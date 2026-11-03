"""Encode AndroidManifest.xml en XML binaire Android (ce que fait aapt), sans aapt.

L'aapt de Debian ne lit pas les ressources d'Android 15 ; le manifeste n'en a pas
besoin : les attributs android: prennent leur identifiant officiel (android.jar,
scripts/attrs.sh), et les valeurs leur type.
Usage : axml.py AndroidManifest.xml sortie.xml [@type/nom=0x7f...]
"""
import struct
import sys
import xml.etree.ElementTree as ET

ANDROID = "http://schemas.android.com/apk/res/android"
IDS = {
    "theme": 0x01010000, "label": 0x01010001, "icon": 0x01010002, "name": 0x01010003,
    "debuggable": 0x0101000F, "drawable": 0x01010199,
    "exported": 0x01010010, "process": 0x01010011, "launchMode": 0x0101001D,
    "screenOrientation": 0x0101001E, "configChanges": 0x0101001F, "minSdkVersion": 0x0101020C,
    "versionCode": 0x0101021B, "versionName": 0x0101021C, "targetSdkVersion": 0x01010270,
    "glEsVersion": 0x01010281, "required": 0x0101028E, "hardwareAccelerated": 0x010102D3,
    "extractNativeLibs": 0x010104EA, "preferMinimalPostProcessing": 0x0101060C,
}
BOOLS = {"debuggable", "exported", "extractNativeLibs", "hardwareAccelerated", "required",
         "preferMinimalPostProcessing"}
INTS = {"versionCode", "minSdkVersion", "targetSdkVersion"}
ENUMS = {
    "launchMode": {"standard": 0, "singleTop": 1, "singleTask": 2, "singleInstance": 3},
    "screenOrientation": {"landscape": 0, "portrait": 1, "sensorLandscape": 6},
}
CONFIG = {"mcc": 0x1, "mnc": 0x2, "locale": 0x4, "touchscreen": 0x8, "keyboard": 0x10,
          "keyboardHidden": 0x20, "navigation": 0x40, "orientation": 0x80, "screenLayout": 0x100,
          "uiMode": 0x200, "screenSize": 0x400, "smallestScreenSize": 0x800, "density": 0x1000,
          "layoutDirection": 0x2000, "colorMode": 0x4000, "grammaticalGender": 0x8000,
          "fontWeightAdjustment": 0x10000000, "fontScale": 0x40000000}
# Les ressources de l'app (l'icône), compilées par aapt sans framework : leurs
# identifiants sont passés en plus, "@type/nom=0x7f......" (apk2.sh).
REFS = {"@android:style/Theme.NoTitleBar.Fullscreen": 0x01030007}
for extra in sys.argv[3:]:
    name, value = extra.split("=")
    REFS[name] = int(value, 16)
T_REF, T_STRING, T_DEC, T_HEX, T_BOOL = 0x01, 0x03, 0x10, 0x11, 0x12

tree = ET.parse(sys.argv[1])
elements = list(tree.getroot().iter())

# Le pool de chaînes : d'abord les noms d'attributs android: (dans l'ordre de la
# table des identifiants), puis le reste.
attr_names = sorted({k.split("}")[1] for e in elements for k in e.attrib if k.startswith("{")},
                    key=lambda n: IDS[n])
strings = list(attr_names)


def index(text):
    if text not in strings:
        strings.append(text)
    return strings.index(text)


index("android"), index(ANDROID)


def encode(name, value):
    """(chaîne brute ou -1, type, donnée)."""
    if name in BOOLS:
        return -1, T_BOOL, 0xFFFFFFFF if value == "true" else 0
    if name in INTS:
        return -1, T_DEC, int(value)
    if name == "glEsVersion":
        return -1, T_HEX, int(value, 16)
    if name in ENUMS:
        return -1, T_DEC, ENUMS[name][value]
    if name == "configChanges":
        flags = 0
        for part in value.split("|"):
            flags |= CONFIG[part]
        return -1, T_HEX, flags
    if value in REFS:
        return -1, T_REF, REFS[value]
    i = index(value)
    return i, T_STRING, i


body = b""
body += struct.pack("<HHIIIII", 0x0100, 16, 24, 1, 0xFFFFFFFF, index("android"), index(ANDROID))


def element(e, line=[2]):
    global body
    attrs = []
    for key, value in e.attrib.items():
        if key.startswith("{"):
            name = key.split("}")[1]
            ns, rid = index(ANDROID), IDS[name]
        else:
            name, ns, rid = key, 0xFFFFFFFF, 0xFFFFFFFF
        raw, kind, data = encode(name, value)
        attrs.append((rid, ns, index(name), raw, kind, data))
    attrs.sort(key=lambda a: a[0])  # par identifiant, comme aapt
    tag = index(e.tag)
    body += struct.pack("<HHIIIIIHHHHHH", 0x0102, 16, 36 + 20 * len(attrs), line[0], 0xFFFFFFFF,
                        0xFFFFFFFF, tag, 20, 20, len(attrs), 0, 0, 0)
    for rid, ns, name, raw, kind, data in attrs:
        body += struct.pack("<IIiHBBI", ns, name, raw, 8, 0, kind, data)
    line[0] += 1
    for child in e:
        element(child)
    body += struct.pack("<HHIIIII", 0x0103, 16, 24, line[0], 0xFFFFFFFF, 0xFFFFFFFF, tag)
    line[0] += 1


element(tree.getroot())
body += struct.pack("<HHIIIII", 0x0101, 16, 24, 99, 0xFFFFFFFF, index("android"), index(ANDROID))

# Chaînes en UTF-16.
data, offsets = b"", []
for s in strings:
    offsets.append(len(data))
    u = s.encode("utf-16-le")
    data += struct.pack("<H", len(s)) + u + b"\0\0"
while len(data) % 4:
    data += b"\0"
start = 28 + 4 * len(strings)
pool = struct.pack("<HHIIIIII", 0x0001, 28, start + len(data), len(strings), 0, 0, start, 0)
pool += b"".join(struct.pack("<I", o) for o in offsets) + data
ids = struct.pack("<HHI", 0x0180, 8, 8 + 4 * len(attr_names))
ids += b"".join(struct.pack("<I", IDS[n]) for n in attr_names)

content = pool + ids + body
open(sys.argv[2], "wb").write(struct.pack("<HHI", 0x0003, 8, 8 + len(content)) + content)
print(len(strings), "chaînes,", len(elements), "éléments")
