"""Calques de l'icône adaptative Android à partir de l'icône carrée du jeu (PNG RGBA).

Le premier plan : l'image centrée sur 108 unités, à 66 de côté (le cercle sûr d'Android) ;
le fond : la couleur moyenne des bords de l'image, pour que le cercle soit plein.
Usage : icone-calques.py icon.png icon_fg.png icon_bg.png
"""
import struct
import sys
import zlib


def read_png(path):
    data = open(path, "rb").read()
    pos, idat, w = 8, b"", 0
    while pos < len(data):
        n, kind = struct.unpack_from(">I4s", data, pos)
        body = data[pos + 8:pos + 8 + n]
        if kind == b"IHDR":
            w, h = struct.unpack_from(">II", body)
        elif kind == b"IDAT":
            idat += body
        pos += 12 + n
    raw = zlib.decompress(idat)
    rows, prev, stride = [], bytearray(w * 4), w * 4
    for y in range(h):
        f, line = raw[y * (stride + 1)], bytearray(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)])
        for i in range(stride):
            a = line[i - 4] if i >= 4 else 0
            b, c = prev[i], prev[i - 4] if i >= 4 else 0
            if f == 1: line[i] = (line[i] + a) & 255
            elif f == 2: line[i] = (line[i] + b) & 255
            elif f == 3: line[i] = (line[i] + (a + b) // 2) & 255
            elif f == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[i] = (line[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        rows.append(line)
        prev = line
    return w, h, rows


def write_png(path, w, h, rows):
    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d))
    raw = b"".join(b"\0" + bytes(r) for r in rows)
    open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)) +
                          chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


w, h, rows = read_png(sys.argv[1])
size = round(w * 108 / 66)
pad = (size - w) // 2
fg = [bytearray(size * 4) for _ in range(size)]
for y in range(h):
    fg[pad + y][pad * 4:(pad + w) * 4] = rows[y]
write_png(sys.argv[2], size, size, fg)
edge = [rows[y][x * 4:x * 4 + 3] for y in range(h) for x in range(w) if x in (0, w - 1) or y in (0, h - 1)]
color = bytes(sum(p[i] for p in edge) // len(edge) for i in range(3)) + b"\xff"
write_png(sys.argv[3], size, size, [bytearray(color * size) for _ in range(size)])
print("calques", size, "px, fond", color[:3].hex())
