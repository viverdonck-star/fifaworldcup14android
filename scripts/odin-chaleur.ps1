# Chaleur en match : odin-vers-intro.ps1, passe la présentation, puis relève toutes les 15 s pendant
# $Duree secondes la température max CPU et GPU, la charge et la fréquence GPU, et les images en 10 s.
# Réglages en plus (retirés à la fin) : -Reglages "cle = valeur;..."
param([string]$Nom = "ch", [string]$Reglages = "", [int]$Duree = 180)
$a = "C:\wc14\outils\platform-tools\adb.exe"
$f = "/sdcard/Android/data/com.wc14.test/files"
$pas = "C:\wc14\scripts\odin-pas.ps1"
& $a shell "am force-stop com.wc14.test; sed -i '/# essai$/d' $f/fifawc14.toml"
foreach ($l in ($Reglages -split ';' | Where-Object { $_ })) {
  $k = ($l -split '=')[0].Trim()
  & $a shell "sed -i '/^$k *=/d' $f/fifawc14.toml; echo '$($l.Trim()) # essai' >> $f/fifawc14.toml"
}
& C:\wc14\scripts\odin-vers-intro.ps1 -Nom "$Nom-nav" | Out-Null
Start-Sleep 20; & $pas "START" 5 "$Nom-skip"; & $pas "A" 25 "$Nom-a"
$debut = [int](& $a shell "wc -l < $f/fifawc14.log").Trim()
$mesure = 'c=0; g=0; for z in /sys/class/thermal/thermal_zone*; do t=$(cat $z/type); v=$(cat $z/temp); case $t in cpu-*) [ $v -gt $c ] && c=$v ;; gpuss-*) [ $v -gt $g ] && g=$v ;; esac; done; echo "cpu $((c/1000)) gpu $((g/1000)) charge $(cat /sys/class/kgsl/kgsl-3d0/gpu_busy_percentage) freq $(($(cat /sys/class/kgsl/kgsl-3d0/gpuclk)/1000000))"'
for ($s = 0; $s -le $Duree; $s += 15) {
  "$s s  $((& $a shell $mesure).Trim())"
  if ($s -lt $Duree) { Start-Sleep 15 }
}
& $pas "" 0 "$Nom-fin"
& $a shell "tail -n +$debut $f/fifawc14.log | grep 'present intervals' | sed -E 's/.*last 10 s: //' | cut -c1-40"
& $a shell "am force-stop com.wc14.test; sed -i '/# essai$/d' $f/fifawc14.toml"
