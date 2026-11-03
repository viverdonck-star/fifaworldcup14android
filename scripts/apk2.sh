#!/bin/bash
# APK complet (lanceur + jeu) sans Termux : le manifeste est encodé par axml.py.
set -e
out=~/wc14/apk; tools=/opt/nba-app
rm -rf $out/classes $out/dex $out/lib $out/app-unsigned.apk; mkdir -p $out/classes $out/dex $out/lib/arm64-v8a
cd $out
J=~/wc14/sdk/thirdparty/sdl3/android-project/app/src/main/java
javac -nowarn -Xlint:none -source 8 -target 8 -bootclasspath android.jar -d classes \
  $(find $J -name '*.java') $(find /mnt/c/wc14/app/src -name '*.java') 2>&1 | grep -v '^Note\|warning' | head -10 || true
java -cp $tools/d8.jar com.android.tools.r8.D8 --release --min-api 33 --lib android.jar --output dex \
  $(find classes -name '*.class') 2>&1 | grep -v 'Warning\|Missing class' | head -5 || true
test -f dex/classes.dex
# L'icône (res/) : compilée par aapt avec un manifeste réduit et une icône adaptative vide
# (sans attribut android:, donc sans la bibliothèque Android qu'il ne sait pas lire) ;
# l'icône adaptative réelle est ensuite encodée par axml.py avec les identifiants obtenus.
rm -rf resapk man && mkdir -p resapk man && cp -r /mnt/c/wc14/app/res resapk/res
printf '<manifest package="com.wc14.test"/>' > resapk/AndroidManifest.xml
printf '<adaptive-icon/>' > resapk/res/mipmap-anydpi-v26/app.xml
(cd resapk && aapt package -f -M AndroidManifest.xml -S res -F res.apk && unzip -q -o res.apk resources.arsc 'res/*' -d out)
REFS=$(aapt dump resources resapk/res.apk | sed -nE 's/.*resource (0x7f[0-9a-f]+) com\.wc14\.test:([a-z]+\/[a-z_]+):.*/@\2=\1/p' | sort -u)
echo "ressources: $REFS"
ADAPT=$(ls resapk/out/res/mipmap-anydpi*/app.xml)
tr -d '\r' < /mnt/c/wc14/app/res/mipmap-anydpi-v26/app.xml > resapk/app.src.xml
python3 /mnt/c/wc14/scripts/axml.py resapk/app.src.xml $ADAPT $REFS
tr -d '\r' < /mnt/c/wc14/app/AndroidManifest.xml > AndroidManifest.src.xml
python3 /mnt/c/wc14/scripts/axml.py AndroidManifest.src.xml man/AndroidManifest.xml $REFS
(cd man && zip -q -X ../app-unsigned.apk AndroidManifest.xml)
(cd resapk/out && zip -q -0 ../../app-unsigned.apk resources.arsc && zip -q -r ../../app-unsigned.apk res)
(cd dex && zip -q ../app-unsigned.apk classes.dex)
N=~/android-ndk-r27c/toolchains/llvm/prebuilt/linux-x86_64
P=~/wc14/projet/pc/out/android; L=~/wc14/sdk/out/linux-arm64
cp $L/librexruntime.so $L/librexgpu-xenos.so $P/libfifawc14*.so lib/arm64-v8a/
cp ~/wc14/projet/launcher/out-android/liblauncher.so lib/arm64-v8a/
cp $N/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so lib/arm64-v8a/
$N/bin/llvm-strip --strip-unneeded lib/arm64-v8a/*.so
zip -q -r -1 app-unsigned.apk lib
zipalign -f -p 4 app-unsigned.apk app-aligned.apk
apksigner sign --ks ~/wc14/.cle.keystore --ks-pass file:$HOME/wc14/.cle.txt --min-sdk-version 33 --out WC14-Test.apk app-aligned.apk
apksigner verify WC14-Test.apk && echo signature-ok
aapt dump xmltree WC14-Test.apk AndroidManifest.xml 2>/dev/null | head -60
cp WC14-Test.apk /mnt/c/wc14/WC14-Test.apk
ls -la WC14-Test.apk | cut -c24-
