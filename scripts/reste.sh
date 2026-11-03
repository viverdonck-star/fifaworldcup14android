#!/bin/bash
cd ~/wc14/projet/pc/out/android
ninja -n 2>/dev/null | cut -c1-120 | tail -6
ninja -t commands fifawc14 2>/dev/null | tail -2 | cut -c1-200 >/dev/null
ls -la ~/wc14/projet/pc/generated/default/fifawc14_register.cpp ~/wc14/projet/pc/generated/default/fifawc14_init.cpp 2>/dev/null | cut -c24-
ls CMakeFiles/fifawc14_recomp.dir/generated/default/ | grep -E 'register|init' | head
ps aux --sort=-%mem | grep -E 'clang|ld.lld' | grep -v grep | head -3 | cut -c1-140
free -g | sed -n 2p
