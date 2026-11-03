#!/bin/bash
# Refait l'APK de test sans Termux : reprend l'APK précédent (Java et manifeste inchangés)
# et remplace seulement les bibliothèques ARM64.
set -e
out=~/wc14/apk
cd $out
cp WC14-Test.apk precedent.apk
zip -q -d precedent.apk 'lib/*' 'META-INF/*'
N=~/android-ndk-r27c/toolchains/llvm/prebuilt/linux-x86_64
P=~/wc14/projet/pc/out/android; L=~/wc14/sdk/out/linux-arm64
rm -rf lib; mkdir -p lib/arm64-v8a
cp $L/librexruntime.so $L/librexgpu-xenos.so $P/libfifawc14*.so lib/arm64-v8a/
cp $N/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so lib/arm64-v8a/
$N/bin/llvm-strip --strip-unneeded lib/arm64-v8a/*.so
zip -q -r -1 precedent.apk lib
zipalign -f -p 4 precedent.apk app-aligned.apk
apksigner sign --ks ~/wc14/.cle.keystore --ks-pass file:$HOME/wc14/.cle.txt --min-sdk-version 33 --out WC14-Test.apk app-aligned.apk
apksigner verify WC14-Test.apk && echo signature-ok
rm precedent.apk
cp WC14-Test.apk /mnt/c/wc14/WC14-Test.apk
ls -la WC14-Test.apk | cut -c24-
