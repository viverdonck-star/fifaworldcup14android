#!/bin/bash
# Compile le lanceur Android (liblauncher.so) dans WSL, à partir des sources Windows.
set -e
NDK=~/android-ndk-r27c
mkdir -p ~/wc14/projet
# Les sources du lanceur et VERSION, copiées comme le reste du projet.
mkdir -p ~/wc14/projet/launcher
cp /mnt/c/wc14/src/projet/VERSION ~/wc14/projet/
rsync -a --delete /mnt/c/wc14/src/projet/launcher/src/ ~/wc14/projet/launcher/src/
rsync -a --delete /mnt/c/wc14/src/projet/launcher/android/ ~/wc14/projet/launcher/android/
# Les fichiers modifiés sous Windows arrivent avec des fins de ligne Windows : sans effet en C++.
O=~/wc14/projet/launcher/out-android
[ -f $O/build.ninja ] || cmake -S ~/wc14/projet/launcher/android -B $O -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE=$NDK/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-33 -DANDROID_STL=c++_shared \
  -DCMAKE_BUILD_TYPE=Release -DREXSDK_DIR=$HOME/wc14/sdk -DREXSDK_INSTALL=$HOME/wc14/sdk/out/install \
  > /tmp/lanceur-cmake.log 2>&1 || { tail -30 /tmp/lanceur-cmake.log; exit 1; }
cmake --build $O -j 4 -- -k 0 > /tmp/lanceur.log 2>&1 || true
echo "erreurs: $(grep -c 'error:' /tmp/lanceur.log)  echecs: $(grep -c '^FAILED' /tmp/lanceur.log)"
grep -E 'error:|undefined' /tmp/lanceur.log | sed -E 's#/home/viver/wc14/##' | sort | uniq -c | sort -rn | cut -c1-220 | head -40
ls -la $O/liblauncher.so 2>/dev/null | cut -c24-
