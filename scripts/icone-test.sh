#!/bin/bash
# Vérifie qu'aapt compile une ressource image sans la bibliothèque Android.
rm -rf /tmp/ic && mkdir -p /tmp/ic/res/drawable && cd /tmp/ic
printf '<manifest package="com.wc14.test"/>' > m.xml
# Un PNG minuscule (1x1 rouge).
python3 - <<'E'
import struct, zlib
raw = b"\0\xff\0\0\xff"
def chunk(t, d): return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d))
png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b"")
open("res/drawable/icon.png", "wb").write(png)
E
aapt package -f -M m.xml -S res -F t.apk 2>&1 | tail -3
aapt dump resources t.apk 2>&1 | grep -iE 'icon|package'
unzip -l t.apk
