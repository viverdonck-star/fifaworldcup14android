"""Tire l'image la plus grande d'un .ico (32 bits, BGRA de bas en haut) en PNG.

Usage : ico-png.py icone.ico sortie.png
"""
import struct
import sys
import zlib

data = open(sys.argv[1], "rb").read()
count = struct.unpack_from("<H", data, 4)[0]
best = None
for i in range(count):
    w, h, _, _, _, bpp, size, offset = struct.unpack_from("<BBBBHHII", data, 6 + 16 * i)
    w = w or 256
    if best is None or w > best[0]:
        best = (w, size, offset)
w, size, offset = best
header = struct.unpack_from("<IiiHH", data, offset)
pixels = data[offset + header[0]:]
rows = bytearray()
for y in range(w):
    rows.append(0)
    src = pixels[(w - 1 - y) * w * 4:(w - y) * w * 4]
    for x in range(w):
        b, g, r, a = src[x * 4:x * 4 + 4]
        rows += bytes((r, g, b, a))


def chunk(t, d):
    return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d))


png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, w, 8, 6, 0, 0, 0)) +
       chunk(b"IDAT", zlib.compress(bytes(rows), 9)) + chunk(b"IEND", b""))
open(sys.argv[2], "wb").write(png)
print(w, "x", w)
