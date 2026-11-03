#!/bin/bash
# Pousse les réglages à côté de l'app, relance et lit les messages utiles.
W=${1:-30}
key=~/.ssh/odin_nba2k14; t=u0_a155@192.168.129.50
S="ssh -i $key -p 8022 -o BatchMode=yes $t"
tr -d '\r' < /mnt/c/wc14/app/fifawc14.toml | $S 'cat > ~/storage/shared/WC14/fifawc14.toml; touch ~/storage/shared/WC14/portable.txt'
$S "A='adb -s 127.0.0.1:46255 shell'; adb connect 127.0.0.1:46255 >/dev/null 2>&1
\$A am force-stop com.wc14.test; \$A logcat -c; rm -f ~/storage/shared/WC14/fifawc14.log
\$A am start -n com.wc14.test/.MainActivity 2>&1 | tail -1
sleep $W
\$A dumpsys activity activities | grep -E 'topResumedActivity' | head -1 | cut -c1-100
echo \"pid: \$(\$A pidof com.wc14.test)\"
\$A dumpsys meminfo com.wc14.test 2>/dev/null | grep -E 'TOTAL PSS' | head -1 | cut -c1-60
\$A logcat -d 2>/dev/null > ~/wc14-test/logcat.txt
P=\$(grep -m1 -oE 'Start proc [0-9]+:com.wc14.test' ~/wc14-test/logcat.txt | grep -oE '[0-9]+')
grep -E \" \$P +[0-9]+ |DEBUG|tombstone\" ~/wc14-test/logcat.txt | grep -E 'SDL  |FATAL|Abort|F DEBUG|signal |backtrace|#[0-9][0-9] pc|Finished main|Vulkan|vulkan|lib.*\\.so' | grep -vE 'searching for layers|Running main|nativeSetup|surface|onWindow|on[A-Z][a-z]+\\(\\)|Window size|Device size|setOrientation|Manufacturer|Device:|Model:' | tail -30 | cut -c19-175
echo --- journal; ls -la ~/storage/shared/WC14 | cut -c24-; ls -la ~/storage/shared/WC14/logs 2>/dev/null | cut -c24- | tail -3
F=\$(ls -t ~/storage/shared/WC14/fifawc14.log ~/storage/shared/WC14/logs/* 2>/dev/null | head -1); echo \$F
grep -vE 'XMA:|NtCreateFile' \"\$F\" 2>/dev/null | tail -30 | cut -c1-170"
