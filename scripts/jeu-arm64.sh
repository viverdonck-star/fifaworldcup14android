#!/bin/bash
# Le jeu pour Android ARM64. Limite : 4 tâches, WSL n'a que 7 Go de mémoire.
set -e
NDK=~/android-ndk-r27c
mkdir -p ~/wc14/projet
cd /mnt/c/wc14/src/projet
tar --exclude=./out --exclude=./.git --exclude=./pc/out --exclude=./launcher --exclude=./assets -cf - pc | tar -xf - -C ~/wc14/projet --keep-newer-files --warning=none 2>/dev/null || true
tar --exclude=generated -cf - pc/CMakeLists.txt pc/src pc/fixes | tar -xf - -C ~/wc14/projet
cd ~/wc14/projet/pc
# rexglue pour ARM64 ne tourne pas ici : le code est déjà généré sous Windows.
sed -i 's#COMMAND $<TARGET_FILE:rex::rexglue> codegen .*#COMMAND ${CMAKE_COMMAND} -E touch_nocreate ${CMAKE_CURRENT_SOURCE_DIR}/generated/default/codegen.build.stamp#; /DEPFILE "/d' generated/rexglue.cmake
if [ ! -f out/android/build.ninja ]; then
cmake -S . -B out/android -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE=$NDK/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-33 -DANDROID_STL=c++_shared \
  -DCMAKE_BUILD_TYPE=Release -Drexglue_DIR=$HOME/wc14/sdk/out/install/lib/cmake/rexglue \
  -DCMAKE_FIND_ROOT_PATH=$HOME/wc14/sdk/out/install -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=BOTH \
  -DREXGLUE_RECOMP_DEBUG_INFO=none \
  -DCMAKE_CXX_FLAGS="-march=armv8.2-a+fp16+dotprod" 2>&1 | grep -E 'CMake Error|Error|Found ReXGlue|Configuring|Generating done' -A4 | head -30
fi
D=${1:-900}
date +%T
free -g | sed -n 2p
timeout $D cmake --build out/android -j 4 -- -k 0 > /tmp/jeu.log 2>&1 || true
date +%T
echo "erreurs: $(grep -c 'error:' /tmp/jeu.log)  echecs: $(grep -c '^FAILED' /tmp/jeu.log)"
grep -E '^\[[0-9]+/[0-9]+\]' /tmp/jeu.log | tail -1 | cut -c1-120
grep -E 'error:' /tmp/jeu.log | sed -E 's#/home/viver/wc14/##' | sort | uniq -c | sort -rn | cut -c1-175 | head -30
tail -2 /tmp/jeu.log | cut -c1-140
du -sh out/android 2>/dev/null
