#!/bin/bash
# Compile le pont vers libadrenotools (libadrenotools_bridge.so) et ses crochets pour Android, dans WSL.
set -e
NDK=~/android-ndk-r27c
mkdir -p ~/wc14/projet/gpudriver ~/wc14/libadrenotools
rsync -a --delete /mnt/c/wc14/src/projet/gpudriver/ ~/wc14/projet/gpudriver/
rsync -a --delete --exclude=.git /mnt/c/wc14/telechargement/libadrenotools/ ~/wc14/libadrenotools/
O=~/wc14/projet/gpudriver/out
[ -f $O/build.ninja ] || cmake -S ~/wc14/projet/gpudriver -B $O -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE=$NDK/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-33 -DANDROID_STL=c++_shared \
  -DCMAKE_BUILD_TYPE=Release -DADRENOTOOLS_DIR=$HOME/wc14/libadrenotools > /tmp/pilote-cmake.log 2>&1 \
  || { tail -30 /tmp/pilote-cmake.log; exit 1; }
cmake --build $O -j 4 > /tmp/pilote.log 2>&1 || { grep -E 'error|Error' /tmp/pilote.log | head -20; exit 1; }
find $O -name '*.so' -exec ls -la {} \; | cut -c24-
