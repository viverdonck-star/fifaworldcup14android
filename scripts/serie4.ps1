$b = 'C:\wc14\scripts\banc.ps1'
$tests = @(
  @('w', 'native_2x_msaa = false;vulkan_force_convert_quad_lists_to_triangle_lists = true'),
  @('x', 'native_2x_msaa = false;vulkan_force_expand_point_sprites_in_vs = true')
)
foreach ($t in $tests) {
  "=== $($t[0]) : $($t[1])"
  powershell -NoProfile -ExecutionPolicy Bypass -File $b -Nom $t[0] -Reglages $t[1]
}
"fin"
