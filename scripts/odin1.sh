#!/bin/bash
# Lecture seule : joint l'Odin et regarde quels outils Vulkan sont déjà là.
K=~/.ssh/odin_nba2k14
for ip in 192.168.129.50; do
  ssh -p 8022 -i "$K" -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new u0_a155@$ip '
    echo "connecte: $(uname -m) $(getprop ro.product.model) Android $(getprop ro.build.version.release)"
    echo "gpu: $(getprop ro.hardware.egl) $(getprop ro.hardware.vulkan)"
    echo "turnip/outils:"; command -v vulkaninfo clang gcc; pkg list-installed 2>/dev/null | grep -iE "vulkan|mesa|clang|ndk" | head
    ls -la ~ | head -30
    ls -d ~/*turnip* ~/*Turnip* /storage/emulated/0/*urnip* 2>/dev/null
    find ~ -maxdepth 4 \( -name "vulkan.*.so" -o -name "libvulkan_freedreno*.so" -o -name "vulkaninfo*" \) 2>/dev/null | head -20
    dumpsys package features 2>/dev/null | grep -i vulkan
    echo fin
  ' && exit 0
done
echo "connexion impossible"
