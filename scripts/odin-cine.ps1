# Comme odin-stade.ps1 : relance l'app, Play, va jusqu'à la présentation du match (une cinématique),
# puis relève les images par 10 s pendant 50 s, la charge GPU et les températures, et ferme le jeu.
# Réglages en plus, retirés à la fin : -Reglages "cle = valeur;cle2 = valeur"
param([string]$Nom = "c", [string]$Reglages = "")
$a = "C:\wc14\outils\platform-tools\adb.exe"
$s = "C:\Users\viver\AppData\Local\Temp\claude\C--Users-viver--claude-spares-spare-Do2Bn5\5e8256b9-c7a9-4676-84b1-93538662e7af\scratchpad"
$f = "/sdcard/Android/data/com.wc14.test/files"
function K([string]$touches, [int]$apres) { foreach ($t in $touches -split ' ') { & $a shell "input keyevent --longpress $t"; Start-Sleep -Seconds 4 }; Start-Sleep -Seconds $apres }
function E([string]$n) { & $a shell "screencap -p /sdcard/Download/e.png"; & $a pull /sdcard/Download/e.png "$s\$Nom-$n.png" 2>$null | Out-Null; & $a shell "rm /sdcard/Download/e.png"; "$Nom-$n" }
function M { & $a shell "g=`$(cat /sys/class/kgsl/kgsl-3d0/gpu_busy_percentage | tr -d ' %'); c=0; for z in /sys/class/thermal/thermal_zone*; do case `$(cat `$z/type) in cpu-*) t=`$(cat `$z/temp); [ `$t -gt `$c ] && c=`$t ;; esac; done; echo gpu `$g% cpu `$c" }
& $a shell "am force-stop com.wc14.test"
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
K "62" 35
$debut = (& $a shell "date +%H:%M:%S").Trim()
K "66" 8
for ($i = 0; $i -lt 5; $i++) { Start-Sleep 10; M }
E "cine"
& $a shell "grep 'present intervals' $f/fifawc14.log | awk -v d='$debut' '`$2 > d' | sed -E 's/.*\] present intervals in the last 10 s: //'"
& $a shell "grep -E 'audio endpoint' $f/fifawc14.log | tail -1"
& $a shell "am force-stop com.wc14.test"
foreach ($l in ($Reglages -split ';' | Where-Object { $_ })) {
  $k = ($l -split '=')[0].Trim()
  & $a shell "sed -i '/^$k *=/d' $f/fifawc14.toml"
}
