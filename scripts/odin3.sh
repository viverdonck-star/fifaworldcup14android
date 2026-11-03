#!/bin/bash
K=~/.ssh/odin_nba2k14
S="ssh -p 8022 -i $K -o BatchMode=yes -o ConnectTimeout=8 u0_a155@192.168.129.50"
$S 'cd ~/nba2k14; ls; L=$(find ~/nba2k14 -name "ld-linux-aarch64.so.1" 2>/dev/null | head -3); echo "ld: $L"
for t in turnip/libvulkan_freedreno.so turnip/libvulkan-gen8-v4.so turnip/libvulkan-banner-a8xx.so; do
  echo "== $t: $(strings -a $t 2>/dev/null | grep -c fragment_shader_interlock) mentions interlock, $(strings -a $t 2>/dev/null | grep -m1 -E "^Mesa [0-9]|Mesa 2[0-9]\.[0-9]") "
  strings -a $t 2>/dev/null | grep -iE "VK_EXT_fragment_shader_interlock|VK_EXT_rasterization_order_attachment_access|fragmentShaderSampleInterlock" | head -4
done; echo fin'
