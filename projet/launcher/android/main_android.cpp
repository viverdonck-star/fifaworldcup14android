// The launcher on Android: the same menu as on PC (ui.cpp, setup.cpp), drawn
// with Dear ImGui on SDL3's GPU API (Vulkan; the SDK's SDL has no 2D
// renderer), art, fonts and music read from the player's own game.
//
// It runs in LauncherActivity (Java), in the app's main process. The player's
// game is a document they picked once (Android's file picker): Java keeps the
// permission to read it and hands it over as /proc/self/fd/<n>, a path to the
// open file. Play starts the game's activity (MainActivity) in a process of
// its own, as Launcher.exe starts fifawc14.exe on PC; the menu comes back
// when it ends.
//
// Settings, logs and saves are in the app's own folder on shared storage
// (Android/data/<package>/files), which needs no permission.

#include <jni.h>

#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>

#include <algorithm>
#include <chrono>
#include <filesystem>
#include <fstream>
#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <vector>

#include <imgui.h>
#include <imgui_impl_sdl3.h>
#include <imgui_impl_sdlgpu3.h>

#include "audio.h"
#include "game_check.h"
#include "game_files.h"
#include "game_source.h"
#include "i18n.h"
#include "log.h"
#include "settings.h"
#include "setup.h"
#include "textures.h"
#include "ui.h"

using launcher::T;
namespace fs = std::filesystem;

namespace {

// ------------------------------------------------------------------ Java

// LauncherActivity's static methods (the activity's own class: a thread SDL
// made can't find app classes by name).
std::string CallString(const char* method, const char* signature = "()Ljava/lang/String;") {
  auto* env = static_cast<JNIEnv*>(SDL_GetAndroidJNIEnv());
  auto activity = static_cast<jobject>(SDL_GetAndroidActivity());
  jclass type = env->GetObjectClass(activity);
  jmethodID id = env->GetStaticMethodID(type, method, signature);
  auto text = static_cast<jstring>(env->CallStaticObjectMethod(type, id));
  std::string result;
  if (text) {
    const char* chars = env->GetStringUTFChars(text, nullptr);
    result = chars;
    env->ReleaseStringUTFChars(text, chars);
    env->DeleteLocalRef(text);
  }
  env->DeleteLocalRef(type);
  env->DeleteLocalRef(activity);
  return result;
}

void CallVoid(const char* method, const std::vector<std::string>& args = {}) {
  auto* env = static_cast<JNIEnv*>(SDL_GetAndroidJNIEnv());
  auto activity = static_cast<jobject>(SDL_GetAndroidActivity());
  jclass type = env->GetObjectClass(activity);
  std::string signature = "(";
  for (size_t i = 0; i < args.size(); ++i) signature += "Ljava/lang/String;";
  signature += ")V";
  jmethodID id = env->GetStaticMethodID(type, method, signature.c_str());
  std::vector<jvalue> values(args.size());
  for (size_t i = 0; i < args.size(); ++i) values[i].l = env->NewStringUTF(args[i].c_str());
  env->CallStaticVoidMethodA(type, id, values.data());
  for (jvalue& value : values) env->DeleteLocalRef(value.l);
  env->DeleteLocalRef(type);
  env->DeleteLocalRef(activity);
}

// What the file picker returned (LauncherActivity.nativeIsoPicked, on Java's
// thread), taken by the frame loop.
struct Picked {
  std::string path, name, uri;
};
std::mutex g_picked_mutex;
std::optional<Picked> g_picked;

// "<path>\n<name>\n<uri>" (Java's openGame), or nothing.
std::optional<Picked> ParsePicked(const std::string& text) {
  size_t a = text.find('\n'), b = a == std::string::npos ? a : text.find('\n', a + 1);
  if (b == std::string::npos) return std::nullopt;
  return Picked{text.substr(0, a), text.substr(a + 1, b - a - 1), text.substr(b + 1)};
}

// ------------------------------------------------------------------ settings

// fifawc14.toml: created if missing, and given the settings the game needs to
// run correctly on Android if they're absent (the player's own choices are
// kept). As EnsureGameConfig in main.cpp, with the Vulkan ones measured on
// the Odin 3 (TRANSFERT-PORT-ANDROID.md).
void EnsureGameConfig(const fs::path& data_folder) {
  fs::path path = data_folder / "fifawc14.toml";
  std::error_code ec;
  bool created = !fs::exists(path, ec);
  launcher::GameConfig config(path);
  auto require = [&](const char* key, const char* value) {
    if (config.Get(key, "").empty()) config.Set(key, value);
  };
  require("gpu_plugin", "\"xenos\"");
  require("gpu_allow_invalid_fetch_constants", "true");
  require("readback_resolve", "\"none\"");
  require("protect_zero", "false");
  require("execute_unclipped_draw_vs_on_cpu", "true");
  require("async_shader_compilation", "false");
  require("vulkan_submit_on_primary_buffer_end", "false");
  require("native_2x_msaa", "true");
  // Without it the match introduction (its depth-of-field shots) is a
  // white-blue veil on the Odin; measured 02/11/2026.
  require("depth_float24_convert_in_pixel_shader", "true");
  config.Set("clear_memory_page_state", "false");
  for (const auto& [key, value] : launcher::KeyboardSettings()) {
    if (key == "mnk_mode" || key == "mnk_exact_modifiers") {
      config.Set(key, value);
    } else {
      require(key.c_str(), value.c_str());
    }
  }
  if (created) {
    config.Set("present_interval_cap", "1");
    config.Set("frame_rate_floor", "60");
    config.Set("present_late_tolerance", "100");
    config.Set("anisotropic_override", "5");
    config.Set("log_file", "\"" + (data_folder / "fifawc14.log").string() + "\"");
    config.Set("log_level", "\"info\"");
  }
  config.Save();
}

// The game's address for its own process: the picked document (Java opens it
// again there, MainActivity), and its name for the menu.
void SaveGame(const fs::path& data_folder, const Picked& picked) {
  CallVoid("keepGame", {picked.uri, picked.name});
  launcher::GameConfig settings(data_folder / "launcher.toml");
  settings.Set("game_name", "\"" + picked.name + "\"");
  settings.Save();
}

// An RGBA image (rows top to bottom) as a PNG, its pixels stored uncompressed
// (deflate's stored blocks): the game's quit shortcut reads it (pc/src/quit_shortcut.cpp).
bool WritePng(const fs::path& png, const std::vector<uint8_t>& rgba, int width, int height) {
  auto crc = [](const uint8_t* data, size_t size, uint32_t c = 0xFFFFFFFFu) {
    for (size_t i = 0; i < size; ++i) {
      c ^= data[i];
      for (int k = 0; k < 8; ++k) c = (c >> 1) ^ (0xEDB88320u & (0u - (c & 1)));
    }
    return c;
  };
  auto be32 = [](std::vector<uint8_t>& out, uint32_t v) {
    for (int s = 24; s >= 0; s -= 8) out.push_back(uint8_t(v >> s));
  };
  std::vector<uint8_t> raw;  // each row behind a 0 (no filter)
  for (int y = 0; y < height; ++y) {
    raw.push_back(0);
    raw.insert(raw.end(), rgba.begin() + size_t(y) * width * 4,
               rgba.begin() + size_t(y + 1) * width * 4);
  }
  std::vector<uint8_t> z = {0x78, 0x01};
  for (size_t at = 0; at < raw.size(); at += 65535) {
    uint16_t n = uint16_t(std::min<size_t>(65535, raw.size() - at));
    z.push_back(at + n == raw.size());
    z.push_back(uint8_t(n)), z.push_back(uint8_t(n >> 8));
    z.push_back(uint8_t(~n)), z.push_back(uint8_t(~n >> 8));
    z.insert(z.end(), raw.begin() + at, raw.begin() + at + n);
  }
  uint32_t a = 1, b = 0;
  for (uint8_t v : raw) a = (a + v) % 65521, b = (b + a) % 65521;
  be32(z, b << 16 | a);
  std::vector<uint8_t> out = {0x89, 'P', 'N', 'G', '\r', '\n', 0x1A, '\n'};
  auto chunk = [&](const char* type, const std::vector<uint8_t>& data) {
    be32(out, uint32_t(data.size()));
    size_t start = out.size();
    out.insert(out.end(), type, type + 4);
    out.insert(out.end(), data.begin(), data.end());
    be32(out, ~crc(&out[start], out.size() - start));
  };
  std::vector<uint8_t> header;
  be32(header, uint32_t(width));
  be32(header, uint32_t(height));
  header.insert(header.end(), {8, 6, 0, 0, 0});  // 8-bit RGBA
  chunk("IHDR", header);
  chunk("IDAT", z);
  chunk("IEND", {});
  std::ofstream file(png, std::ios::binary);
  file.write(reinterpret_cast<const char*>(out.data()), std::streamsize(out.size()));
  return bool(file);
}

// The screen's refresh rate (0 if SDL doesn't say).
int ScreenRefreshHz(SDL_Window* window) {
  const SDL_DisplayMode* mode = SDL_GetCurrentDisplayMode(SDL_GetDisplayForWindow(window));
  return mode && mode->refresh_rate > 1 ? int(mode->refresh_rate + 0.5f) : 0;
}

// ------------------------------------------------------------------ controller

// Controller buttons as menu commands: d-pad or left stick to move, with
// repeat when held; South (A) selects, East (B) goes back, North (Y) skips the
// song. As PollController in main.cpp, read here on the frame's thread.
class Controller {
 public:
  void Poll(float dt, launcher::Ui* ui, launcher::Setup* setup) {
    enum : uint32_t { kUp = 1, kDown = 2, kLeft = 4, kRight = 8, kSouth = 16, kEast = 32, kNorth = 64 };
    uint32_t buttons = 0;
    int count = 0;
    SDL_JoystickID* ids = SDL_GetGamepads(&count);
    for (int i = 0; i < count; ++i) {
      SDL_Gamepad* pad = SDL_GetGamepadFromID(ids[i]);
      if (!pad) pad = SDL_OpenGamepad(ids[i]);
      if (!pad) continue;
      if (SDL_GetGamepadButton(pad, SDL_GAMEPAD_BUTTON_DPAD_UP)) buttons |= kUp;
      if (SDL_GetGamepadButton(pad, SDL_GAMEPAD_BUTTON_DPAD_DOWN)) buttons |= kDown;
      if (SDL_GetGamepadButton(pad, SDL_GAMEPAD_BUTTON_DPAD_LEFT)) buttons |= kLeft;
      if (SDL_GetGamepadButton(pad, SDL_GAMEPAD_BUTTON_DPAD_RIGHT)) buttons |= kRight;
      if (SDL_GetGamepadButton(pad, SDL_GAMEPAD_BUTTON_SOUTH)) buttons |= kSouth;
      if (SDL_GetGamepadButton(pad, SDL_GAMEPAD_BUTTON_EAST)) buttons |= kEast;
      if (SDL_GetGamepadButton(pad, SDL_GAMEPAD_BUTTON_NORTH)) buttons |= kNorth;
      const Sint16 dead = 16000;
      Sint16 x = SDL_GetGamepadAxis(pad, SDL_GAMEPAD_AXIS_LEFTX);
      Sint16 y = SDL_GetGamepadAxis(pad, SDL_GAMEPAD_AXIS_LEFTY);
      if (y < -dead) buttons |= kUp;
      if (y > dead) buttons |= kDown;
      if (x < -dead) buttons |= kLeft;
      if (x > dead) buttons |= kRight;
    }
    SDL_free(ids);
    uint32_t pressed = buttons & ~previous_;
    const uint32_t directions = kUp | kDown | kLeft | kRight;
    if (buttons & directions & previous_) {
      repeat_ -= dt;
      if (repeat_ <= 0) {
        pressed |= buttons & directions;
        repeat_ = 0.12f;
      }
    } else {
      repeat_ = 0.4f;
    }
    previous_ = buttons;
    auto send = [&](launcher::Command command) {
      if (ui) {
        ui->OnCommand(command, launcher::InputDevice::kController);
      } else if (setup) {
        setup->OnCommand(command);
      }
    };
    if (pressed & kUp) send(launcher::Command::kUp);
    if (pressed & kDown) send(launcher::Command::kDown);
    if (pressed & kLeft) send(launcher::Command::kLeft);
    if (pressed & kRight) send(launcher::Command::kRight);
    if (pressed & kSouth) send(launcher::Command::kAccept);
    if (pressed & kEast) send(launcher::Command::kBack);
    if ((pressed & kNorth) && ui) ui->SkipSong();
  }

 private:
  uint32_t previous_ = 0;
  float repeat_ = 0;
};

}  // namespace

// The file picker's answer (LauncherActivity.onActivityResult).
extern "C" JNIEXPORT void JNICALL Java_com_wc14_test_LauncherActivity_nativeIsoPicked(
    JNIEnv* env, jclass, jstring path, jstring name, jstring uri) {
  auto text = [env](jstring value) {
    const char* chars = env->GetStringUTFChars(value, nullptr);
    std::string result = chars;
    env->ReleaseStringUTFChars(value, chars);
    return result;
  };
  std::lock_guard lock(g_picked_mutex);
  g_picked = Picked{text(path), text(name), text(uri)};
}

int main(int, char*[]) {
  SDL_SetHint(SDL_HINT_ANDROID_TRAP_BACK_BUTTON, "1");
  if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_GAMEPAD)) return 1;

  fs::path data_folder = CallString("dataFolder");
  fs::path saves_folder = data_folder / "saves";
  std::error_code ec;
  fs::create_directories(saves_folder, ec);
  // The game keeps its saves in "saves" next to its settings when this is there
  // (pc/src/data_folder.cpp), as the portable PC version does.
  if (!fs::exists(data_folder / "portable.txt", ec)) std::ofstream(data_folder / "portable.txt");
  launcher::OpenLog(data_folder / "launcher.log");
  launcher::Log("data: %s", data_folder.c_str());
  EnsureGameConfig(data_folder);
  {
    launcher::GameConfig config(data_folder / "launcher.toml");
    std::string code = config.Get("language", "");
    if (code.size() >= 2 && code.front() == '"') code = code.substr(1, code.size() - 2);
    launcher::SetLanguage(launcher::LanguageFromCode(code, launcher::Language::kEnglish));
  }

  // The game picked last time, if it's still there and still the right game.
  std::unique_ptr<launcher::GameSource> source;
  std::vector<uint32_t> game_languages;
  if (std::optional<Picked> kept = ParsePicked(CallString("openGame"))) {
    source = launcher::OpenGameSource(kept->path);
    if (source) {
      launcher::GameCheck check = launcher::CheckGame(*source);
      if (check.result != launcher::GameCheck::Result::kFound) {
        launcher::Log("the game '%s' doesn't check out (result %d), asking", kept->name.c_str(),
                      int(check.result));
        source.reset();
      }
      game_languages = check.languages;
    } else {
      launcher::Log("the game '%s' can't be read, asking", kept->name.c_str());
    }
  }

  SDL_Window* window = SDL_CreateWindow("2014 FIFA World Cup Brazil", 0, 0, SDL_WINDOW_FULLSCREEN);
  SDL_GPUDevice* gpu = window ? SDL_CreateGPUDevice(SDL_GPU_SHADERFORMAT_SPIRV, false, nullptr)
                              : nullptr;
  if (!gpu || !SDL_ClaimWindowForGPUDevice(gpu, window)) {
    launcher::Log("no window or GPU device: %s", SDL_GetError());
    return 1;
  }
  SDL_SetGPUSwapchainParameters(gpu, window, SDL_GPU_SWAPCHAINCOMPOSITION_SDR,
                                SDL_GPU_PRESENTMODE_VSYNC);
  launcher::Log("GPU: %s", SDL_GetGPUDeviceDriver(gpu));

  ImGui::CreateContext();
  ImGui::GetIO().IniFilename = nullptr;
  ImGui_ImplSDL3_InitForSDLGPU(window);
  ImGui_ImplSDLGPU3_InitInfo init_info;
  init_info.Device = gpu;
  init_info.ColorTargetFormat = SDL_GetGPUSwapchainTextureFormat(gpu, window);
  ImGui_ImplSDLGPU3_Init(&init_info);

  // The menu, once the game is found (in this order so the music, which
  // streams from the game's files, stops before they close).
  std::unique_ptr<launcher::GameFiles> files;
  std::unique_ptr<launcher::Ui> ui;
  std::unique_ptr<launcher::Audio> audio;
  bool change_game = false;
  bool playing = false;  // Play started the game: the menu is in the background
  bool running = true;

  auto load_menu = [&]() -> bool {
    files = std::make_unique<launcher::GameFiles>(*source);
    launcher::Log("game data: %zu files in its archives", files->entry_count());
    bool anthem_first;
    {
      launcher::GameConfig first_start(data_folder / "launcher.toml");
      anthem_first = first_start.Get("anthem_played", "false") != "true";
      if (anthem_first) {
        first_start.Set("anthem_played", "true");
        first_start.Save();
      }
    }
    ui = std::make_unique<launcher::Ui>();
    if (!ui->Load(gpu, *files, data_folder, saves_folder)) {
      launcher::Log("the menu's art couldn't be read from the game's files");
      return false;
    }
    audio = std::make_unique<launcher::Audio>();
    audio->Load(*files, anthem_first);
    ui->SetAudio(audio.get());
    ui->on_play = [&] {
      audio->SetMusic(false, 0.0f);
      launcher::GameConfig config(data_folder / "fifawc14.toml");
      config.Set("quit_buttons", "\"xbox\"");
      uint32_t language = launcher::Info(launcher::CurrentLanguage()).xbox;
      if (!game_languages.empty() &&
          std::find(game_languages.begin(), game_languages.end(), language) == game_languages.end()) {
        language = 1;
      }
      config.Set("user_language", std::to_string(language));
      auto quoted = [](const char* text) { return std::string("\"") + text + "\""; };
      config.Set("quit_hold", quoted(T("Hold")));
      config.Set("quit_to_quit", quoted(T("to quit")));
      config.Set("quit_quitting", quoted(T("Quitting")));
      config.Set("quit_create", quoted(T("Create")));
      int rate = std::atoi(config.Get("frame_rate_floor", "0").c_str());
      if (rate <= 0) rate = 60;
      int screen = ScreenRefreshHz(window);
      if (screen > 0) rate = std::min(rate, screen);
      config.Set("video_mode_refresh_rate", std::to_string(rate));
      launcher::Log("play: %d FPS on a %d Hz screen", rate, screen);
      config.Save();
      playing = true;
      CallVoid("startGame");
    };
    ui->on_quit = [&] { running = false; };
    ui->on_change_game = [&] { change_game = true; };
    // The game's condensed font and a brush-stroke panel, for its frame-rate
    // display and quit shortcut (pc/src/fps_counter.cpp, quit_shortcut.cpp).
    fs::path font = data_folder / "futurastd-condensed.ttf";
    if (!fs::exists(font, ec)) {
      if (auto data = files->Read("data/ui/fonts/futurastd-condensed.ttf")) {
        std::ofstream(font, std::ios::binary)
            .write(reinterpret_cast<const char*>(data->data()), std::streamsize(data->size()));
      }
    }
    fs::path panel = data_folder / "quit-panel.png";
    if (!fs::exists(panel, ec)) {
      if (auto dds = files->Read("data/ui/imgassets/custompanels/custompanels_42.dds")) {
        int width = 0, height = 0;
        std::vector<uint8_t> rgba = launcher::DecodeDds(*dds, &width, &height);
        if (!rgba.empty()) WritePng(panel, rgba, width, height);
      }
    }
    return true;
  };

  // Until then, the setup screen.
  std::unique_ptr<launcher::Setup> setup;
  std::unique_ptr<launcher::GameSource> chosen;
  std::optional<Picked> offered;  // the document on the setup screen
  bool leaving = false, going_back = false;
  float black = 0.0f;
  auto open_setup = [&]() -> bool {
    setup = std::make_unique<launcher::Setup>();
    if (!setup->Load()) return false;
    setup->on_choose_iso = [] { CallVoid("pickIso"); };
    setup->on_continue = [&](std::unique_ptr<launcher::GameSource> found) {
      chosen = std::move(found);
      game_languages = setup->check().languages;
      leaving = true;
    };
    setup->on_back = [&] { going_back = true; };
    setup->on_language = [&] {
      launcher::GameConfig config(data_folder / "launcher.toml");
      config.Set("language", std::string("\"") + launcher::Info(launcher::CurrentLanguage()).code + "\"");
      config.Save();
    };
    if (source) {
      launcher::GameConfig config(data_folder / "launcher.toml");
      std::string name = config.Get("game_name", "");
      if (name.size() >= 2 && name.front() == '"') name = name.substr(1, name.size() - 2);
      setup->AllowBack(name);
    }
    return true;
  };
  if (source) {
    if (!load_menu()) return 2;
  } else {
    if (!open_setup()) return 2;
  }

  Controller controller;
  auto last = std::chrono::steady_clock::now();
  while (running) {
    SDL_Event event;
    while (SDL_PollEvent(&event)) {
      ImGui_ImplSDL3_ProcessEvent(&event);
      if (event.type == SDL_EVENT_QUIT || event.type == SDL_EVENT_TERMINATING) running = false;
      if (event.type == SDL_EVENT_KEY_DOWN && event.key.scancode == SDL_SCANCODE_AC_BACK) {
        if (ui && !setup) {
          ui->OnCommand(launcher::Command::kBack, launcher::InputDevice::kController);
        } else if (setup) {
          setup->OnCommand(launcher::Command::kBack);
        }
      }
      // Back from the game (its activity gone, ours in front again): the
      // menu's music again.
      if ((event.type == SDL_EVENT_DID_ENTER_FOREGROUND ||
           event.type == SDL_EVENT_WINDOW_FOCUS_GAINED) &&
          playing) {
        playing = false;
        for (int button = 0; button < ImGuiMouseButton_COUNT; ++button) {
          ImGui::GetIO().AddMouseButtonEvent(button, false);
        }
        if (ui) ui->ApplySoundSettings();
        last = std::chrono::steady_clock::now();
        launcher::Log("back from the game");
      }
    }
    if (!running) break;

    auto now = std::chrono::steady_clock::now();
    float dt = std::min(std::chrono::duration<float>(now - last).count(), 0.1f);
    last = now;
    controller.Poll(dt, setup ? nullptr : ui.get(), setup.get());
    if (audio) audio->Update();

    ImGui_ImplSDLGPU3_NewFrame();
    ImGui_ImplSDL3_NewFrame();
    ImGui::NewFrame();
    ImVec2 size = ImGui::GetIO().DisplaySize;
    if (setup) {
      setup->Frame(size.x, size.y, dt);
    } else {
      ui->Frame(size.x, size.y, dt);
    }
    if (black > 0) {
      ImGui::GetForegroundDrawList()->AddRectFilled(
          ImVec2(0, 0), size, IM_COL32(0, 0, 0, int(255 * std::min(black, 1.0f))));
    }
    ImGui::Render();
    ImDrawData* draw_data = ImGui::GetDrawData();
    SDL_GPUCommandBuffer* commands = SDL_AcquireGPUCommandBuffer(gpu);
    SDL_GPUTexture* swapchain = nullptr;
    // No swapchain image while the app is in the background (the game runs).
    if (commands && SDL_WaitAndAcquireGPUSwapchainTexture(commands, window, &swapchain, nullptr,
                                                          nullptr) &&
        swapchain) {
      ImGui_ImplSDLGPU3_PrepareDrawData(draw_data, commands);
      SDL_GPUColorTargetInfo target = {};
      target.texture = swapchain;
      target.clear_color = SDL_FColor{0, 0, 0, 1};
      target.load_op = SDL_GPU_LOADOP_CLEAR;
      target.store_op = SDL_GPU_STOREOP_STORE;
      SDL_GPURenderPass* pass = SDL_BeginGPURenderPass(commands, &target, 1, nullptr);
      ImGui_ImplSDLGPU3_RenderDrawData(draw_data, commands, pass);
      SDL_EndGPURenderPass(pass);
    }
    if (commands) SDL_SubmitGPUCommandBuffer(commands);

    if (change_game) {
      change_game = false;
      if (!open_setup()) return 2;
    }
    if (setup) {
      {
        std::lock_guard lock(g_picked_mutex);
        if (g_picked) {
          offered = std::move(*g_picked);
          g_picked.reset();
          setup->Offer(offered->path, offered->name);
        }
      }
      if (going_back) {
        going_back = false;
        setup.reset();
      } else if (leaving && (black += dt / 0.3f) >= 1.0f) {
        leaving = false;
        setup.reset();
        audio.reset();
        ui.reset();
        files.reset();
        source = std::move(chosen);
        if (offered) SaveGame(data_folder, *offered);
        launcher::Log("game chosen: %s", offered ? offered->name.c_str() : "?");
        if (!load_menu()) return 2;
        last = std::chrono::steady_clock::now();
      }
    } else if (black > 0) {
      black -= dt / 0.6f;
    }
  }

  audio.reset();
  ui.reset();
  SDL_WaitForGPUIdle(gpu);
  ImGui_ImplSDLGPU3_Shutdown();
  ImGui_ImplSDL3_Shutdown();
  ImGui::DestroyContext();
  SDL_ReleaseWindowFromGPUDevice(gpu, window);
  SDL_DestroyGPUDevice(gpu);
  SDL_DestroyWindow(window);
  SDL_Quit();
  return 0;
}
