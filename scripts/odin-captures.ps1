# Va jusqu'à la présentation d'un match amical (odin-vers-intro.ps1), puis capture une image (détail de
# chaque dessin, vulkan_capture_trigger) toutes les 4 s, 5 fois, dans scratchpad\cap-<Nom>-<n>.txt et .png.
# Le réglage vulkan_capture_trigger doit pointer vers <dossier de l'app>/cap.
param([string]$Nom = "x")
$a = "C:\wc14\outils\platform-tools\adb.exe"
$f = "/sdcard/Android/data/com.wc14.test/files"
$s = "C:\Users\viver\AppData\Local\Temp\claude\C--Users-viver--claude-spares-spare-Do2Bn5\5e8256b9-c7a9-4676-84b1-93538662e7af\scratchpad"
& $a shell "rm -f $f/cap"
& C:\wc14\scripts\odin-vers-intro.ps1 -Nom "$Nom-nav"
Start-Sleep 6
for ($n = 1; $n -le 5; $n++) {
  $avant = [int](& $a shell "grep -c 'cap begin' $f/fifawc14.log").Trim()
  & $a shell "touch $f/cap"; Start-Sleep 2
  & C:\wc14\scripts\odin-pas.ps1 "" 0 "cap-$Nom-$n"
  Start-Sleep 2
  $ligne = (& $a shell "grep -n 'cap begin' $f/fifawc14.log | tail -1 | cut -d: -f1").Trim()
  & $a shell "tail -n +$ligne $f/fifawc14.log | grep '\] cap' | head -20000 > /sdcard/Download/c.txt"
  & $a pull /sdcard/Download/c.txt "$s\cap-$Nom-$n.txt" 2>$null | Out-Null
  & $a shell "rm /sdcard/Download/c.txt"
}
& $a shell "am force-stop com.wc14.test"
