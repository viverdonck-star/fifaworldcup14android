// Lit les capacités Vulkan utiles au port. Usage : vkq [chemin du pilote]
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <vulkan/vulkan.h>

int main(int argc, char** argv) {
  const char* lib = argc > 1 ? argv[1] : "libvulkan.so";
  void* h = dlopen(lib, RTLD_NOW | RTLD_LOCAL);
  if (!h) { printf("dlopen KO: %s\n", dlerror()); return 1; }
  PFN_vkGetInstanceProcAddr gipa = (PFN_vkGetInstanceProcAddr)dlsym(h, "vkGetInstanceProcAddr");
  if (!gipa) gipa = (PFN_vkGetInstanceProcAddr)dlsym(h, "vk_icdGetInstanceProcAddr");
  if (!gipa) { printf("pas de GetInstanceProcAddr\n"); return 1; }
#define IF(n) PFN_##n n = (PFN_##n)gipa(inst, #n)
  VkInstance inst = NULL;
  IF(vkCreateInstance);
  VkApplicationInfo app = {VK_STRUCTURE_TYPE_APPLICATION_INFO};
  app.apiVersion = VK_API_VERSION_1_1;
  VkInstanceCreateInfo ci = {VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO};
  ci.pApplicationInfo = &app;
  VkResult r = vkCreateInstance(&ci, NULL, &inst);
  if (r) { printf("vkCreateInstance KO: %d\n", r); return 1; }
  IF(vkEnumeratePhysicalDevices);
  IF(vkGetPhysicalDeviceProperties2);
  IF(vkGetPhysicalDeviceFeatures2);
  IF(vkEnumerateDeviceExtensionProperties);
  uint32_t n = 1;
  VkPhysicalDevice pd;
  vkEnumeratePhysicalDevices(inst, &n, &pd);
  if (!n) { printf("aucun GPU\n"); return 1; }

  VkPhysicalDeviceDriverProperties drv = {VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DRIVER_PROPERTIES};
  VkPhysicalDeviceProperties2 p = {VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2, &drv};
  vkGetPhysicalDeviceProperties2(pd, &p);
  printf("GPU: %s | Vulkan %u.%u.%u | pilote: %s %s\n", p.properties.deviceName,
         VK_API_VERSION_MAJOR(p.properties.apiVersion), VK_API_VERSION_MINOR(p.properties.apiVersion),
         VK_API_VERSION_PATCH(p.properties.apiVersion), drv.driverName, drv.driverInfo);

  VkPhysicalDeviceFragmentShaderInterlockFeaturesEXT il = {
      VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FRAGMENT_SHADER_INTERLOCK_FEATURES_EXT};
  VkPhysicalDeviceFeatures2 f = {VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2, &il};
  vkGetPhysicalDeviceFeatures2(pd, &f);
  printf("fragmentShaderSampleInterlock=%d PixelInterlock=%d ShadingRateInterlock=%d\n",
         il.fragmentShaderSampleInterlock, il.fragmentShaderPixelInterlock,
         il.fragmentShaderShadingRateInterlock);
  VkPhysicalDeviceFeatures* b = &f.features;
  printf("shaderStorageImageMultisample=%d fragmentStoresAndAtomics=%d sampleRateShading=%d "
         "geometryShader=%d tessellationShader=%d dualSrcBlend=%d textureCompressionBC=%d "
         "shaderInt64=%d independentBlend=%d\n",
         b->shaderStorageImageMultisample, b->fragmentStoresAndAtomics, b->sampleRateShading,
         b->geometryShader, b->tessellationShader, b->dualSrcBlend, b->textureCompressionBC,
         b->shaderInt64, b->independentBlend);

  uint32_t c = 0;
  vkEnumerateDeviceExtensionProperties(pd, NULL, &c, NULL);
  VkExtensionProperties* e = calloc(c, sizeof(*e));
  vkEnumerateDeviceExtensionProperties(pd, NULL, &c, e);
  const char* w[] = {"interlock", "rasterization_order", "ORDER_ATTACHMENT", "shader_stencil_export",
                     "custom_border", "memory_budget", "non_seamless", "robustness2",
                     "dynamic_rendering", "tile_image", "load_store_op"};
  printf("%u extensions; utiles:\n", c);
  for (uint32_t i = 0; i < c; i++)
    for (size_t k = 0; k < sizeof(w) / sizeof(*w); k++)
      if (strcasestr(e[i].extensionName, w[k])) { printf("  %s\n", e[i].extensionName); break; }
  return 0;
}
