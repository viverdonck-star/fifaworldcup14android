#!/bin/bash
key=~/.ssh/odin_nba2k14; t=u0_a155@192.168.129.50
ssh -i $key -p 8022 -o BatchMode=yes $t "grep -n 'FATAL' -A3 ~/storage/shared/WC14/fifawc14.log | cut -c1-400; grep -c . ~/storage/shared/WC14/fifawc14.log; grep -E 'error|warning' ~/storage/shared/WC14/fifawc14.log | grep -vE 'STUB|stub|ResolvePath|NtCreateFile|XamMedia|set_priority' | tail -12 | cut -c12-160"
grep -n 'sub_82D5AB[0-9A-F]*\b' ~/wc14/projet/pc/generated/default/*.cpp | head -3 | cut -c1-140
F=$(grep -l 'PPC_FUNC_IMPL(__imp__sub_82D5A' ~/wc14/projet/pc/generated/default/*.cpp | head -1); echo $F
grep -n '^PPC_FUNC_IMPL(__imp__sub_82D5A' $F | head
