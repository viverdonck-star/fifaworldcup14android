# Essai des bandes noires sans le lanceur : retire des réglages du fifawc14.toml de l'app,
# démarre directement le jeu (identité de l'app), capture l'intro.
param([string]$Retirer = "", [string]$Nom = "by")
$a = "C:\wc14\outils\platform-tools\adb.exe"
$s = "C:\Users\viver\AppData\Local\Temp\claude\C--Users-viver--claude-spares-spare-Do2Bn5\5e8256b9-c7a9-4676-84b1-93538662e7af\scratchpad"
$f = "/sdcard/Android/data/com.wc14.test/files/fifawc14.toml"
& $a shell "am force-stop com.wc14.test"
foreach ($k in ($Retirer -split ';' | Where-Object { $_ })) { & $a shell "sed -i '/^$k *=/d' $f" }
& $a shell "run-as com.wc14.test am start -n com.wc14.test/.MainActivity"
Start-Sleep 30
& $a shell "screencap -p /sdcard/Download/e.png"; & $a pull /sdcard/Download/e.png "$s\$Nom.png" 2>$null | Out-Null; & $a shell "rm /sdcard/Download/e.png"
