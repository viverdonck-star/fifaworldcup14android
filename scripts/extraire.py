"""Copie les 3 exécutables du jeu depuis l'ISO, sans modifier l'ISO."""
import os
import struct
import sys

SECTEUR = 2048
MAGIE = b"MICROSOFT*XBOX*MEDIA"
DEPARTS = [0, 0x18300000, 0xFD90000, 0x89D80000, 0x2080000]
VOULUS = (
    "default.xex",
    "dlc/dlc_footballcompeng/dlc/footballcompeng/footballcompengzf.xex.dll",
    "dlc/dlc_powdll/dlc/powdll/powdllzf.xex.dll",
)


def lit_dossier(f, depart, secteur, taille):
    f.seek(depart + secteur * SECTEUR)
    data = f.read(taille)
    vus, sortie = set(), []

    def noeud(pos):
        if pos in vus or pos + 14 > len(data):
            return
        vus.add(pos)
        gauche, droite, sec, tai, attr, lon = struct.unpack_from("<HHIIBB", data, pos)
        if gauche == 0xFFFF:
            return
        sortie.append((data[pos + 14 : pos + 14 + lon].decode("latin-1"), sec, tai, attr))
        if gauche:
            noeud(gauche * 4)
        if droite:
            noeud(droite * 4)

    noeud(0)
    return sortie


def parcours(f, depart, secteur, taille, prefixe, fichiers):
    for nom, sec, tai, attr in lit_dossier(f, depart, secteur, taille):
        if attr & 0x10:
            parcours(f, depart, sec, tai, prefixe + nom + "/", fichiers)
        else:
            fichiers[(prefixe + nom).lower()] = (sec, tai)


iso, dest = sys.argv[1], sys.argv[2]
with open(iso, "rb") as f:
    depart = next(d for d in DEPARTS if not f.seek(d + 0x10000) is None and f.read(20) == MAGIE)
    f.seek(depart + 0x10000 + 20)
    racine, taille = struct.unpack("<II", f.read(8))
    fichiers = {}
    parcours(f, depart, racine, taille, "", fichiers)
    for nom in VOULUS:
        sec, tai = fichiers[nom]
        sortie = os.path.join(dest, nom)
        os.makedirs(os.path.dirname(sortie) or dest, exist_ok=True)
        f.seek(depart + sec * SECTEUR)
        with open(sortie, "wb") as o:
            reste = tai
            while reste:
                morceau = f.read(min(reste, 1 << 20))
                o.write(morceau)
                reste -= len(morceau)
        print(nom, tai)
