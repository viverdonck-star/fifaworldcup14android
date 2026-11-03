#!/bin/bash
K=~/.ssh/odin_nba2k14
S="ssh -p 8022 -i $K -o BatchMode=yes -o ConnectTimeout=8 u0_a155@192.168.129.50"
aarch64-linux-gnu-gcc -D_GNU_SOURCE -O1 -w -o /tmp/vkq-glibc /mnt/c/wc14/scripts/vkq.c -ldl || exit 1
$S 'cat > ~/wc14-test/vkq-glibc && chmod +x ~/wc14-test/vkq-glibc' < /tmp/vkq-glibc
$S 'cd ~/nba2k14
grep -nE "ICD|host/|ld-linux|TU_|library-path" lancer.sh | head -12
for t in libvulkan_freedreno.so libvulkan-gen8-v4.so libvulkan-banner-a8xx.so; do
  echo "=== $t"
  env -u LD_PRELOAD TU_DEBUG=sysmem,noconform timeout 20 host/ld-linux-aarch64.so.1 --library-path host:turnip ~/wc14-test/vkq-glibc $PWD/turnip/$t 2>&1 | cut -c1-230 | grep -vE "^$|Date:|Compiler Version|Driver Branch" | head -22
done; echo fin'
