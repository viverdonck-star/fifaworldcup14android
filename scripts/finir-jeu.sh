#!/bin/bash
cd ~/wc14/projet/pc
[ -f generated/default/fifawc14_register.cpp.orig ] || python3 /mnt/c/wc14/scripts/table-register.py generated/default/fifawc14_register.cpp
sed -n '/^}  \/\/ namespace/,$p' generated/default/fifawc14_register.cpp | head -12 | cut -c1-100
cd out/android
date +%T
timeout 1200 ninja -j 2 2>&1 | tail -14 | cut -c1-220
date +%T
ls -la libfifawc14*.so | cut -c24-
~/android-ndk-r27c/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-readelf -d libfifawc14.so 2>/dev/null | grep NEEDED | cut -c30-
~/android-ndk-r27c/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-nm -D --defined-only libfifawc14.so 2>/dev/null | grep -E ' (SDL_main|main|JNI_OnLoad|Java_org_libsdl_app_SDLActivity_nativeSetupJNI)$'
