"""Remplace les 114 000 appels SetFunction par un tableau et une boucle."""
import os
import re
import sys

for chemin in sys.argv[1:]:
    texte = open(chemin).read().splitlines()
    motif = re.compile(r"^\s*registrar->SetFunction\((0x[0-9A-Fa-f]+), (\w+)\);$")
    entrees = [m.groups() for m in map(motif.match, texte) if m]
    autres = [l for l in texte if not motif.match(l)]
    print(chemin, "entrees:", len(entrees))
    i = next(n for n, l in enumerate(autres) if "RegisterFunctions(" in l)
    corps = "\n".join(f"    {{{a}, {f}}}," for a, f in entrees)
    tableau = [
        "namespace {",
        f"using RexGuestFunction = decltype(&{entrees[0][1]});",
        "constexpr struct { uint32_t address; RexGuestFunction function; } kGuestFunctions[] = {",
        corps,
        "};",
        "}  // namespace",
        "",
    ]
    boucle = ["  for (const auto& entry : kGuestFunctions) {",
              "    registrar->SetFunction(entry.address, entry.function);",
              "  }"]
    sortie = autres[:i] + tableau + autres[i:i + 1] + boucle + autres[i + 1:]
    os.replace(chemin, chemin + ".orig")
    open(chemin, "w").write("\n".join(sortie) + "\n")
