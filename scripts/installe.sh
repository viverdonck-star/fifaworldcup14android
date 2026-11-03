#!/bin/bash
key=~/.ssh/odin_nba2k14; t=u0_a155@192.168.129.50
S="ssh -i $key -p 8022 -o BatchMode=yes $t"
$S 'cat > ~/storage/shared/WC14/WC14-Test.apk' < ~/wc14/apk/WC14-Test.apk
$S 'ls -la ~/storage/shared/WC14/ | cut -c24-; P=$(cat ~/nba2k14/adb-port 2>/dev/null); echo "port note: $P"; adb devices 2>&1 | head -5; timeout 8 adb connect 127.0.0.1:$P 2>&1 | head -3; adb devices 2>&1 | head -5; settings get global adb_wifi_enabled 2>/dev/null | head -1'
