# Relance le jeu, va jusqu'à la présentation d'un match amical (Kick Off, Brésil-Argentine, sans toucher
# à la Coupe du monde en cours), relève les images par 10 s et la charge GPU pendant 60 s, puis ferme le jeu.
# Les réglages de -Reglages "cle = valeur;..." sont mis dans fifawc14.toml (marqués # essai) et retirés à la fin.
param([string]$Nom = "i", [string]$Reglages = "")
$a = "C:\wc14\outils\platform-tools\adb.exe"
$f = "/sdcard/Android/data/com.wc14.test/files"
$pas = "C:\wc14\scripts\odin-pas.ps1"
& $a shell "am force-stop com.wc14.test"
& $a shell "sed -i '/# essai$/d' $f/fifawc14.toml"
foreach ($l in ($Reglages -split ';' | Where-Object { $_ })) {
  $k = ($l -split '=')[0].Trim()
  & $a shell "sed -i '/^$k *=/d' $f/fifawc14.toml; echo '$($l.Trim()) # essai' >> $f/fifawc14.toml"
}
Start-Sleep 2
& $a shell "am start -n com.wc14.test/.LauncherActivity" | Out-Null; Start-Sleep 12
& $a shell "input tap 235 400"; Start-Sleep 30
& $pas "START" 35 "$Nom-1"     # écran titre -> avertissement de sauvegarde (A ignoré tant que l'icône tourne)
& $pas "A" 20 "$Nom-2"         # -> menu principal (Continue sélectionné), le temps qu'il s'installe
& $pas "BAS" 3 "$Nom-3"        # -> Kick Off
& $pas "A" 8 "$Nom-4"          # -> choix du camp
& $pas "A" 6 "$Nom-5"          # -> équipe à domicile
& $pas "A" 6 "$Nom-6"          # -> équipe à l'extérieur
& $pas "A" 6 "$Nom-7"          # -> maillots
& $pas "A A" 6 "$Nom-8"        # -> avant-match (Play Match)
& $pas "A" 75 "$Nom-9"         # chargement (entraînement)
& $pas "START" 1 "$Nom-10"     # -> présentation du match
$t0 = (& $a shell "date +%H:%M:%S").Trim()
for ($i = 1; $i -le 7; $i++) {
  Start-Sleep 9
  "gpu $((& $a shell 'cat /sys/class/kgsl/kgsl-3d0/gpu_busy_percentage').Trim())"
  if ($i -eq 4) { & $pas "" 0 "$Nom-intro" }
}
& $a shell "grep -E 'present intervals' $f/fifawc14.log | awk -v d='$t0' '`$2 > d' | sed -E 's/^\[[0-9-]+ ([0-9:]+)\.[0-9]+\].*last 10 s: /\1 /'"
& $a shell "am force-stop com.wc14.test"
foreach ($l in ($Reglages -split ';' | Where-Object { $_ })) {
  $k = ($l -split '=')[0].Trim()
  & $a shell "sed -i '/^$k *=/d' $f/fifawc14.toml"
}
