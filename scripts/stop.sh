#!/bin/bash
key=~/.ssh/odin_nba2k14; t=u0_a155@192.168.129.50
ssh -i $key -p 8022 -o BatchMode=yes $t "A='adb -s 127.0.0.1:46255 shell'; \$A am force-stop com.wc14.test; echo pid-apres: \$(\$A pidof com.wc14.test); grep -c FATAL ~/storage/shared/WC14/fifawc14.log; grep -E 'gpu_memcpy|readback' ~/storage/shared/WC14/fifawc14.log | tail -3 | cut -c12-140; df -h /storage/emulated/0 | tail -1 | cut -c1-50"
