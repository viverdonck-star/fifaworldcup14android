$b = 'C:\wc14\scripts\banc.ps1'
$s = "C:\Users\viver\AppData\Local\Temp\claude\C--Users-viver--claude-spares-spare-Do2Bn5\5e8256b9-c7a9-4676-84b1-93538662e7af\scratchpad"
$tests = @(
  @('m', 'clear_memory_page_state = true'),
  @('n', 'execute_unclipped_draw_vs_on_cpu = false'),
  @('o', 'vulkan_sparse_shared_memory = false'),
  @('p', 'vulkan_submit_on_primary_buffer_end = false')
)
foreach ($t in $tests) {
  "=== vulkan $($t[0]) : $($t[1])"
  powershell -NoProfile -ExecutionPolicy Bypass -File $b -Nom $t[0] -Court -Reglages "native_2x_msaa = false;$($t[1])"
}
Add-Type -AssemblyName System.Drawing
$noms = 'a','m','n','o','p','g'
$pl = New-Object System.Drawing.Bitmap 1200, 500
$g = [System.Drawing.Graphics]::FromImage($pl)
$f = New-Object System.Drawing.Font 'Arial', 20
for ($i = 0; $i -lt 6; $i++) {
  $p = "$s\$($noms[$i])-maillots.png"
  if (-not (Test-Path $p)) { continue }
  $im = [System.Drawing.Image]::FromFile($p)
  $src = New-Object System.Drawing.Rectangle 590, 130, 370, 340
  $dst = New-Object System.Drawing.Rectangle ($i * 200), 0, 196, 500
  $g.DrawImage($im, $dst, $src, [System.Drawing.GraphicsUnit]::Pixel)
  $g.DrawString($noms[$i], $f, [System.Drawing.Brushes]::Red, ($i * 200 + 4), 4)
  $im.Dispose()
}
$pl.Save("$s\planche3.png", [System.Drawing.Imaging.ImageFormat]::Png)
"fin"
