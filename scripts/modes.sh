#!/bin/bash
key=~/.ssh/odin_nba2k14; t=u0_a155@192.168.129.50
ssh -i $key -p 8022 -o BatchMode=yes $t "A='adb -s 127.0.0.1:46255 shell'; \$A 'settings list system | grep -iE \"perf|fan|mode|gpu|cpu|game\" | head -24; settings list global | grep -iE \"perf|fan|low_power|thermal\" | head; settings list secure | grep -iE \"perf|fan\" | head -5'
for i in 1 2 3; do \$A 'cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq /sys/devices/system/cpu/cpu6/cpufreq/scaling_cur_freq /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq /sys/devices/system/cpu/cpu6/cpufreq/scaling_max_freq | tr \"\\n\" \" \"; echo'; sleep 1; done
\$A 'cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor; dumpsys thermalservice 2>/dev/null | grep -E \"Thermal Status|Current temperatures\" | head -3; getprop | grep -iE \"perfmode|performance|fan|game_mode\" | head -10'"
