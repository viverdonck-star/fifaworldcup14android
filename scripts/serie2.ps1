$b = 'C:\wc14\scripts\banc.ps1'
$s = "C:\Users\viver\AppData\Local\Temp\claude\C--Users-viver--claude-spares-spare-Do2Bn5\5e8256b9-c7a9-4676-84b1-93538662e7af\scratchpad"
$tests = @(
  @('h', 'readback_resolve = "full"'),
  @('i', 'clear_msaa_redirect = false'),
  @('j', 'direct_resolve_32bpp = false'),
  @('k', 'resolve_to_texture = false'),
  @('l', 'native_2x_msaa = false')
)
foreach ($t in $tests) {
  "=== d3d12 $($t[0]) : $($t[1])"
  powershell -NoProfile -ExecutionPolicy Bypass -File $b -Nom $t[0] -Court -Moteur d3d12 -Base reglages-d3d12-rtv.toml -Reglages $t[1]
}
Add-Type -AssemblyName System.Drawing
$noms = 'g','h','i','j','k','l'
$pl = New-Object System.Drawing.Bitmap 1200, 500
$g = [System.Drawing.Graphics]::FromImage($pl)
$f = New-Object System.Drawing.Font 'Arial', 20
for ($i = 0; $i -lt 6; $i++) {
  $p = "$s\$($noms[$i])-maillots.png"
  if (-not (Test-Path $p)) { continue }
  $im = [System.Drawing.Image]::FromFile($p)
  $src = New-Object System.Drawing.Rectangle 590, 130, 200, 340
  $dst = New-Object System.Drawing.Rectangle ($i * 200), 0, 196, 500
  $g.DrawImage($im, $dst, $src, [System.Drawing.GraphicsUnit]::Pixel)
  $g.DrawString($noms[$i], $f, [System.Drawing.Brushes]::Red, ($i * 200 + 4), 4)
  $im.Dispose()
}
$pl.Save("$s\planche2.png", [System.Drawing.Imaging.ImageFormat]::Png)
"fin"
