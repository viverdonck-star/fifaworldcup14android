# Banc d'essai : applique des réglages, va aux maillots puis au match, capture.
# Exemple : banc.ps1 -Nom a -Moteur vulkan -Reglages "native_2x_msaa = false;autre = true"
param([string]$Nom = "a", [string]$Reglages = "", [string]$Base = "reglages-vulkan-fsi.toml",
      [string]$Moteur = "vulkan", [switch]$Court, [switch]$Capture)
$d = 'C:\wc14\vk-test'; $k = 'C:\wc14\scripts\touche.ps1'
function T($t, $a, $n) { powershell -NoProfile -ExecutionPolicy Bypass -File $k -Touches $t -Attente $a -Nom "$Nom-$n" }
Get-Process fifawc14 -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2
Remove-Item "$d\fifawc14.log" -ErrorAction SilentlyContinue
# Sans FSI/ROV : la seule méthode possible sur l'Odin. Un réglage donné remplace celui de la base.
$lignes = ($Reglages -split ';') | Where-Object { $_ }
$cles = $lignes | ForEach-Object { ($_ -split '=')[0].Trim() }
$t = Get-Content "$d\$Base" | Where-Object { $_ -notmatch '^render_target_path' -and ($cles -notcontains (($_ -split '=')[0].Trim())) }
$t + $lignes | Set-Content "$d\fifawc14.toml" -Encoding ascii
$env:REX_GPU_BACKEND = $Moteur
Start-Process -FilePath "$d\fifawc14.exe" -WorkingDirectory $d | Out-Null
Start-Sleep -Seconds 24
T "Space:2,Space:2,Space:3,Enter:7,Enter:9,Space:12" 1 "menu"
T "Space:10,Space:9,Space:9,Space:10" 10 "maillots"
if (-not $Court) {
T "Space:7,Space:7,Space:2" 40 "chargement"
T "Enter:3" 20 "stade"
T "Space:3,Space:3,Space:3" 12 "match"
if ($Capture) { Set-Content "$d\capture.txt" "1"; Start-Sleep -Seconds 4 }
}
"actif: $([bool](Get-Process fifawc14 -ErrorAction SilentlyContinue))"
Get-Process fifawc14 -ErrorAction SilentlyContinue | Stop-Process -Force
