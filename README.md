
# 2014 FIFA World Cup Brazil on Android (AYN Odin 3)

An Android port of the Xbox 360 game *2014 FIFA World Cup Brazil*, built as a static
recompilation (ReXGlue): the game's PowerPC code is translated to C++ and compiled for
ARM64, and its Xenos GPU commands are translated to Vulkan. It is not an emulator.

The game itself is not included: you need your own Xbox 360 disc image (.iso).

## Features

- Full game launcher with the game's own look (menu, settings, controls, about)
- 40 FPS (recommended, cooler device) or 60 FPS, with 30 FPS cutscenes as an option
- Recommended settings by default, each one explaining the risk of changing it
- GPU driver choice: the device's own, built-in Mesa Turnip, or any imported driver
- Save export and import, and log sharing for bug reports
- Disc image check showing the game's region and version (Europe / USA / other)
- Clear message on unsupported devices

## Repository layout

| Folder | Contents |
|---|---|
| `projet/` | The original PC project ([HossEz/fifa-world-cup-2014-recompiled](https://github.com/HossEz/fifa-world-cup-2014-recompiled), commit `6167d07`) with the Android changes: Android launcher (`launcher/android/`), fixes, generated code |
| `rexglue-sdk/` | The ReXGlue SDK (`bd833a2`) with the original project's 40 patches and the Android / ARM64 / Vulkan (Adreno) changes |
| `android-app/` | The Android app: manifest, Java activities (launcher and game), icon, settings, changelog, compatibility notes |
| `scripts/` | Build (WSL Debian + Android NDK r27c), APK packaging, adb test and measurement scripts |
| `TRANSFERT-PORT-ANDROID.md` | Development log: problems, causes, solutions and measurements (in French) |

## Requirements

- Android 13 or later, 64-bit ARM (arm64-v8a)
- Vulkan 1.1; a recent Snapdragon (Adreno 7xx / 8xx) is recommended
- Tested on the AYN Odin 3 (Snapdragon 8 Elite, Adreno 830)

See `android-app/COMPATIBILITE.md` for details.

## Building

Built under WSL (Debian) with the Android NDK r27c, in this order:

1. `scripts/sdk-arm64.sh`: the ReXGlue runtime
2. `scripts/jeu-arm64.sh`: the recompiled game
3. `scripts/lanceur-arm64.sh`: the launcher
4. `scripts/pilote-arm64.sh`: the GPU driver loader (libadrenotools bridge)
5. `scripts/apk2.sh`: the APK (`RELEASE=1` for a build without debugging)

Not in this repository: the game's disc image, the APK, the signing key, build outputs
and tools (NDK, adb, CMake).

## Credits

ReXGlue and Xenia (BSD), FFmpeg (LGPL), SDL (zlib), Dear ImGui (MIT), libmspack (LGPL),
stb (public domain / MIT), libadrenotools (BSD 2-Clause), Mesa Turnip (MIT).

Unofficial fan project, not affiliated with or endorsed by Electronic Arts, EA Sports,
FIFA or Microsoft.
