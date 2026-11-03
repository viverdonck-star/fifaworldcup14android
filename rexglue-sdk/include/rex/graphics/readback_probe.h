/**
 * @file        graphics/readback_probe.h
 * @brief       Diagnostic: report which host code first touches resolve output
 *
 * With readback_probe enabled, every resolve destination is made inaccessible in
 * all guest virtual views of physical memory. The first CPU access faults, gets
 * logged with the symbolized host function (recompiled sub_XXXXXXXX names come
 * from the PDB) and the page protection is restored. Windows only; slow; for
 * finding game code that consumes GPU-rendered data on the CPU.
 */

#pragma once

#include <cstdint>

#include <rex/cvar.h>

REXCVAR_DECLARE(bool, readback_probe);

namespace rex::memory {
class Memory;
}

namespace rex::graphics {

// Arms the probe for a resolve that wrote [physical_address, +length).
void ReadbackProbeArm(rex::memory::Memory& memory, uint32_t physical_address, uint32_t length,
                      uint32_t format);

}  // namespace rex::graphics
