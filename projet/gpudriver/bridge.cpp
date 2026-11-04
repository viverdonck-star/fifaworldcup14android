// The GPU driver bridge for Android (libadrenotools_bridge.so): the game's
// Vulkan setup (rex::ui::vulkan::VulkanInstance) dlopens it when the player
// chose a driver of their own, such as Turnip, and calls the one function
// below. libadrenotools (BSD-2-Clause, github.com/bylaws/libadrenotools) opens
// the system Vulkan loader with that driver in place of Qualcomm's; its hooks
// (libmain_hook.so, libhook_impl.so...) sit next to this library in the APK.

#include <dlfcn.h>

#include <adrenotools/driver.h>

extern "C" __attribute__((visibility("default"))) void* adrenotools_bridge_open_vulkan(
    const char* hook_dir, const char* driver_dir, const char* driver_name) {
  return adrenotools_open_libvulkan(RTLD_NOW, ADRENOTOOLS_DRIVER_CUSTOM, nullptr, hook_dir,
                                    driver_dir, driver_name, nullptr, nullptr);
}
