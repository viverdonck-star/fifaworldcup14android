#!/bin/bash
key=~/.ssh/odin_nba2k14; t=u0_a155@192.168.129.50
ssh -i $key -p 8022 -o BatchMode=yes $t "L=~/wc14-test/logcat.txt; P=\$(grep -m1 -oE 'Start proc [0-9]+:com.wc14.test' \$L | grep -oE '[0-9]+'); echo pid \$P; grep -E \" \$P +[0-9]+ \" \$L | grep -vE 'InteractionJank|Choreographer|ViewRoot|InsetsController|BLAST|vulkan-loader|nativeloader.*Load|TurboSchedMonitor|ashmem|CompatChange|ziparchive|ApplicationLoaders|Compatibility|AppCompat|HWUI|Perf  ' | cut -c19-200 | head -60"
