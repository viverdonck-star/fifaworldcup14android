"""Porte vers Vulkan le suivi des résolutions restées en mémoire GPU (patch 0001)."""


def R(p, a, b):
    s = open(p, newline="").read()
    assert a in s, (p, a)
    open(p, "w", newline="").write(s.replace(a, b, 1))


h = "include/rex/graphics/vulkan/command_processor.h"
R(h, """  bool IssueCopy_ReadbackResolvePath();
  bool IssueDraw_MemexportReadbackFullPath(uint32_t total_size);""", """  bool IssueCopy_ReadbackResolvePath();
  // The game's CPU readers of GPU results: resolves stay in GPU memory, and only
  // what the guest actually reads comes back (see command_processor.h).
  bool SupportsGpuMemoryCopy() const override { return true; }
  void ExecuteGpuMemoryCopy(uint32_t dst_physical, uint32_t src_physical,
                            uint32_t length) override;
  void ExecuteGpuMemoryReadback(uint32_t physical_address, uint32_t length) override;
  void DestroyGpuMemoryReadbackBuffer();
  static void GpuNewerGlobalWatchCallback(const std::unique_lock<std::recursive_mutex>& global_lock,
                                          void* context, uint32_t address_first,
                                          uint32_t address_last, bool invalidated_by_gpu);
  bool IssueDraw_MemexportReadbackFullPath(uint32_t total_size);""")
R(h, """  std::unordered_map<uint64_t, ReadbackBuffer> readback_buffers_;
""", """  std::unordered_map<uint64_t, ReadbackBuffer> readback_buffers_;
  SharedMemory::GlobalWatchHandle gpu_newer_watch_ = nullptr;
  VkBuffer gpu_memory_readback_buffer_ = VK_NULL_HANDLE;
  VkDeviceMemory gpu_memory_readback_memory_ = VK_NULL_HANDLE;
  void* gpu_memory_readback_mapping_ = nullptr;
  uint32_t gpu_memory_readback_size_ = 0;
""")

c = "src/graphics/vulkan/command_processor.cpp"
R(c, """    REXGPU_ERROR("Failed to initialize shared memory");
    return false;
  }

""", """    REXGPU_ERROR("Failed to initialize shared memory");
    return false;
  }
  // CPU writes make guest memory authoritative again for those pages.
  gpu_newer_watch_ = shared_memory_->RegisterGlobalWatch(GpuNewerGlobalWatchCallback, this);

""")
R(c, """  primitive_processor_.reset();

  shared_memory_.reset();
""", """  primitive_processor_.reset();

  DestroyGpuMemoryReadbackBuffer();
  if (shared_memory_ && gpu_newer_watch_) {
    shared_memory_->UnregisterGlobalWatch(gpu_newer_watch_);
    gpu_newer_watch_ = nullptr;
  }
  shared_memory_.reset();
""")
R(c, """    uint32_t written_address, written_length;
    return render_target_cache_->Resolve(*memory_, *shared_memory_, *texture_cache_,
                                         written_address, written_length);
  }

  return IssueCopy_ReadbackResolvePath();
}
""", """    uint32_t written_address, written_length;
    bool result = render_target_cache_->Resolve(*memory_, *shared_memory_, *texture_cache_,
                                                written_address, written_length);
    MarkGpuMemoryNewer(written_address, written_length, true);
    return result;
  }

  return IssueCopy_ReadbackResolvePath();
}

void VulkanCommandProcessor::GpuNewerGlobalWatchCallback(
    const std::unique_lock<std::recursive_mutex>& global_lock, void* context,
    uint32_t address_first, uint32_t address_last, bool invalidated_by_gpu) {
  (void)global_lock;
  if (invalidated_by_gpu) {
    return;
  }
  static_cast<VulkanCommandProcessor*>(context)->MarkGpuMemoryNewer(
      address_first, address_last - address_first + 1, false);
}

void VulkanCommandProcessor::ExecuteGpuMemoryCopy(uint32_t dst_physical, uint32_t src_physical,
                                                  uint32_t length) {
  if (!BeginSubmission(true)) {
    return;
  }
  // Source holds resolve output; destination pages may be partially covered, so
  // both must be current in GPU memory before copying (uploads if not).
  if (!shared_memory_->RequestRange(src_physical, length) ||
      !shared_memory_->RequestRange(dst_physical, length)) {
    REXGPU_WARN("GPU memory copy {:08X} -> {:08X} +{:X}: shared memory request failed",
                src_physical, dst_physical, length);
    return;
  }
  // Source and destination may overlap, so bounce through the scratch buffer.
  ScratchBufferAcquisition scratch = AcquireScratchGpuBuffer(length, VK_PIPELINE_STAGE_TRANSFER_BIT,
                                                             VK_ACCESS_TRANSFER_WRITE_BIT);
  if (scratch.buffer() == VK_NULL_HANDLE) {
    return;
  }
  shared_memory_->Use(VulkanSharedMemory::Usage::kRead);
  SubmitBarriers(true);
  VkBufferCopy region = {};
  region.srcOffset = src_physical;
  region.size = length;
  deferred_command_buffer_.CmdVkCopyBuffer(shared_memory_->buffer(), scratch.buffer(), 1, &region);
  PushBufferMemoryBarrier(scratch.buffer(), 0, length, VK_PIPELINE_STAGE_TRANSFER_BIT,
                          VK_PIPELINE_STAGE_TRANSFER_BIT, VK_ACCESS_TRANSFER_WRITE_BIT,
                          VK_ACCESS_TRANSFER_READ_BIT);
  scratch.SetAccessMask(VK_ACCESS_TRANSFER_READ_BIT);
  shared_memory_->Use(VulkanSharedMemory::Usage::kTransferDestination,
                      std::pair<uint32_t, uint32_t>(dst_physical, length));
  SubmitBarriers(true);
  region.srcOffset = 0;
  region.dstOffset = dst_physical;
  deferred_command_buffer_.CmdVkCopyBuffer(scratch.buffer(), shared_memory_->buffer(), 1, &region);
  // Invalidates textures over dst and keeps the pages valid (GPU-owned).
  shared_memory_->RangeWrittenByGpu(dst_physical, length);
  MarkGpuMemoryNewer(dst_physical, length, true);
}

void VulkanCommandProcessor::DestroyGpuMemoryReadbackBuffer() {
  const ui::vulkan::VulkanDevice* const vulkan_device = GetVulkanDevice();
  const ui::vulkan::VulkanDevice::Functions& dfn = vulkan_device->functions();
  const VkDevice device = vulkan_device->device();
  if (gpu_memory_readback_mapping_) {
    dfn.vkUnmapMemory(device, gpu_memory_readback_memory_);
    gpu_memory_readback_mapping_ = nullptr;
  }
  if (gpu_memory_readback_buffer_ != VK_NULL_HANDLE) {
    dfn.vkDestroyBuffer(device, gpu_memory_readback_buffer_, nullptr);
    gpu_memory_readback_buffer_ = VK_NULL_HANDLE;
  }
  if (gpu_memory_readback_memory_ != VK_NULL_HANDLE) {
    dfn.vkFreeMemory(device, gpu_memory_readback_memory_, nullptr);
    gpu_memory_readback_memory_ = VK_NULL_HANDLE;
  }
  gpu_memory_readback_size_ = 0;
}

void VulkanCommandProcessor::ExecuteGpuMemoryReadback(uint32_t physical_address, uint32_t length) {
  if (!BeginSubmission(true) || !shared_memory_->RequestRange(physical_address, length)) {
    return;
  }
  const ui::vulkan::VulkanDevice* const vulkan_device = GetVulkanDevice();
  const ui::vulkan::VulkanDevice::Functions& dfn = vulkan_device->functions();
  const VkDevice device = vulkan_device->device();
  if (length > gpu_memory_readback_size_) {
    if (!AwaitAllQueueOperationsCompletion()) {
      return;
    }
    DestroyGpuMemoryReadbackBuffer();
    uint32_t size = AlignReadbackBufferSize(length);
    if (!ui::vulkan::util::CreateDedicatedAllocationBuffer(
            vulkan_device, size, VK_BUFFER_USAGE_TRANSFER_DST_BIT,
            ui::vulkan::util::MemoryPurpose::kReadback, gpu_memory_readback_buffer_,
            gpu_memory_readback_memory_)) {
      REXGPU_ERROR("Failed to create a {} MB Vulkan GPU memory readback buffer", size >> 20);
      return;
    }
    if (dfn.vkMapMemory(device, gpu_memory_readback_memory_, 0, VK_WHOLE_SIZE, 0,
                        &gpu_memory_readback_mapping_) != VK_SUCCESS) {
      REXGPU_ERROR("Failed to map the Vulkan GPU memory readback buffer");
      gpu_memory_readback_mapping_ = nullptr;
      DestroyGpuMemoryReadbackBuffer();
      return;
    }
    gpu_memory_readback_size_ = size;
    if (!BeginSubmission(true)) {
      return;
    }
  }
  shared_memory_->Use(VulkanSharedMemory::Usage::kRead);
  SubmitBarriers(true);
  VkBufferCopy region = {};
  region.srcOffset = physical_address;
  region.size = length;
  deferred_command_buffer_.CmdVkCopyBuffer(shared_memory_->buffer(), gpu_memory_readback_buffer_,
                                           1, &region);
  PushBufferMemoryBarrier(gpu_memory_readback_buffer_, 0, length, VK_PIPELINE_STAGE_TRANSFER_BIT,
                          VK_PIPELINE_STAGE_HOST_BIT, VK_ACCESS_TRANSFER_WRITE_BIT,
                          VK_ACCESS_HOST_READ_BIT);
  if (!AwaitAllQueueOperationsCompletion()) {
    return;
  }
  VkMappedMemoryRange range = {};
  range.sType = VK_STRUCTURE_TYPE_MAPPED_MEMORY_RANGE;
  range.memory = gpu_memory_readback_memory_;
  range.size = VK_WHOLE_SIZE;
  dfn.vkInvalidateMappedMemoryRanges(device, 1, &range);
  // Through the physical membase: does not trip the CPU write watches, so the
  // GPU copy stays valid.
  std::memcpy(memory_->TranslatePhysical(physical_address), gpu_memory_readback_mapping_, length);
}
""")
