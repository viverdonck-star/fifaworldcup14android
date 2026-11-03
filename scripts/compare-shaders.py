"""Compare les shaders vus par les journaux Vulkan et Direct3D 12."""
import collections
import re

D = "C:/wc14/vk-test/"


def lit(nom):
    vs, ps, paires, autres = set(), set(), set(), collections.Counter()
    for l in open(D + nom, errors="replace"):
        m = re.search(r"Creating graphics pipeline state with VS ([0-9A-F]{16})(?:, PS ([0-9A-F]{16}))?", l)
        if m:
            vs.add(m.group(1))
            if m.group(2):
                ps.add(m.group(2))
            paires.add(m.groups())
        elif "[gpu]" in l and ("warning" in l or "error" in l):
            autres[re.sub(r"^\[[^\]]+\] ", "", re.sub(r"[0-9A-Fa-f]{6,}", "#", l)).strip()[:110]] += 1
    return vs, ps, paires, autres


vv, vp, vpa, va = lit("vk-match.log.txt")
dv, dp, dpa, da = lit("d3d-match.log.txt")
print("vulkan VS", len(vv), "PS", len(vp), "paires", len(vpa))
print("d3d12  VS", len(dv), "PS", len(dp), "paires", len(dpa))
print("VS seulement d3d12:", sorted(dv - vv)[:20])
print("VS seulement vulkan:", sorted(vv - dv)[:20])
print("PS seulement d3d12:", sorted(dp - vp)[:20])
print("PS seulement vulkan:", sorted(vp - dp)[:20])
print("paires d3d12 absentes de vulkan:", len(dpa - vpa))
for a, b in sorted(dpa - vpa, key=str)[:12]:
    print(" ", a, b)
print("--- avertissements gpu vulkan")
for k, n in va.most_common(10):
    print(n, k)
print("--- avertissements gpu d3d12")
for k, n in da.most_common(6):
    print(n, k)
