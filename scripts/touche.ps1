# Envoie des touches au jeu, puis capture l'écran.
# Exemple : touche.ps1 -Touches "Space:1,Down:0.3" -Attente 3 -Nom m1
param([string]$Touches = "", [double]$Attente = 2, [string]$Nom = "cap")
$s = "C:\Users\viver\AppData\Local\Temp\claude\C--Users-viver--claude-spares-spare-Do2Bn5\5e8256b9-c7a9-4676-84b1-93538662e7af\scratchpad"
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public class Clavier {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint MapVirtualKey(uint c, uint t);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
}
"@
[Clavier]::SetProcessDPIAware() | Out-Null
$g = Get-Process fifawc14 -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $g) { "jeu arrete"; exit 1 }
[Clavier]::SetForegroundWindow($g.MainWindowHandle) | Out-Null
Start-Sleep -Milliseconds 300
if ([Clavier]::GetForegroundWindow() -ne $g.MainWindowHandle) { "fenetre du jeu pas au premier plan, touches non envoyees"; exit 2 }
$vk = @{ Space=0x20; Enter=0x0D; Backspace=0x08; Up=0x26; Down=0x28; Left=0x25; Right=0x27; Escape=0x1B }
foreach ($t in ($Touches -split ',' | Where-Object { $_ })) {
  $p = $t -split ':'; $k = [byte]$vk[$p[0]]
  if (-not $k) { $k = [byte][char]$p[0].ToUpper() }
  $sc = [byte][Clavier]::MapVirtualKey($k, 0)
  [Clavier]::keybd_event($k, $sc, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 120
  [Clavier]::keybd_event($k, $sc, 2, [UIntPtr]::Zero)
  $w = 0.6; if ($p.Count -gt 1) { $w = [double]$p[1] }
  Start-Sleep -Milliseconds ([int]($w * 1000))
}
Start-Sleep -Milliseconds ([int]($Attente * 1000))
$b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
$gr = [System.Drawing.Graphics]::FromImage($bmp)
$gr.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
$small = New-Object System.Drawing.Bitmap $bmp, 960, ([int](960 * $b.Height / $b.Width))
$small.Save("$s\$Nom.png", [System.Drawing.Imaging.ImageFormat]::Png)
"ok $Nom"
