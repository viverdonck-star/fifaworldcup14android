"""Compare l'atlas du public écrit par Direct3D 12 et par Vulkan, nibble par nibble."""
import collections

d = open("C:/wc14/vk-test/captures/001/r00_1BEEB000_info01000781.bin", "rb").read()
v = open("C:/wc14/vk-test/captures/vk/1BEEB000.bin", "rb").read()
n = min(len(d), len(v))
print("tailles", len(d), len(v))
# Moyenne de chacun des 4 nibbles des valeurs 16 bits (octet 0 = poids fort).
for nom, b in (("d3d12", d), ("vulkan", v)):
    s = [0] * 4
    nz = [0] * 4
    for i in range(0, n, 2):
        val = b[i] << 8 | b[i + 1]
        for k in range(4):
            x = (val >> (4 * k)) & 15
            s[k] += x
            nz[k] += x != 0
    c = n // 2
    print(nom, "nibbles bits0-3,4-7,8-11,12-15 moyenne", [round(x / c, 2) for x in s],
          "non nuls %", [round(100 * x / c, 1) for x in nz])
# Exemples de valeurs aux mêmes positions non nulles.
ex = [(i, d[i:i + 2].hex(), v[i:i + 2].hex()) for i in range(0, n, 2) if d[i:i + 2] != b"\0\0"][:2000:100]
for e in ex:
    print(*e)
