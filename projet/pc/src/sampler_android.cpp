// Android test builds: sampling profiler, since perf_event_open is refused here.
//
// When the file sampler.go appears in the app folder, every thread is sampled
// 100 times a second for 8 seconds (program counter and frame pointer chain,
// through SIGPROF), and the addresses go to samples.txt. sampler.go is then removed.

#include <dirent.h>
#include <dlfcn.h>
#include <signal.h>
#include <sys/syscall.h>
#include <ucontext.h>
#include <unistd.h>

#include <atomic>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <map>
#include <string>
#include <thread>
#include <vector>

namespace {

constexpr int kDepth = 8;
std::atomic<int> g_pending{0};
uintptr_t g_frames[kDepth];
int g_frame_count = 0;

void OnSample(int, siginfo_t*, void* context) {
  auto& mc = static_cast<ucontext_t*>(context)->uc_mcontext;
  g_frames[0] = mc.pc;
  g_frames[1] = mc.regs[30];
  int count = 2;
  uintptr_t sp = mc.sp;
  uintptr_t fp = mc.regs[29];
  while (count < kDepth && fp > sp && fp - sp < (1u << 20) && !(fp & 7)) {
    auto* frame = reinterpret_cast<uintptr_t*>(fp);
    g_frames[count++] = frame[1] & 0x0000FFFFFFFFFFFF;
    sp = fp;
    fp = frame[0];
  }
  g_frame_count = count;
  g_pending.store(0, std::memory_order_release);
}

std::string ThreadName(int tid) {
  char path[64];
  std::snprintf(path, sizeof(path), "/proc/self/task/%d/comm", tid);
  char name[32] = "";
  if (FILE* file = std::fopen(path, "r")) {
    if (std::fgets(name, sizeof(name), file)) {
      name[strcspn(name, "\n")] = 0;
    }
    std::fclose(file);
  }
  return name;
}

std::string Describe(uintptr_t pc) {
  Dl_info info;
  char text[160];
  if (dladdr(reinterpret_cast<void*>(pc), &info) && info.dli_fname) {
    const char* name = strrchr(info.dli_fname, '/');
    std::snprintf(text, sizeof(text), "%s+%lx", name ? name + 1 : info.dli_fname,
                  (unsigned long)(pc - uintptr_t(info.dli_fbase)));
  } else {
    std::snprintf(text, sizeof(text), "?%lx", (unsigned long)pc);
  }
  return text;
}

void Capture(const std::string& folder) {
  using Stack = std::vector<uintptr_t>;
  std::map<std::pair<std::string, Stack>, int> samples;
  std::map<int, std::string> names;
  auto end = std::chrono::steady_clock::now() + std::chrono::seconds(8);
  int self = gettid();
  while (std::chrono::steady_clock::now() < end) {
    DIR* tasks = opendir("/proc/self/task");
    if (!tasks) {
      return;
    }
    while (dirent* entry = readdir(tasks)) {
      int tid = std::atoi(entry->d_name);
      if (!tid || tid == self) {
        continue;
      }
      auto& name = names[tid];
      if (name.empty()) {
        name = ThreadName(tid);
      }
      // Sleeping threads tell nothing about CPU use.
      char path[64], stat[256] = "";
      std::snprintf(path, sizeof(path), "/proc/self/task/%d/stat", tid);
      if (FILE* file = std::fopen(path, "r")) {
        std::fgets(stat, sizeof(stat), file);
        std::fclose(file);
      }
      const char* state = strrchr(stat, ')');
      if (!state || state[2] != 'R') {
        continue;
      }
      g_pending.store(1, std::memory_order_release);
      if (syscall(SYS_tgkill, getpid(), tid, SIGPROF)) {
        g_pending.store(0);
        continue;
      }
      auto limit = std::chrono::steady_clock::now() + std::chrono::milliseconds(3);
      while (g_pending.load(std::memory_order_acquire) &&
             std::chrono::steady_clock::now() < limit) {
      }
      if (!g_pending.load(std::memory_order_acquire)) {
        ++samples[{name, Stack(g_frames, g_frames + g_frame_count)}];
      }
    }
    closedir(tasks);
    std::this_thread::sleep_for(std::chrono::milliseconds(10));
  }
  if (FILE* out = std::fopen((folder + "/samples.txt").c_str(), "w")) {
    for (const auto& [key, count] : samples) {
      std::fprintf(out, "%d|%s", count, key.first.c_str());
      for (uintptr_t pc : key.second) {
        std::fprintf(out, "|%s", Describe(pc).c_str());
      }
      std::fprintf(out, "\n");
    }
    std::fclose(out);
  }
}

[[gnu::constructor]] void StartSampler() {
  const char* folder = std::getenv("REX_APP_DIR");
  if (!folder) {
    return;
  }
  std::string path = folder;
  struct sigaction action = {};
  action.sa_sigaction = OnSample;
  action.sa_flags = SA_SIGINFO | SA_RESTART;
  sigaction(SIGPROF, &action, nullptr);
  std::thread([path]() {
    std::string go = path + "/sampler.go";
    for (;;) {
      std::this_thread::sleep_for(std::chrono::seconds(1));
      if (access(go.c_str(), F_OK) == 0) {
        Capture(path);
        unlink(go.c_str());
      }
    }
  }).detach();
}

}  // namespace
