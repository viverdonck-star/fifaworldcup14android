# Une mesure de la présentation du match avec des réglages d'essai : odin-vers-intro.ps1, puis 6 relevés
# (images en 10 s du journal, temps GPU par image, fréquence GPU, températures) et une capture d'écran.
# Ex. : odin-ab.ps1 -Nom m7 -Reglages "depth_float24_convert_msaa_mask = 7;gpu_timing = true"
param([string]$Nom = "ab", [string]$Reglages = "")
$a = "C:\wc14\outils\platform-tools\adb.exe"
$f = "/sdcard/Android/data/com.wc14.test/files"
& $a shell "am force-stop com.wc14.test; sed -i '/# essai$/d' $f/fifawc14.toml"
foreach ($l in ($Reglages -split ';' | Where-Object { $_ })) {
  $k = ($l -split '=')[0].Trim()
  & $a shell "sed -i '/^$k *=/d' $f/fifawc14.toml; echo '$($l.Trim()) # essai' >> $f/fifawc14.toml"
}
& C:\wc14\scripts\odin-vers-intro.ps1 -Nom "$Nom-nav"
$debut = [int](& $a shell "wc -l < $f/fifawc14.log").Trim()
for ($i = 1; $i -le 6; $i++) {
  Start-Sleep 9
  $g = (& $a shell "cat /sys/class/kgsl/kgsl-3d0/gpuclk").Trim()
  $t = (& $a shell "c=0; for z in /sys/class/thermal/thermal_zone*; do case `$(cat `$z/type) in cpu-*|gpuss-*) t=`$(cat `$z/temp); [ `$t -gt `$c ] && c=`$t ;; esac; done; echo `$c").Trim()
  "gpu $([int64]$g / 1000000) MHz, max $([int]$t / 1000) C"
  if ($i -eq 3) { & C:\wc14\scripts\odin-pas.ps1 "" 0 "$Nom-intro" }
}
& $a shell "tail -n +$debut $f/fifawc14.log | grep -E 'gpu time a frame|present intervals' | sed -E 's/^\[[0-9-]+ ([0-9:]+)\.[0-9]+\].*\] (gpu time a frame: |present intervals in the last 10 s: )/\1 /' | cut -c1-120"
& $a shell "am force-stop com.wc14.test; sed -i '/# essai$/d' $f/fifawc14.toml"
