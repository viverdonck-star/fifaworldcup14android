#!/bin/bash
key=~/.ssh/odin_nba2k14; t=u0_a155@192.168.129.50
S="ssh -i $key -p 8022 -o BatchMode=yes $t"
$S "A='adb -s 127.0.0.1:46255 shell'; P=\$(\$A pidof com.wc14.test); echo pid \$P
\$A 'simpleperf record -p '\$P' --duration 6 -f 1000 -o /data/local/tmp/p.data 2>&1 | tail -2'
\$A 'simpleperf report -i /data/local/tmp/p.data --sort comm 2>/dev/null | sed -n 6,24p | cut -c1-70'
echo === dso; \$A 'simpleperf report -i /data/local/tmp/p.data --sort comm,dso 2>/dev/null | sed -n 6,26p | sed -E \"s#/data/app/[^ ]*/lib/arm64/##\" | cut -c1-90'
echo === sym; \$A 'simpleperf report -i /data/local/tmp/p.data --sort comm,symbol --comms SDLThread,\"GPU Commands\",\"Audio Worker\" 2>/dev/null | sed -n 6,40p | cut -c1-110'
\$A 'cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq | tr \"\\n\" \" \"; echo; cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq /sys/devices/system/cpu/cpu7/cpufreq/cpuinfo_max_freq | tr \"\\n\" \" \"; echo; ps -T -o tid,psr,comm -p '\$P' 2>/dev/null | grep -E \"SDLThread|GPU Commands|Audio Worker|Main XThread\" | cut -c1-40'"
