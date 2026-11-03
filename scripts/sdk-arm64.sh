#!/bin/bash
# SDK pour Android ARM64. Copie dans WSL : les compilations sur /mnt/c sont très lentes.
set -e
NDK=~/android-ndk-r27c
mkdir -p ~/wc14/sdk
cd /mnt/c/wc14/src/sdk
tar --exclude=./out --exclude=./.git --exclude=./thirdparty/moltenvk -cf - . | tar -xf - -C ~/wc14/sdk --keep-newer-files --warning=none 2>/dev/null || true
tar --exclude=./out --exclude=./.git --exclude=./thirdparty -cf - . | tar -xf - -C ~/wc14/sdk
cd ~/wc14/sdk
git init -q 2>/dev/null || true
[ -f out/android/build.ninja ] || \
cmake -S . -B out/android -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE=$NDK/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-33 -DANDROID_STL=c++_shared \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$HOME/wc14/sdk/out/install \
  -DCMAKE_C_FLAGS="-march=armv8.2-a+fp16+dotprod" -DCMAKE_CXX_FLAGS="-march=armv8.2-a+fp16+dotprod" \
  -DREXGLUE_USE_VULKAN=ON 2>&1 | grep -E 'CMake Error|Error|Graphics:|Configuring|Generating' | head -20
timeout 1500 cmake --build out/android -j 4 -- -k 0 > /tmp/arm64.log 2>&1 || true
echo "erreurs: $(grep -c 'error:' /tmp/arm64.log)  echecs: $(grep -c '^FAILED' /tmp/arm64.log)"
grep -E '^\[[0-9]+/[0-9]+\]' /tmp/arm64.log | tail -1 | cut -c1-120
grep -E 'error:' /tmp/arm64.log | sed -E 's#/home/viver/wc14/sdk/##' | sort | uniq -c | sort -rn | cut -c1-175 | head -30
tail -1 /tmp/arm64.log | cut -c1-120
