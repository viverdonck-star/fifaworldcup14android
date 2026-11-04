# Un pas sur l'Odin : appuie sur des boutons de la vraie manette (sendevent), attend, capture.
# Boutons : A B X Y LB RB BACK START HAUT BAS GAUCHE DROITE. Ex. : odin-pas.ps1 "A A BAS" 3 p1
param([string]$Boutons = "", [int]$Attente = 3, [string]$Nom = "p")
$a = "C:\wc14\outils\platform-tools\adb.exe"
$s = "C:\Users\viver\AppData\Local\Temp\claude\C--Users-viver--claude-spares-spare-Do2Bn5\5e8256b9-c7a9-4676-84b1-93538662e7af\scratchpad"
$codes = @{ A = 304; B = 305; X = 307; Y = 308; LB = 310; RB = 311; BACK = 314; START = 315;
            HAUT = 544; BAS = 545; GAUCHE = 546; DROITE = 547 }
foreach ($b in ($Boutons -split ' ' | Where-Object { $_ })) {
  $c = $codes[$b]
  & $a shell "sendevent /dev/input/event8 1 $c 1; sendevent /dev/input/event8 0 0 0; sleep 0.12; sendevent /dev/input/event8 1 $c 0; sendevent /dev/input/event8 0 0 0"
  Start-Sleep -Milliseconds 700
}
Start-Sleep $Attente
& $a shell "screencap -p /sdcard/Download/e.png"; & $a pull /sdcard/Download/e.png "$s\$Nom.png" 2>$null | Out-Null; & $a shell "rm /sdcard/Download/e.png"
