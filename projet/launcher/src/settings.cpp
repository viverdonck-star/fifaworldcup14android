#include "settings.h"

#ifdef _WIN32
#include <windows.h>
#include <shellapi.h>
#include <shlobj.h>
#include <shobjidl.h>
#include <wrl/client.h>
#endif

#include <algorithm>
#include <fstream>
#include <regex>

#include "i18n.h"

namespace launcher {

namespace fs = std::filesystem;

#ifdef __ANDROID__
// main_android.cpp: LauncherActivity's actions, and where imported drivers are.
void AndroidCall(const char* method);
fs::path AndroidDriversFolder();
#endif

// ------------------------------------------------------------------ GameConfig

namespace {

// `key = value  # comment`: groups 1 (up to the value), 2 (value), 3 (rest).
std::regex SettingLine(const std::string& key) {
  return std::regex("^(\\s*" + key + "\\s*=\\s*)((?:\"[^\"]*\"|[^#\\s])*)(.*)$");
}

}  // namespace

GameConfig::GameConfig(fs::path path) : path_(std::move(path)) {
  std::ifstream file(path_);
  std::string line;
  while (std::getline(file, line)) {
    if (!line.empty() && line.back() == '\r') line.pop_back();
    lines_.push_back(line);
  }
}

std::string GameConfig::Get(const std::string& key, const std::string& fallback) const {
  std::regex pattern = SettingLine(key);
  std::smatch match;
  for (const std::string& line : lines_) {
    if (std::regex_match(line, match, pattern)) return match[2].str();
  }
  return fallback;
}

void GameConfig::Set(const std::string& key, const std::string& value) {
  std::regex pattern = SettingLine(key);
  std::smatch match;
  for (std::string& line : lines_) {
    if (std::regex_match(line, match, pattern)) {
      line = match[1].str() + value + match[3].str();
      return;
    }
  }
  lines_.push_back(key + " = " + value);
}

bool GameConfig::Save() const {
  std::ofstream file(path_, std::ios::trunc);
  for (const std::string& line : lines_) file << line << '\n';
  return bool(file);
}

// ------------------------------------------------------------------ Option

size_t Option::Current(const GameConfig& config) const {
  for (size_t i = 0; i < choices.size(); ++i) {
    bool matches = true;
    for (const auto& [key, value] : choices[i].writes) {
      auto fallback = defaults.find(key);
      if (config.Get(key, fallback != defaults.end() ? fallback->second : "") != value) {
        matches = false;
        break;
      }
    }
    if (matches) return i;
  }
  return 0;
}

void Option::Step(GameConfig& config, int delta) const {
  if (choices.empty()) return;
  size_t count = choices.size();
  size_t next = (Current(config) + count + delta) % count;
  for (const auto& [key, value] : choices[next].writes) config.Set(key, value);
  for (const auto& [key, value] : choices[next].also) config.Set(key, value);
  config.Save();
}

// ------------------------------------------------------------------ keyboard

const std::vector<ControlRow>& KeyboardLayout() {
  // Sticks: one setting per direction (up, down, left, right), keys in the same order.
  // The game's Controller Settings screen lists neither the right stick nor
  // L3 / R3, Start and Back; Skill moves and Pause are FIFA's usual ones.
  static const std::vector<ControlRow> layout = {
      {"A", Glyph::kFace, "keybind_a", "Space,Z", "Space  Z", "Short Pass/Header", "Contain"},
      {"B", Glyph::kFace, "keybind_b", "X,Backspace", "X  Backspace", "Shoot/Volley/Header",
       "Tackle/Push or Pull (when chasing)"},
      {"X", Glyph::kFace, "keybind_x", "C", "C", "Lob Pass/Cross/Header", ""},
      {"Y", Glyph::kFace, "keybind_y", "V", "V", "Through Ball", ""},
      {"LB", Glyph::kBumper, "keybind_left_shoulder", "Q", "Q", "Player Run/Modifier",
       "Change Player"},
      {"RB", Glyph::kBumper, "keybind_right_shoulder", "E", "E", "Finesse Shot Modifier",
       "Teammate Contain"},
      {"LT", Glyph::kTrigger, "keybind_left_trigger", "1,Control", "1  Ctrl", "Pace Control",
       "Jockey"},
      {"RT", Glyph::kTrigger, "keybind_right_trigger", "Shift,3", "Shift  3", "Sprint", "Sprint"},
      {"L", Glyph::kStick,
       "keybind_lstick_up,keybind_lstick_down,keybind_lstick_left,keybind_lstick_right",
       "W,S,A,D", "W  A  S  D", "Move Player", "Move Player"},
      {"R", Glyph::kStick,
       "keybind_rstick_up,keybind_rstick_down,keybind_rstick_left,keybind_rstick_right",
       "I,K,J,L", "I  J  K  L", "Skill moves", ""},
      {"L3", Glyph::kStick, "keybind_lstick_press", "F", "F", "", ""},
      {"R3", Glyph::kStick, "keybind_rstick_press", "G", "G", "", ""},
      {"D-pad", Glyph::kPad, "keybind_dpad_up,keybind_dpad_down,keybind_dpad_left,keybind_dpad_right",
       "Up,Down,Left,Right", "Arrow keys", "Tactics & Mentality",
       "Tactics & Mentality"},
      {"Start", Glyph::kSmall, "keybind_start", "Return", "Enter", "Pause", "Pause"},
      {"Back", Glyph::kSmall, "keybind_back", "Tab", "Tab", "", ""},
  };
  return layout;
}

// The keybind settings for the layout above: each row's setting gets its keys;
// a stick's four settings get one key each.
std::map<std::string, std::string> KeyboardSettings() {
  std::map<std::string, std::string> settings = {{"mnk_mode", "true"},
                                                 {"mnk_exact_modifiers", "false"}};
  auto split = [](const std::string& text) {
    std::vector<std::string> parts;
    size_t start = 0;
    for (size_t comma; (comma = text.find(',', start)) != std::string::npos; start = comma + 1) {
      parts.push_back(text.substr(start, comma - start));
    }
    parts.push_back(text.substr(start));
    return parts;
  };
  for (const ControlRow& row : KeyboardLayout()) {
    std::vector<std::string> names = split(row.setting);
    if (names.size() == 1) {
      settings[names[0]] = "\"" + std::string(row.keys) + "\"";
    } else {
      std::vector<std::string> keys = split(row.keys);
      for (size_t i = 0; i < names.size() && i < keys.size(); ++i) {
        settings[names[i]] = "\"" + keys[i] + "\"";
      }
    }
  }
  return settings;
}


// ------------------------------------------------------------------ sections

namespace {

#ifdef _WIN32
void OpenFolder(const fs::path& folder) {
  std::error_code ec;
  fs::create_directories(folder, ec);
  ShellExecuteW(nullptr, L"open", folder.c_str(), nullptr, nullptr, SW_SHOWNORMAL);
}
#endif

uint64_t FolderBytes(const fs::path& folder) {
  uint64_t total = 0;
  std::error_code ec;
  for (auto it = fs::recursive_directory_iterator(folder, ec);
       it != fs::recursive_directory_iterator(); it.increment(ec)) {
    if (ec) break;
    if (it->is_regular_file(ec)) total += it->file_size(ec);
  }
  return total;
}

std::string Size(uint64_t bytes) {
  char text[32];
  if (bytes < 1024 * 1024) {
    std::snprintf(text, sizeof(text), "%llu KB", (unsigned long long)(bytes / 1024));
  } else {
    std::snprintf(text, sizeof(text), "%llu MB", (unsigned long long)(bytes / (1024 * 1024)));
  }
  return text;
}

#ifdef _WIN32
// The desktop shortcut's file on a desktop (the player's own, or the shared
// one the installer puts it on), named as the installer names it.
fs::path DesktopShortcut(REFKNOWNFOLDERID desktop_id) {
  PWSTR desktop = nullptr;
  fs::path path;
  if (SUCCEEDED(SHGetKnownFolderPath(desktop_id, 0, nullptr, &desktop))) {
    path = fs::path(desktop) / L"2014 FIFA World Cup Brazil - Recompiled.lnk";
  }
  CoTaskMemFree(desktop);
  return path;
}

bool HasDesktopShortcut() {
  std::error_code ec;
  return fs::exists(DesktopShortcut(FOLDERID_Desktop), ec) ||
         fs::exists(DesktopShortcut(FOLDERID_PublicDesktop), ec);
}

// A desktop shortcut to this launcher with the game's icon (icon.ico in the
// data folder, made from the player's copy, see icon.h): the portable version
// has none, and a deleted one comes back this way. Not when one is there already.
void CreateDesktopShortcut(const fs::path& data_folder) {
  if (HasDesktopShortcut()) return;
  wchar_t exe[MAX_PATH];
  GetModuleFileNameW(nullptr, exe, MAX_PATH);
  fs::path shortcut = DesktopShortcut(FOLDERID_Desktop);
  Microsoft::WRL::ComPtr<IShellLinkW> link;
  Microsoft::WRL::ComPtr<IPersistFile> file;
  if (shortcut.empty() ||
      FAILED(CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER,
                              IID_PPV_ARGS(&link))) ||
      FAILED(link.As(&file))) {
    return;
  }
  link->SetPath(exe);
  link->SetWorkingDirectory(fs::path(exe).parent_path().c_str());
  link->SetDescription(L"2014 FIFA World Cup Brazil: Recompiled");
  std::error_code ec;
  fs::path icon = data_folder / "icon.ico";
  if (fs::exists(icon, ec)) link->SetIconLocation(icon.c_str(), 0);
  if (SUCCEEDED(file->Save(shortcut.c_str(), TRUE))) {
    SHChangeNotify(SHCNE_CREATE, SHCNF_PATHW, shortcut.c_str(), nullptr);
  }
}
#endif

Option OnOff(const char* label, std::string key, std::string fallback, std::string help) {
  Option option;
  option.label = T(label);
  option.help = std::move(help);
  option.choices = {{T("Off"), {{key, "false"}}, {}}, {T("On"), {{key, "true"}}, {}}};
  option.defaults = {{key, std::move(fallback)}};
  return option;
}

}  // namespace

std::vector<Section> MakeSections(const fs::path& data_folder, const fs::path& user_folder) {
  std::vector<Section> sections;

  Section display{T("Display"), 0, {}};
  {
    // In launcher.toml; the game gets it at Play (user_language, main.cpp).
    Option language;
    language.label = T("Language");
    language.help = T("The language of this menu and of the game, which asks for it at every "
                      "start with this one selected.");
    for (const LanguageInfo& info : Languages()) {
      language.choices.push_back({info.name, {{"language", std::string("\"") + info.code + "\""}}, {}});
    }
    language.defaults = {{"language", std::string("\"") + Info(Language::kEnglish).code + "\""}};
    language.local = true;
    display.options.push_back(language);

#ifdef _WIN32
    Option window;
    window.label = T("Window");
    window.help = T("Fullscreen fills your screen and lets you switch apps quickly. Exclusive "
                    "gives the game the screen to itself. Windowed uses Window size.");
    window.choices = {
        {T("Fullscreen"), {{"fullscreen", "true"}, {"fullscreen_exclusive", "false"}}, {}},
        {T("Exclusive"), {{"fullscreen", "true"}, {"fullscreen_exclusive", "true"}}, {}},
        {T("Windowed"), {{"fullscreen", "false"}}, {}}};
    window.defaults = {{"fullscreen", "true"}, {"fullscreen_exclusive", "false"}};
    display.options.push_back(window);

    Option size;
    size.label = T("Window size");
    size.help = T("The size of the game's window in Windowed mode. Automatic makes it as large "
                  "as fits your screen. A size larger than your screen is shrunk to fit.");
    size.applies = [](const GameConfig& config) { return config.Get("fullscreen", "true") == "false"; };
    size.choices = {{T("Automatic"), {{"windowed_width", "0"}, {"windowed_height", "0"}}, {}}};
    for (auto [w, h] : {std::pair{1280, 720}, {1600, 900}, {1920, 1080}, {2560, 1440}}) {
      size.choices.push_back({std::to_string(w) + " x " + std::to_string(h),
                              {{"windowed_width", std::to_string(w)},
                               {"windowed_height", std::to_string(h)}},
                              {}});
    }
    size.defaults = {{"windowed_width", "0"}, {"windowed_height", "0"}};
    display.options.push_back(size);

    int monitors = GetSystemMetrics(SM_CMONITORS);
    if (monitors > 1) {
      Option monitor;
      monitor.label = T("Monitor");
      monitor.help = T("The screen the game opens on.");
      monitor.choices = {{T("Main"), {{"monitor", "0"}}, {}}};
      for (int i = 2; i <= monitors; ++i) {
        monitor.choices.push_back({Tf("Monitor {0}", {std::to_string(i)}), {{"monitor", std::to_string(i)}}, {}});
      }
      monitor.defaults = {{"monitor", "0"}};
      display.options.push_back(monitor);
    }

    Option sync;
    sync.label = "VSync";
    sync.help = T("On stops tearing and keeps the game at your screen's refresh rate or below. "
                  "Off lets Frame rate go higher, but can tear.");
    // At Play, On also lowers the game's rate to the screen's (main.cpp).
    sync.choices = {{T("On"),
                     {{"d3d12_allow_variable_refresh_rate_and_tearing", "false"},
                      {"vsync_to_display", "true"}},
                     {}},
                    {T("Off"),
                     {{"d3d12_allow_variable_refresh_rate_and_tearing", "true"},
                      {"vsync_to_display", "false"}},
                     {}}};
    sync.defaults = {{"d3d12_allow_variable_refresh_rate_and_tearing", "false"},
                     {"vsync_to_display", "true"}};
    display.options.push_back(sync);
#endif
    Option rate;
    rate.label = T("Frame rate");
#ifdef __ANDROID__
    rate.help = T("Recommended: 40 FPS, even on a 120 Hz screen, with the device about 8 degrees "
                  "cooler and the battery lasting longer. 60 FPS is smoother, but the device gets "
                  "much hotter. As on console holds cutscenes at 40 and many menus at 30.");
    for (int fps : {60}) {
#else
    rate.help = T("The game holds cutscenes at 40 FPS and many menus at 30, as on the console. "
                  "These rates lift both limits. Above 60 needs a faster PC, and heavy scenes may "
                  "run below the rate you pick.");
    for (int fps : {60, 120, 144, 165, 240}) {
#endif
      rate.choices.push_back({std::to_string(fps) + " FPS",
                              {{"present_interval_cap", "1"},
                               {"frame_rate_floor", std::to_string(fps)},
                               {"frame_rate_cap", "0"},
                               {"present_late_tolerance", "100"}},
                              {}});
    }
#ifdef __ANDROID__
    // 40 FPS everywhere: three refreshes of a 120 Hz screen a frame, so it
    // stays even, with a third less work than 60.
    rate.choices.push_back({"40 FPS",
                            {{"present_interval_cap", "1"},
                             {"frame_rate_floor", "40"},
                             {"frame_rate_cap", "40"},
                             {"present_late_tolerance", "100"}},
                            {}});
#endif
    rate.choices.push_back({T("As on console"),
                            {{"present_interval_cap", "0"},
                             {"frame_rate_floor", "0"},
                             {"frame_rate_cap", "0"},
                             {"present_late_tolerance", "0"}},
                            {}});
    rate.defaults = {{"present_interval_cap", "0"},
                     {"frame_rate_floor", "0"},
                     {"frame_rate_cap", "0"},
                     {"present_late_tolerance", "100"}};
    display.options.push_back(rate);

    display.options.push_back(OnOff("Show FPS", "show_fps", "false",
                                    T("The frame rate in the top left corner of the game.")));
  }
  sections.push_back(display);

  Section graphics{T("Graphics"), 1, {}};
  {
    Option resolution;
    resolution.label = T("Resolution");
    resolution.help = T("What the game draws at. 720p is the console's own. 1440p is sharp on a "
                        "1080p screen. 4K needs a fast graphics card.");
#ifdef __ANDROID__
    // 4K is out of reach of a handheld's graphics.
    resolution.help = T("Recommended: 720p, the console's own. 1440p is sharper, but costs a lot "
                        "of frame rate and makes the device hotter.");
    resolution.choices = {{"720p", {{"resolution_scale", "1"}}, {}},
                          {"1440p", {{"resolution_scale", "2"}}, {}}};
#else
    resolution.choices = {{"720p", {{"resolution_scale", "1"}}, {}},
                          {"1440p", {{"resolution_scale", "2"}}, {}},
                          {"4K", {{"resolution_scale", "3"}}, {}}};
#endif
    resolution.defaults = {{"resolution_scale", "1"}};
    graphics.options.push_back(resolution);

    Option upscaling;
    upscaling.label = T("Upscaling");
    upscaling.help = T("FSR sharpens the picture as it's fitted to your screen, most of all at "
                       "720p on a 1080p screen. It can look a bit artificial.");
    upscaling.choices = {{T("Off"), {{"present_effect", "\"bilinear\""}}, {}},
                         {"FSR", {{"present_effect", "\"fsr\""}}, {}}};
    upscaling.defaults = {{"present_effect", "\"bilinear\""}};
#ifdef __ANDROID__
    upscaling.help = T("Recommended: Off. FSR sharpens the picture as it's fitted to the screen, "
                       "for a small cost in frame rate. It can look a bit artificial.");
#endif
    graphics.options.push_back(upscaling);

    Option picture;
    picture.label = T("Picture");
    picture.help = T("Fit keeps the right shape, with black bars on screens wider than 16:9. "
                     "Stretch fills the screen, but players and the HUD look wider.");
    picture.choices = {{T("Fit"), {{"present_letterbox", "true"}}, {}},
                       {T("Stretch"), {{"present_letterbox", "false"}}, {}}};
    picture.defaults = {{"present_letterbox", "true"}};
    graphics.options.push_back(picture);

    Option filtering;
    filtering.label = T("Texture filtering");
    filtering.help = T("Keeps the pitch markings and the stands sharp at shallow angles. Costs "
                       "next to nothing on today's graphics cards.");
    filtering.choices = {{T("Game's own"), {{"anisotropic_override", "-1"}}, {}},
                         {"2x", {{"anisotropic_override", "2"}}, {}},
                         {"4x", {{"anisotropic_override", "3"}}, {}},
                         {"8x", {{"anisotropic_override", "4"}}, {}},
                         {"16x", {{"anisotropic_override", "5"}}, {}}};
    filtering.defaults = {{"anisotropic_override", "3"}};
#ifdef __ANDROID__
    filtering.help = T("Recommended: 16x. Keeps the pitch markings and the stands sharp at shallow "
                       "angles; lower settings were no faster on the Odin 3.");
#endif
    graphics.options.push_back(filtering);
#ifdef __ANDROID__
    // The depth conversion is what removes the white veil of the match
    // introduction on the Adreno (main_android.cpp), but every depth-tested
    // draw then writes its depth from the pixel shader, which may cost the
    // heavier cutscenes their frame rate.
    Option depth;
    depth.label = T("Exact depth");
    depth.help = T("Recommended: On. Off brings back the white haze over the shots before "
                   "kickoff, for no gain in frame rate on the Odin 3.");
    depth.choices = {{T("On"), {{"depth_float24_convert_in_pixel_shader", "true"}}, {}},
                     {T("Off"), {{"depth_float24_convert_in_pixel_shader", "false"}}, {}}};
    depth.defaults = {{"depth_float24_convert_in_pixel_shader", "true"}};
    graphics.options.push_back(depth);

    // Read by the game's activity (MainActivity.java), which hands the driver
    // to the engine through libadrenotools.
    Option driver;
    driver.label = T("GPU driver");
    driver.help = T("Recommended: Device's own, the fastest here (Turnip was about a quarter "
                    "slower on the Odin 3). Another driver may fix a wrong picture, but may also "
                    "stop the game from starting: then choose Device's own again.");
    driver.choices = {{T("Device's own"), {{"gpu_driver", "\"system\""}}, {}},
                      {"Turnip", {{"gpu_driver", "\"builtin:libvulkan_freedreno.so\""}}, {}}};
    // Those the player imported (LauncherActivity.importDriver), by file name.
    fs::path drivers = AndroidDriversFolder();
    std::vector<std::string> imported;
    std::error_code ec;
    for (const auto& entry : fs::directory_iterator(drivers, ec)) {
      if (entry.path().extension() == ".so") imported.push_back(entry.path().filename().string());
    }
    std::sort(imported.begin(), imported.end());
    for (const std::string& name : imported) {
      std::string shown = name.substr(0, name.size() - 3);
      if (shown.size() > 22) shown = shown.substr(0, 21) + "\xE2\x80\xA6";
      driver.choices.push_back({shown, {{"gpu_driver", "\"imported:" + name + "\""}}, {}});
    }
    driver.defaults = {{"gpu_driver", "\"system\""}};
    graphics.options.push_back(driver);

    Option import;
    import.label = T("Import a driver");
    import.action = T("Import");
    import.help = T("Adds a Vulkan driver for Adreno (a Turnip .zip made for AdrenoTools, or its "
                    ".so file) to GPU driver, and chooses it. Only drivers from sources you "
                    "trust: a driver runs with the game's rights.");
    import.run = [] { AndroidCall("importDriver"); };
    graphics.options.push_back(import);

    if (!imported.empty()) {
      Option remove;
      remove.label = T("Imported drivers");
      remove.action = T("Remove");
      remove.confirm = true;
      remove.rebuilds = true;
      remove.info = [count = imported.size()] { return std::to_string(count); };
      remove.help = T("Removes the drivers you imported. If one of them was chosen, the game "
                      "uses the device's own again.");
      remove.run = [drivers] {
        std::error_code ec;
        fs::remove_all(drivers, ec);
      };
      graphics.options.push_back(remove);
    }

    Option cutscenes;
    cutscenes.label = T("Cutscenes");
    cutscenes.help = T("Recommended: 30 FPS. The match introduction and replays can't hold 60 "
                       "on a handheld: 30 keeps them even and the device cooler. As the frame "
                       "rate is smoother at times, but uneven.");
    cutscenes.choices = {{T("As the frame rate"), {{"frame_rate_cutscene", "0"}}, {}},
                         {"30 FPS", {{"frame_rate_cutscene", "30"}}, {}}};
    cutscenes.defaults = {{"frame_rate_cutscene", "0"}};
    graphics.options.push_back(cutscenes);
#endif
  }
  sections.push_back(graphics);

  // This menu's own sound; the game's volume is in the game's own settings.
  Section sound{T("Menu sound"), 3, {}};
  {
    auto percent = [](const char* label, std::string key, std::string fallback, std::string help) {
      Option option;
      option.label = T(label);
      option.help = std::move(help);
      for (int v = 10; v <= 100; v += 10) {
        option.choices.push_back({std::to_string(v) + "%", {{key, std::to_string(v)}}, {}});
      }
      option.defaults = {{key, std::move(fallback)}};
      option.local = true;
      return option;
    };
    auto only_here = [](const char* text) {
      return std::string(T(text)) + " " +
             T("Only in this menu. The game's own sound is set in the game.");
    };
    Option music = OnOff("Music", "menu_music", "true",
                         only_here("The game's EA Trax soundtrack, shuffled, while you're in "
                                   "this menu."));
    music.local = true;
    sound.options.push_back(music);
    sound.options.push_back(percent("Music volume", "music_volume", "50",
                                    only_here("How loud this menu's music is.")));
    Option sounds = OnOff("Sounds", "menu_sounds", "true",
                          only_here("The game's menu sounds as you move, select and go back."));
    sounds.local = true;
    sound.options.push_back(sounds);
    sound.options.push_back(percent("Sounds volume", "sounds_volume", "80",
                                    only_here("How loud this menu's sounds are.")));
  }
  sections.push_back(sound);

  Section data{T("Data"), 2, {}};
  {
    Option saves;
    saves.label = T("Saves");
    saves.help = T("Your profile, settings and tournament saves.");
#ifdef __ANDROID__
    // Android doesn't let the player open the app's folder: the saves go in a
    // zip, where they choose, and come back from one.
    saves.label = T("Export saves");
    saves.action = T("Export");
    saves.help = T("Your profile, settings and tournament saves, in a zip you can keep (in "
                   "Downloads, a cloud...) or copy to another device.");
    saves.run = [] { AndroidCall("exportSaves"); };
    data.options.push_back(saves);

    saves = Option{};
    saves.label = T("Import saves");
    saves.action = T("Import");
    saves.confirm = true;
    saves.help = T("Replaces your saves with those of an exported zip. The current ones are kept "
                   "aside in a saves-before-import folder, in case.");
    saves.run = [] { AndroidCall("importSaves"); };
#else
    saves.action = T("Open folder");
    saves.run = [user_folder] { OpenFolder(user_folder); };
#endif
    data.options.push_back(saves);

    fs::path shaders = user_folder / "cache";
    Option cache;
    cache.label = T("Shader cache");
    cache.action = T("Clear");
    cache.confirm = true;
    cache.info = [shaders] { return Size(FolderBytes(shaders)); };
    cache.run = [shaders] {
      std::error_code ec;
      fs::remove_all(shaders, ec);
    };
    cache.help = T("Shaders the game has built, kept so later matches don't stutter. Clearing "
                   "only helps if graphics look wrong after an update.");
    data.options.push_back(cache);

    Option logs;
    logs.label = T("Logs");
    logs.help = T("The game's log (fifawc14.log). Attach it when you report a problem.");
#ifdef __ANDROID__
    logs.help = T("The game's and this menu's logs, with your settings, in a zip to send (by "
                  "message, mail...) when you report a problem.");
    logs.action = T("Share");
    logs.run = [] { AndroidCall("shareLogs"); };
#else
    logs.action = T("Open folder");
    logs.run = [data_folder] { OpenFolder(data_folder); };
#endif
    data.options.push_back(logs);

#ifdef _WIN32
    Option updates = OnOff("Check for updates", "check_updates", "true",
                           T("At start, asks this project's GitHub page whether a newer version "
                             "is out, and offers it. Nothing is sent about you or your game."));
    updates.local = true;
    data.options.push_back(updates);

    Option shortcut;
    shortcut.label = T("Desktop shortcut");
    shortcut.action = T("Create");
    shortcut.info = [] { return HasDesktopShortcut() ? std::string(T("On desktop")) : std::string(); };
    shortcut.run = [data_folder] { CreateDesktopShortcut(data_folder); };
    shortcut.outcome = [] {
      return HasDesktopShortcut()
                 ? std::make_pair(std::string(T("The shortcut is on your desktop.")), true)
                 : std::make_pair(std::string(T("The shortcut couldn't be created.")), false);
    };
    shortcut.help = T("A shortcut to this launcher on your desktop, with the game's icon. Useful "
                      "for the portable version, or if you deleted the one the installer made.");
    data.options.push_back(shortcut);
#endif
  }
  sections.push_back(data);
  return sections;
}

}  // namespace launcher
