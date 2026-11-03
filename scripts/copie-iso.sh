#!/bin/bash
# Copie l'ISO vers l'Odin, si ce n'est pas déjà fait, avec contrôle de la taille.
key=~/.ssh/odin_nba2k14; t=u0_a155@192.168.129.50
S="ssh -i $key -p 8022 -o BatchMode=yes $t"
I="/mnt/c/Users/viver/Desktop/WORLD CUP 14/2014 FIFA World Cup Brasil [RF][ENG,GER,ITA].iso"
$S 'mkdir -p ~/storage/shared/WC14 && touch ~/storage/shared/WC14/fifawc14/portable.txt 2>/dev/null; mkdir -p ~/storage/shared/WC14/fifawc14; touch ~/storage/shared/WC14/fifawc14/portable.txt'
tr -d '\r' < /mnt/c/wc14/app/fifawc14.toml | $S 'cat > ~/storage/shared/WC14/fifawc14/fifawc14.toml'
T=$(stat -c %s "$I")
A=$($S 'stat -c %s ~/storage/shared/WC14/wc14.iso 2>/dev/null || echo 0')
echo "taille PC $T, Odin $A"
if [ "$T" != "$A" ]; then
  date +%T
  dd if="$I" bs=4M status=none | $S 'cat > ~/storage/shared/WC14/wc14.iso'
  date +%T
fi
$S 'stat -c "%s %n" ~/storage/shared/WC14/wc14.iso; df -h /storage/emulated/0 | tail -1; ls ~/storage/shared/WC14/fifawc14'
