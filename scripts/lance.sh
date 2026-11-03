#!/bin/bash
# Relance le test sur l'Odin. Attente en secondes en paramètre.
W=${1:-25}
key=~/.ssh/odin_nba2k14; t=u0_a155@192.168.129.50
S="ssh -i $key -p 8022 -o BatchMode=yes $t"
$S "A='adb -s 127.0.0.1:46255 shell'; adb connect 127.0.0.1:46255 >/dev/null 2>&1
\$A appops get com.wc14.test MANAGE_EXTERNAL_STORAGE | head -1
\$A am force-stop com.wc14.test; \$A logcat -c; rm -f ~/storage/shared/WC14/fifawc14.log
\$A am start -n com.wc14.test/.MainActivity 2>&1 | tail -1
sleep $W
\$A dumpsys activity activities | grep -E 'topResumedActivity' | head -1 | cut -c1-110
echo \"pid: \$(\$A pidof com.wc14.test)\"
\$A logcat -d 2>/dev/null > /data/data/com.termux/files/home/wc14-test/logcat.txt
L=~/wc14-test/logcat.txt
grep -E 'com.wc14|wc14|DEBUG|FATAL|libc  |linker|UnsatisfiedLink|Vulkan|Adreno|SDL' \$L | grep -v 'ActivityManager: Start\|WindowManager\|InputDispatcher\|ImeTracker' | tail -40 | cut -c1-190
echo --- journal; ls -la ~/storage/shared/WC14/*.log ~/storage/shared/WC14/fifawc14/logs 2>/dev/null | cut -c24-
tail -25 ~/storage/shared/WC14/fifawc14.log 2>/dev/null | cut -c1-170"
