#!/bin/bash
cd ~/wc14/projet/pc/out/android
O=CMakeFiles/fifawc14_recomp.dir/generated/default/fifawc14_register.cpp.o
ninja -t commands $O | tail -1 | tr ' ' '\n' | grep -nE 'pch|Xclang|include$|^-O|^-g|^-f' | head -30
sed -n 1,12p ~/wc14/projet/pc/generated/default/fifawc14_register.cpp | cut -c1-120
grep -c . ~/wc14/projet/pc/generated/default/fifawc14_register.cpp
sed -n 100000,100003p ~/wc14/projet/pc/generated/default/fifawc14_register.cpp | cut -c1-140
