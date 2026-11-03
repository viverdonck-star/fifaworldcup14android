#!/bin/bash
# Instantanés de piles (debuggerd), symbolisés avec les bibliothèques non réduites du PC.
N=${1:-6}
key=~/.ssh/odin_nba2k14; t=u0_a155@192.168.129.50
S="ssh -i $key -p 8022 -o BatchMode=yes $t"
Y=~/android-ndk-r27c/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-symbolizer
L=~/wc14/sdk/out/linux-arm64; G=~/wc14/projet/pc/out/android
rm -f /tmp/piles.txt
P=$($S "adb connect 127.0.0.1:46255 >/dev/null 2>&1; adb -s 127.0.0.1:46255 shell pidof com.wc14.test")
echo "pid $P"
[ -n "$P" ] || exit 1
for i in $(seq 1 $N); do
  $S "adb -s 127.0.0.1:46255 shell debuggerd -b $P 2>/dev/null" >> /tmp/piles.txt
  sleep 0.4
done
python3 - "$Y" "$L" "$G" <<'E'
import re, subprocess, sys, collections
Y, L, G = sys.argv[1:4]
fils = ("SDLThread", "GPU Commands", "Audio Worker", "Main XThread")
pile = collections.defaultdict(list)
cur = None
for l in open("/tmp/piles.txt", errors="replace"):
    m = re.match(r'"(.*?)" sysTid=', l)
    if m:
        cur = m.group(1); pile[cur].append([]); continue
    m = re.search(r'#(\d+) pc ([0-9a-f]+)\s+(\S+)', l)
    if m and cur:
        pile[cur][-1].append((int(m.group(1)), m.group(2), m.group(3), l.strip()[-60:]))
def sym(lib, pc):
    n = lib.split("/")[-1]
    for d in (L, G):
        p = d + "/" + n
        try:
            o = subprocess.run([Y, "-e", p, "-f", "--no-inlines", "0x" + pc], capture_output=True, text=True).stdout.split("\n")[0]
            if o and o != "??":
                return o[:62]
        except Exception:
            pass
    return n + "+" + pc
for nom, ps in sorted(pile.items()):
    if not nom.startswith(fils):
        continue
    print("==", nom, len(ps), "instantanes")
    c = collections.Counter()
    for f in ps:
        c[" < ".join(sym(x[2], x[1]) if ".so" in x[2] else x[2].split("/")[-1] for x in f[:4])] += 1
    for k, v in c.most_common(4):
        print(f"{v}x {k[:230]}")
E
