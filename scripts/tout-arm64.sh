#!/bin/bash
tr -d '\r' < /mnt/c/wc14/scripts/sdk-arm64.sh > /tmp/s-lf.sh
bash /tmp/s-lf.sh < /dev/null
cd ~/wc14/sdk && cmake --install out/android > /dev/null 2>&1 && echo sdk-installe
tr -d '\r' < /mnt/c/wc14/scripts/jeu-arm64.sh > /tmp/j-lf.sh
bash /tmp/j-lf.sh 1500 < /dev/null
cd ~/wc14/projet/pc
find out/android ../../sdk/out/linux-arm64 -maxdepth 2 \( -name '*.so' -o -name 'fifawc14*' \) -type f 2>/dev/null | xargs -r ls -la | cut -c24- | head
