#!/bin/bash
K=~/.ssh/odin_nba2k14
S="ssh -p 8022 -i $K -o BatchMode=yes -o ConnectTimeout=8 u0_a155@192.168.129.50"
$S 'mkdir -p ~/wc14-test && cat > ~/wc14-test/vkq.c' < /mnt/c/wc14/scripts/vkq.c
$S 'cd ~/wc14-test && clang -O1 -w -o vkq vkq.c -ldl 2>&1 | tail -5
echo "=== Pilote systeme Qualcomm"; ./vkq 2>&1
echo "=== Turnip deja present"; file ~/nba2k14/turnip/libvulkan_freedreno.so 2>/dev/null | cut -c1-140; ls -la ~/nba2k14/turnip | head; ./vkq ~/nba2k14/turnip/libvulkan_freedreno.so 2>&1 | cut -c1-220
echo fin'
