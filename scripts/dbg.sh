#!/bin/bash
key=~/.ssh/odin_nba2k14; t=u0_a155@192.168.129.50
ssh -i $key -p 8022 -o BatchMode=yes $t "A='adb -s 127.0.0.1:46255 shell'; adb connect 127.0.0.1:46255 >/dev/null 2>&1; P=\$(\$A pidof com.wc14.test); echo pid \$P; \$A debuggerd -b \$P 2>&1 | head -6 | cut -c1-120; echo ---; \$A run-as com.wc14.test sh -c \"'id; cat /proc/\$P/task/*/comm | sort | uniq -c | sort -rn | head -5; for t in /proc/\$P/task/*; do n=\\\$(cat \\\$t/comm); case \\\$n in SDLThread*) echo \\\$n \\\$(cat \\\$t/wchan) \\\$(cut -d\\\" \\\" -f3,14,15 \\\$t/stat);; esac; done'\" 2>&1 | head -14 | cut -c1-120"
