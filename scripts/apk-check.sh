#!/bin/bash
N=~/android-ndk-r27c/toolchains/llvm/prebuilt/linux-x86_64/bin
L=~/wc14/sdk/out/linux-arm64
$N/llvm-nm -D --defined-only $L/librexruntime.so | grep -cE 'Java_org_libsdl_app|JNI_OnLoad'
$N/llvm-readelf -d $L/librexruntime.so | grep NEEDED | cut -c30-
$N/llvm-readelf -d $L/librexgpu-xenos.so | grep NEEDED | cut -c30- | tr '\n' ' '; echo
$N/llvm-readelf -l ~/wc14/projet/pc/out/android/libfifawc14.so | grep -A1 LOAD | head -4 | cut -c1-90
which javac java keytool aapt apksigner zipalign zip 2>&1 | head; ls /opt/nba-app 2>/dev/null
ssh -p 8022 -i ~/.ssh/odin_nba2k14 -o BatchMode=yes u0_a155@192.168.129.50 'getconf PAGESIZE; ls -ld ~/storage/shared 2>&1 | cut -c1-80; df -h /storage/emulated/0 | tail -1; which aapt; pm list packages 2>/dev/null | grep -iE "nba|shizuku" | head -3; cat ~/nba2k14/adb-port 2>/dev/null | head -2; command -v adb' < /dev/null
