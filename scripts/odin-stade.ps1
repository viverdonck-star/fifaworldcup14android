# Relance l'app sur l'Odin (USB), Play, va jusqu'à la présentation du match et la capture,
# puis ferme le jeu. Réglages en plus du fifawc14.toml de l'app : -Reglages "cle = valeur;cle2 = valeur"
# (retirés à la fin). Exemple : odin-stade.ps1 -Nom d1 -Reglages "depth_float24_round = true"
param([string]$Nom = "s", [string]$Reglages = "")
$a = "C:\wc14\outils\platform-tools\adb.exe"
$s = "C:\Users\viver\AppData\Local\Temp\claude\C--Users-viver--claude-spares-spare-Do2Bn5\5e8256b9-c7a9-4676-84b1-93538662e7af\scratchpad"
$f = "/sdcard/Android/data/com.wc14.test/files"
function K([string]$touches, [int]$apres) { foreach ($t in $touches -split ' ') { & $a shell "input keyevent --longpress $t"; Start-Sleep -Seconds 4 }; Start-Sleep -Seconds $apres }
function E([string]$n) { & $a shell "screencap -p /sdcard/Download/e.png"; & $a pull /sdcard/Download/e.png "$s\$Nom-$n.png" 2>$null | Out-Null; & $a shell "rm /sdcard/Download/e.png"; "$Nom-$n" }
& $a shell "am force-stop com.wc14.test"
# Les essais vont dans le fichier, marqués pour être retirés.
& $a shell "sed -i '/# essai$/d' $f/fifawc14.toml"
foreach ($l in ($Reglages -split ';' | Where-Object { $_ })) {
  $k = ($l -split '=')[0].Trim()
  & $a shell "sed -i '/^$k *=/d' $f/fifawc14.toml; echo '$($l.Trim()) # essai' >> $f/fifawc14.toml"
}
Start-Sleep 2
& $a shell "am start -n com.wc14.test/.LauncherActivity" | Out-Null; Start-Sleep 12
& $a shell "input tap 235 400"; Start-Sleep 26
K "66 66 62 62" 5
K "62 62 62 62 62 62 62" 10
K "62" 35; E "chargement"
K "66" 22; E "stade"
& $a shell "am force-stop com.wc14.test"
foreach ($l in ($Reglages -split ';' | Where-Object { $_ })) {
  $k = ($l -split '=')[0].Trim()
  & $a shell "grep '^$k *=' $f/fifawc14.toml; sed -i '/^$k *=/d' $f/fifawc14.toml"
}
& $a shell "grep -c outdated $f/fifawc14.log"
