#!/bin/bash
key=~/.ssh/odin_nba2k14; t=u0_a155@192.168.129.50
S="ssh -i $key -p 8022 -o BatchMode=yes $t"
$S 'echo 46255 > ~/nba2k14/adb-port; adb start-server >/dev/null 2>&1; timeout 10 adb connect 127.0.0.1:46255 2>&1 | head -2; adb devices 2>&1 | head -4
adb -s 127.0.0.1:46255 shell "pm list packages com.wc14.test; appops get com.wc14.test MANAGE_EXTERNAL_STORAGE; dumpsys activity activities | grep -E \"topResumedActivity|mResumedActivity\" | head -2; pidof com.wc14.test; ps -A | grep -iE \"nba|shadps|fex\" | head -3; dumpsys battery | grep -E \"level|temperature\"; cat /sys/class/thermal/thermal_zone0/temp" 2>&1 | head -14
ls -la ~/storage/shared/WC14/fifawc14 ~/storage/shared/WC14/*.log 2>/dev/null | cut -c24-'
