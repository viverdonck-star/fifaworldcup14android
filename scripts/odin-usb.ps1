# Lance le jeu sur l'Odin par USB et va jusqu'au match (même séquence que odin-jeu.sh).
# Exemple : odin-usb.ps1 -Nom u1
param([string]$Nom = "u")
$a = "C:\wc14\outils\platform-tools\adb.exe"
$s = "C:\Users\viver\AppData\Local\Temp\claude\C--Users-viver--claude-spares-spare-Do2Bn5\5e8256b9-c7a9-4676-84b1-93538662e7af\scratchpad"
function K([string]$touches, [int]$apres) {
  foreach ($t in $touches -split ' ') { & $a shell "input keyevent --longpress $t"; Start-Sleep -Seconds 4 }
  Start-Sleep -Seconds $apres
}
function E([string]$n) {
  & $a shell "screencap -p /sdcard/WC14/e.png"; & $a pull /sdcard/WC14/e.png "$s\$Nom-$n.png" | Out-Null
  & $a shell "rm /sdcard/WC14/e.png"; "ok $Nom-$n"
}
# Réglages de l'app + clavier pour piloter le jeu.
$t = "$env:TEMP\wc14-odin.toml"
((Get-Content C:\wc14\app\fifawc14.toml) + 'mnk_mode = true') | Set-Content $t -Encoding ascii
& $a push $t /sdcard/WC14/fifawc14.toml | Out-Null
& $a shell "am force-stop com.wc14.test; rm -f /sdcard/WC14/fifawc14.log"
Start-Sleep -Seconds 2
& $a shell "am start -n com.wc14.test/.MainActivity" | Out-Null
Start-Sleep -Seconds 26
K "66 66 62 62" 5
K "62 62 62 62 62 62 62" 40
K "66" 25
K "62 62 62 62" 8
E "match"
