#!/bin/bash
# Recompile, emballe et installe l'APK sur l'Odin.
tr -d '\r' < /mnt/c/wc14/scripts/tout-apk.sh > /tmp/ta-lf.sh; bash /tmp/ta-lf.sh 2>&1 | grep -E 'erreurs:|error:|signature-ok|WC14-Test.apk' | cut -c1-150
key=~/.ssh/odin_nba2k14; t=u0_a155@192.168.129.50
S="ssh -i $key -p 8022 -o BatchMode=yes $t"
$S 'cat > ~/storage/shared/WC14/WC14-Test.apk' < ~/wc14/apk/WC14-Test.apk
$S "adb connect 127.0.0.1:46255 >/dev/null 2>&1; adb -s 127.0.0.1:46255 install -r /storage/emulated/0/WC14/WC14-Test.apk 2>&1 | tail -1; adb -s 127.0.0.1:46255 shell appops get com.wc14.test MANAGE_EXTERNAL_STORAGE | head -1"
