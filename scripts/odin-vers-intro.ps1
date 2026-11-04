# Relance le jeu et va jusqu'à la présentation d'un match amical (Kick Off, sans toucher à la Coupe du
# monde en cours), avec les vrais boutons de la manette. Attentes mesurées le 03/11/2026 : le jeu ignore A
# tant que l'icône de sauvegarde tourne. Capture d'écran à chaque étape (scratchpad\<Nom>-n.png).
param([string]$Nom = "nav")
$a = "C:\wc14\outils\platform-tools\adb.exe"
$pas = "C:\wc14\scripts\odin-pas.ps1"
& $a shell "am force-stop com.wc14.test"; Start-Sleep 2
& $a shell "am start -n com.wc14.test/.LauncherActivity" | Out-Null; Start-Sleep 12
& $a shell "input tap 235 400"; Start-Sleep 40
& $pas "START" 40 "$Nom-1"   # écran titre -> avertissement de sauvegarde
& $pas "A" 20 "$Nom-2"       # -> menu principal (Continue sélectionné)
& $pas "BAS" 3 "$Nom-3"      # -> Kick Off
& $pas "A" 8 "$Nom-4"        # -> choix du camp
& $pas "A" 6 "$Nom-5"
& $pas "A" 6 "$Nom-6"
& $pas "A" 6 "$Nom-7"
& $pas "A A" 6 "$Nom-8"      # -> avant-match (Play Match)
& $pas "A" 75 "$Nom-9"       # chargement (entraînement)
& $pas "START" 1 "$Nom-10"   # -> présentation du match
