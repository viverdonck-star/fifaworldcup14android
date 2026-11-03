#!/bin/bash
# APK de test : Java SDL + bibliothèques ARM64. aapt tourne sur l'Odin (celui de Debian ne lit pas Android 15).
set -e
out=~/wc14/apk; tools=/opt/nba-app
key=~/.ssh/odin_nba2k14; t=u0_a155@192.168.129.50
S="ssh -i $key -p 8022 -o BatchMode=yes $t"
rm -rf $out/classes $out/dex $out/lib; mkdir -p $out/classes $out/dex $out/lib/arm64-v8a
cd $out
if [ ! -f android.jar ]; then
  python3 -c "import urllib.request as u; u.urlretrieve('https://dl.google.com/android/repository/platform-35_r02.zip','p.zip')"
  python3 -c "import zipfile; z=zipfile.ZipFile('p.zip'); n=[x for x in z.namelist() if x.endswith('/android.jar')][0]; open('android.jar','wb').write(z.read(n))"
  rm p.zip
fi
J=~/wc14/sdk/thirdparty/sdl3/android-project/app/src/main/java
javac -nowarn -Xlint:none -source 8 -target 8 -bootclasspath android.jar -d classes \
  $(find $J -name '*.java') $(find /mnt/c/wc14/app/src -name '*.java') 2>&1 | grep -v '^Note\|warning' | head -10 || true
java -cp $tools/d8.jar com.android.tools.r8.D8 --release --min-api 33 --lib android.jar --output dex \
  $(find classes -name '*.class') 2>&1 | grep -v 'Warning\|Missing class' | head -5 || true
test -f dex/classes.dex
tr -d '\r' < /mnt/c/wc14/app/AndroidManifest.xml > AndroidManifest.xml
$S 'rm -rf ~/app-res-wc; mkdir ~/app-res-wc; cat > ~/app-res-wc/AndroidManifest.xml' < AndroidManifest.xml
$S 'cd ~/app-res-wc && aapt package -f -M AndroidManifest.xml -I /system/framework/framework-res.apk -F base.apk && cat base.apk' > app-unsigned.apk
$S 'rm -rf ~/app-res-wc'
(cd dex && zip -q ../app-unsigned.apk classes.dex)
N=~/android-ndk-r27c/toolchains/llvm/prebuilt/linux-x86_64
P=~/wc14/projet/pc/out/android; L=~/wc14/sdk/out/linux-arm64
cp $L/librexruntime.so $L/librexgpu-xenos.so $P/libfifawc14*.so $out/lib/arm64-v8a/
cp $N/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so $out/lib/arm64-v8a/
$N/bin/llvm-strip --strip-unneeded lib/arm64-v8a/*.so
ls -la lib/arm64-v8a | cut -c24-
zip -q -r -1 app-unsigned.apk lib
zipalign -f -p 4 app-unsigned.apk app-aligned.apk
if [ ! -f ~/wc14/.cle.keystore ]; then
  head -c 24 /dev/urandom | base64 | tr -d '/+=' > ~/wc14/.cle.txt; chmod 600 ~/wc14/.cle.txt
  keytool -genkeypair -keystore ~/wc14/.cle.keystore -storepass:file ~/wc14/.cle.txt -alias wc14 \
    -keyalg RSA -keysize 2048 -validity 10000 -dname CN=wc14test 2>/dev/null
fi
apksigner sign --ks ~/wc14/.cle.keystore --ks-pass file:$HOME/wc14/.cle.txt --min-sdk-version 33 --out WC14-Test.apk app-aligned.apk
apksigner verify WC14-Test.apk && echo signature-ok
ls -la WC14-Test.apk | cut -c24-
