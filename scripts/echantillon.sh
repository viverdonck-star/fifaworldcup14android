#!/bin/bash
# Déclenche l'échantillonneur intégré et résume les piles par fil.
key=~/.ssh/odin_nba2k14; t=u0_a155@192.168.129.50
S="ssh -i $key -p 8022 -o BatchMode=yes $t"
Y=~/android-ndk-r27c/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-symbolizer
$S 'rm -f ~/storage/shared/WC14/samples.txt; touch ~/storage/shared/WC14/sampler.go; sleep 12; cat ~/storage/shared/WC14/samples.txt' > /tmp/samples.txt
wc -l /tmp/samples.txt
python3 - "$Y" <<'E'
import collections, subprocess, sys
Y = sys.argv[1]
L = ["/home/viver/wc14/sdk/out/linux-arm64/", "/home/viver/wc14/projet/pc/out/android/"]
cache = {}
def sym(x):
    if x in cache: return cache[x]
    r = x
    if "+" in x:
        lib, off = x.rsplit("+", 1)
        for d in L:
            try:
                o = subprocess.run([Y, "-e", d + lib, "-f", "--no-inlines", "0x" + off], capture_output=True, text=True).stdout.split("\n")[0]
                if o and o != "??":
                    r = o; break
            except Exception:
                pass
    r = r.replace("rex::", "").replace("graphics::", "")[:52]
    cache[x] = r
    return r
fils = collections.Counter(); hauts = collections.defaultdict(collections.Counter); fonc = collections.defaultdict(collections.Counter)
for l in open("/tmp/samples.txt", errors="replace"):
    p = l.strip().split("|")
    if len(p) < 3: continue
    n = int(p[0]); nom = p[1][:15]
    fils[nom] += n
    pile = [sym(x) for x in p[2:]]
    fonc[nom][pile[0]] += n
    hauts[nom][" < ".join(pile[:3])] += n
tot = sum(fils.values())
print("total", tot)
for nom, c in fils.most_common(9):
    print(f"== {nom} {c}")
    for k, v in fonc[nom].most_common(5):
        print(f"  {v:5d} {k}")
    for k, v in hauts[nom].most_common(2):
        print(f"   ->{v:4d} {k[:150]}")
E
