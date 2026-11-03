#!/bin/bash
key=~/.ssh/odin_nba2k14; t=u0_a155@192.168.129.50
S="ssh -i $key -p 8022 -o BatchMode=yes $t"
$S "A='adb -s 127.0.0.1:46255 shell'; \$A logcat -d -b crash 2>/dev/null | tail -60 | cut -c19-150
echo ---; \$A logcat -d 2>/dev/null > ~/wc14-test/logcat.txt; grep -nE 'F libc|signal 1|Fatal signal|am_crash|Process com.wc14.test|has died|lowmemorykiller|Killing' ~/wc14-test/logcat.txt | tail -8 | cut -c1-170
echo --- jeu; grep -vE 'XMA:|NtCreateFile|vblank pacing|present intervals' ~/storage/shared/WC14/fifawc14.log | tail -14 | cut -c12-170"
