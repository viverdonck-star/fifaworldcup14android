/**
 * @file        graphics/readback_probe.cpp
 * @brief       Diagnostic: report which host code first touches resolve output
 */

#include <rex/graphics/readback_probe.h>

#include <rex/logging/macros.h>
#include <rex/system/xmemory.h>

REXCVAR_DEFINE_BOOL(readback_probe, false, "GPU",
                    "Diagnostic: log which host function first touches each resolve "
                    "destination (Windows, slow)");

#if defined(_WIN32)

#include <Windows.h>
#include <DbgHelp.h>

#include <mutex>
#include <set>
#include <string>
#include <vector>

#pragma comment(lib, "dbghelp.lib")

namespace rex::graphics {
namespace {

struct ArmedPage {
  uint8_t* host_page;
  DWORD old_protect;
};

struct ArmedRange {
  uint32_t physical_address;
  uint32_t length;
  uint32_t format;
  std::vector<ArmedPage> pages;
};

std::mutex g_mutex;
std::vector<ArmedRange> g_ranges;
std::set<std::string> g_reported;  // "function|address|length|r/w" already logged
PVOID g_veh = nullptr;
bool g_symbols_ready = false;
size_t g_page_size = 4096;

std::string Symbolize(uintptr_t rip) {
  HANDLE process = GetCurrentProcess();
  if (!g_symbols_ready) {
    SymSetOptions(SYMOPT_UNDNAME | SYMOPT_DEFERRED_LOADS);
    SymInitialize(process, nullptr, TRUE);
    g_symbols_ready = true;
  }
  alignas(SYMBOL_INFO) char buffer[sizeof(SYMBOL_INFO) + 256];
  auto* symbol = reinterpret_cast<SYMBOL_INFO*>(buffer);
  symbol->SizeOfStruct = sizeof(SYMBOL_INFO);
  symbol->MaxNameLen = 255;
  DWORD64 displacement = 0;
  if (SymFromAddr(process, rip, &displacement, symbol)) {
    return std::string(symbol->Name) + "+0x" + std::to_string(displacement);
  }
  return "?";
}

void Restore(ArmedRange& range) {
  for (const ArmedPage& page : range.pages) {
    DWORD ignored;
    VirtualProtect(page.host_page, g_page_size, page.old_protect, &ignored);
  }
  range.pages.clear();
}

LONG CALLBACK ProbeHandler(EXCEPTION_POINTERS* info) {
  if (info->ExceptionRecord->ExceptionCode != EXCEPTION_ACCESS_VIOLATION ||
      info->ExceptionRecord->NumberParameters < 2) {
    return EXCEPTION_CONTINUE_SEARCH;
  }
  auto fault = static_cast<uintptr_t>(info->ExceptionRecord->ExceptionInformation[1]);
  bool is_write = info->ExceptionRecord->ExceptionInformation[0] == 1;
  std::lock_guard lock(g_mutex);
  for (auto it = g_ranges.begin(); it != g_ranges.end(); ++it) {
    for (const ArmedPage& page : it->pages) {
      auto base = reinterpret_cast<uintptr_t>(page.host_page);
      if (fault < base || fault >= base + g_page_size) {
        continue;
      }
      std::string function = Symbolize(info->ContextRecord->Rip);
      std::string key = function.substr(0, function.find('+')) + "|" +
                        std::to_string(it->physical_address) + "|" + std::to_string(it->length) +
                        (is_write ? "|w" : "|r");
      if (g_reported.insert(key).second) {
        REXGPU_WARN("Readback probe: {} {} resolve {:08X} +{:X} (fmt {}) at host {:016X}",
                    function, is_write ? "WRITES" : "reads", it->physical_address, it->length,
                    it->format, fault);
      }
      Restore(*it);
      g_ranges.erase(it);
      return EXCEPTION_CONTINUE_EXECUTION;
    }
  }
  return EXCEPTION_CONTINUE_SEARCH;
}

}  // namespace

void ReadbackProbeArm(rex::memory::Memory& memory, uint32_t physical_address, uint32_t length,
                      uint32_t format) {
  if (!REXCVAR_GET(readback_probe) || !length) {
    return;
  }
  std::lock_guard lock(g_mutex);
  if (!g_veh) {
    SYSTEM_INFO system_info;
    GetSystemInfo(&system_info);
    g_page_size = system_info.dwPageSize;
    g_veh = AddVectoredExceptionHandler(1, ProbeHandler);
  }
  // Re-arming a destination: drop the previous (untouched) arming first.
  for (auto it = g_ranges.begin(); it != g_ranges.end();) {
    if (it->physical_address == physical_address) {
      Restore(*it);
      it = g_ranges.erase(it);
    } else {
      ++it;
    }
  }
  ArmedRange range{physical_address, length, format, {}};
  // The same physical page is visible through the A0/C0/E0 guest views; protect
  // the host pages of every view that maps it.
  for (uint32_t view_base : {0xA0000000u, 0xC0000000u, 0xE0000000u}) {
    for (uint32_t delta : {0u, 0x1000u}) {
      uint32_t virtual_address = view_base + physical_address - delta;
      if (memory.GetPhysicalAddress(virtual_address) != physical_address) {
        continue;
      }
      auto* host = memory.TranslateVirtual<uint8_t*>(virtual_address);
      auto first = reinterpret_cast<uintptr_t>(host) & ~uintptr_t(g_page_size - 1);
      auto last = (reinterpret_cast<uintptr_t>(host) + length - 1) & ~uintptr_t(g_page_size - 1);
      for (uintptr_t page = first; page <= last; page += g_page_size) {
        DWORD old_protect;
        if (VirtualProtect(reinterpret_cast<void*>(page), g_page_size, PAGE_NOACCESS,
                           &old_protect)) {
          range.pages.push_back({reinterpret_cast<uint8_t*>(page), old_protect});
        }
      }
      break;
    }
  }
  if (!range.pages.empty()) {
    g_ranges.push_back(std::move(range));
  }
}

}  // namespace rex::graphics

#else

namespace rex::graphics {
void ReadbackProbeArm(rex::memory::Memory&, uint32_t, uint32_t, uint32_t) {}
}  // namespace rex::graphics

#endif
