#!/bin/bash
# odin-jeu.sh demarre : relance avec clavier et profil de test.
# odin-jeu.sh "62 62 66" 8 nom : touches Android (62 espace, 66 entrée), attente, capture.
key=~/.ssh/odin_nba2k14; t=u0_a155@192.168.129.50
S="ssh -i $key -p 8022 -o BatchMode=yes $t"
if [ "$1" = demarre ]; then
  (tr -d '\r' < /mnt/c/wc14/app/fifawc14.toml | sed -e "${2:-s/^$//}"; echo 'mnk_mode = true') | $S 'cat > ~/storage/shared/WC14/fifawc14.toml'
  cd /mnt/c/wc14/vk-test/saves && tar cf - . | $S 'cd ~/storage/shared/WC14/saves && tar xf - --no-same-owner 2>/dev/null; du -sh . | cut -f1'
  $S "A='adb -s 127.0.0.1:46255 shell'; adb connect 127.0.0.1:46255 >/dev/null 2>&1; \$A am force-stop com.wc14.test; rm -f ~/storage/shared/WC14/fifawc14.log; \$A am start -n com.wc14.test/.MainActivity 2>&1 | tail -1"
  exit
fi
$S "A='adb -s 127.0.0.1:46255 shell'; for k in $1; do \$A input keyevent --longpress \$k; sleep ${4:-4}; done; sleep ${2:-5}"
tr -d '\r' < /mnt/c/wc14/scripts/ecran.sh > /tmp/ec-lf.sh; bash /tmp/ec-lf.sh ${3:-oj}
