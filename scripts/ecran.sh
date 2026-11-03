#!/bin/bash
# Capture l'écran de l'Odin vers le scratchpad, avec température et cadence.
N=${1:-o1}
key=~/.ssh/odin_nba2k14; t=u0_a155@192.168.129.50
S="ssh -i $key -p 8022 -o BatchMode=yes $t"
D="/mnt/c/Users/viver/AppData/Local/Temp/claude/C--Users-viver--claude-spares-spare-Do2Bn5/5e8256b9-c7a9-4676-84b1-93538662e7af/scratchpad"
$S "adb connect 127.0.0.1:46255 >/dev/null 2>&1; adb -s 127.0.0.1:46255 exec-out screencap -p" > "$D/$N.png"
ls -la "$D/$N.png" | cut -c24-60
$S "A='adb -s 127.0.0.1:46255 shell'; echo pid \$(\$A pidof com.wc14.test); \$A dumpsys activity activities | grep -E 'topResumedActivity' | head -1 | cut -c28-90; \$A dumpsys meminfo com.wc14.test 2>/dev/null | grep -E 'TOTAL PSS' | head -1 | cut -c1-40; \$A 'for z in /sys/class/thermal/thermal_zone*; do t=\$(cat \$z/type); case \$t in cpu*|gpu*) echo \$t \$(cat \$z/temp);; esac; done' | sort -k2 -n | tail -2 | tr '\n' ' '; echo
grep -E 'present intervals|\\[error\\]|FATAL' ~/storage/shared/WC14/fifawc14.log | grep -v ResolvePath | tail -4 | cut -c12-150"
