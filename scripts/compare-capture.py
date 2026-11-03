"""Compare les dessins d'une image capturée en Vulkan et en Direct3D 12."""
import collections
import difflib
import re

D = "C:/wc14/vk-test/"
R = re.compile(r"cap draw #(\d+): (\S+).*? prim (\d+) count (\d+) vs (\w+) ps (\w+) surface (\w+) "
               r"color0 (\w+) mask (\w+) blend0 (\w+) depth (\w+).*?textures (\w+) memexport (\d) "
               r"host_vs (\d+) host_count (\d+)")


def lit(nom):
    return [m.groups() for l in open(D + nom, errors="replace") if (m := R.search(l))]


vk, dx = lit("cap-vk.log.txt"), lit("cap-d3d.log.txt")
cle = lambda d: (d[4], d[5])
sm = difflib.SequenceMatcher(a=[cle(d) for d in dx], b=[cle(d) for d in vk], autojunk=False)
for op, a1, a2, b1, b2 in sm.get_opcodes():
    if op == "equal":
        continue
    print(f"--- {op} d3d12 {a1}..{a2} vulkan {b1}..{b2}")
    for d in dx[a1:a2][:8]:
        print("  D", d)
    for d in vk[b1:b2][:8]:
        print("  V", d)
# Dessins communs dont l'état diffère (hors indices).
print("=== mêmes shaders, état différent")
n = 0
for op, a1, a2, b1, b2 in sm.get_opcodes():
    if op != "equal":
        continue
    for x, y in zip(dx[a1:a2], vk[b1:b2]):
        if x[2:4] != y[2:4] or x[6:] != y[6:] and x[1] == y[1]:
            diff = [i for i in range(len(x)) if x[i] != y[i]]
            if diff != [6] and n < 40:
                print(" ", x[0], y[0], [(i, x[i], y[i]) for i in diff])
                n += 1
print("memexport d3d12:", collections.Counter(d[4] for d in dx if d[12] == "1"))
print("memexport vulkan:", collections.Counter(d[4] for d in vk if d[12] == "1"))
