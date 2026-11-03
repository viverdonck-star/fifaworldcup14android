# Relevés de chaleur pendant un match déjà lancé sur l'Odin : toutes les 30 s,
# images/s et températures ; arrête le jeu au-delà de 95 °C. Capture à la fin.
param([int]$Minutes = 4, [string]$Nom = "ch")
$a = "C:\wc14\outils\platform-tools\adb.exe"
$s = "C:\Users\viver\AppData\Local\Temp\claude\C--Users-viver--claude-spares-spare-Do2Bn5\5e8256b9-c7a9-4676-84b1-93538662e7af\scratchpad"
$t = "$env:TEMP\mesure-odin.sh"
[IO.File]::WriteAllText($t, ((Get-Content C:\wc14\scripts\mesure-odin.sh -Raw) -replace "`r", ""))
& $a push $t /sdcard/WC14/mesure.sh | Out-Null
for ($i = 1; $i -le $Minutes * 2; $i++) {
  Start-Sleep 30
  $r = (& $a shell "sh /sdcard/WC14/mesure.sh") -split ' '
  $cpu = [int]$r[2] / 1000; $gpu = [int]$r[3] / 1000
  "{0} images/s {1,3}  GPU {2,3} %  CPU max {3} C  GPU max {4} C" -f (Get-Date -Format HH:mm:ss), ([int]$r[0] / 10), $r[1], $cpu, $gpu
  if ($cpu -gt 95) { & $a shell "am force-stop com.wc14.test"; "ARRET : CPU au-dessus de 95 C, jeu ferme"; exit }
}
& $a shell "screencap -p /sdcard/WC14/e.png"; & $a pull /sdcard/WC14/e.png "$s\$Nom.png" | Out-Null; & $a shell "rm /sdcard/WC14/e.png"
