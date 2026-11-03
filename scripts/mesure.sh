#!/bin/bash
key=~/.ssh/odin_nba2k14; t=u0_a155@192.168.129.50
S="ssh -i $key -p 8022 -o BatchMode=yes $t"
$S "A='adb -s 127.0.0.1:46255 shell'; \$A top -H -b -n 1 -d 2 -p \$(\$A pidof com.wc14.test) 2>/dev/null | sed -n 5,20p | cut -c1-90
for f in /sys/class/kgsl/kgsl-3d0/gpubusy /sys/class/kgsl/kgsl-3d0/gpu_busy_percentage /sys/class/kgsl/kgsl-3d0/devfreq/cur_freq /sys/class/kgsl/kgsl-3d0/gpuclk; do echo \"\$f \$(\$A cat \$f 2>/dev/null)\"; done
\$A 'for z in /sys/class/thermal/thermal_zone*; do t=\$(cat \$z/type); case \$t in gpu*|gpuss*|skin*|battery|cpu-1-1-1) echo \$t \$(cat \$z/temp);; esac; done' | sort -k2 -n | tail -6 | tr '\n' ' '; echo
\$A dumpsys gfxinfo com.wc14.test 2>/dev/null | head -0"
