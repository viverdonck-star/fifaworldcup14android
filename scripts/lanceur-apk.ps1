# Compile le lanceur, refait l'APK, l'installe sur l'Odin (USB) et ouvre le lanceur avec une capture.
param([string]$Nom = "l")
$a = "C:\wc14\outils\platform-tools\adb.exe"
$s = "C:\Users\viver\AppData\Local\Temp\claude\C--Users-viver--claude-spares-spare-Do2Bn5\5e8256b9-c7a9-4676-84b1-93538662e7af\scratchpad"
wsl -d Debian -u viver --exec bash -c "tr -d '\r' < /mnt/c/wc14/scripts/lanceur-arm64.sh > /tmp/la.sh; bash /tmp/la.sh && tr -d '\r' < /mnt/c/wc14/scripts/apk2.sh > /tmp/a2.sh && bash /tmp/a2.sh < /dev/null 2>&1 | grep -E 'signature|error|Error|WC14-Test'"
& $a install -r C:\wc14\WC14-Test.apk
& $a shell "am force-stop com.wc14.test; logcat -c; am start -n com.wc14.test/.LauncherActivity" | Out-Null
Start-Sleep 10
& $a shell "screencap -p /sdcard/Download/e.png"; & $a pull /sdcard/Download/e.png "$s\$Nom.png" | Out-Null; & $a shell "rm /sdcard/Download/e.png"
& $a shell "cat /sdcard/Android/data/com.wc14.test/files/launcher.log; logcat -d | grep -E 'AndroidRuntime|FATAL|F DEBUG|SDL.*rror' | tail -15"
