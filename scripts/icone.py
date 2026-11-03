"""Dessine l'icône de l'app (512x512, PNG) aux couleurs du Brésil 2014, sans bibliothèque d'image.

Disque vert, losange jaune et cercle bleu du drapeau, ballon blanc à pentagones noirs.
Anticrénelage par 3x3 échantillons par pixel. Usage : icone.py sortie.png
"""
import math
import struct
import sys
import zlib

N = 512
C = N / 2


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(4))


def polygon(cx, cy, r, sides, start):
    return [(cx + r * math.cos(start + 2 * math.pi * k / sides),
             cy + r * math.sin(start + 2 * math.pi * k / sides)) for k in range(sides)]


def inside(poly, x, y):
    hit = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            hit = not hit
        j = i
    return hit


def seg_dist(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    return math.hypot(px - ax - t * dx, py - ay - t * dy)


R_DISC, R_BLUE, R_BALL = 248, 124, 96
diamond = [(C - 218, C), (C, C - 156), (C + 218, C), (C, C + 156)]
up = -math.pi / 2
center_pent = polygon(C, C, 30, 5, up)
outer_pents = [polygon(C + 86 * math.cos(up + math.pi + 2 * math.pi * k / 5),
                       C + 86 * math.sin(up + math.pi + 2 * math.pi * k / 5), 30, 5,
                       up + math.pi + 2 * math.pi * k / 5) for k in range(5)]
# Coutures : des sommets du pentagone central vers les pentagones du bord.
seams = []
for k in range(5):
    vx, vy = center_pent[k]
    seams.append((vx, vy, C + 64 * math.cos(up + 2 * math.pi * k / 5),
                  C + 64 * math.sin(up + 2 * math.pi * k / 5)))

GREEN_IN, GREEN_OUT = (0, 168, 89, 255), (0, 96, 48, 255)
YELLOW, YELLOW_DARK = (255, 221, 0, 255), (240, 180, 0, 255)
BLUE_IN, BLUE_OUT = (18, 64, 160, 255), (0, 30, 100, 255)
WHITE, SHADE, INK = (255, 255, 255, 255), (205, 214, 226, 255), (18, 22, 30, 255)


def color(x, y):
    d = math.hypot(x - C, y - C)
    if d > R_DISC:
        return (0, 0, 0, 0)
    if d > R_DISC - 7:
        return YELLOW  # liseré jaune
    if d <= R_BALL:
        if any(inside(p, x, y) for p in [center_pent] + outer_pents):
            return INK
        if any(seg_dist(x, y, *s) < 2.6 for s in seams):
            return INK
        # Ombre douce vers le bas à droite.
        light = math.hypot(x - (C - 30), y - (C - 34)) / (R_BALL * 1.6)
        return mix(WHITE, SHADE, min(1.0, light * light))
    if d <= R_BALL + 5:
        return (10, 20, 50, 255)  # contour du ballon
    if d <= R_BLUE:
        return mix(BLUE_IN, BLUE_OUT, (d - R_BALL) / (R_BLUE - R_BALL))
    if inside(diamond, x, y):
        return mix(YELLOW, YELLOW_DARK, abs(y - C) / 156)
    return mix(GREEN_IN, GREEN_OUT, d / R_DISC)


rows = bytearray()
S = 3
for py in range(N):
    rows.append(0)
    for px in range(N):
        acc = [0.0] * 4
        for sy in range(S):
            for sx in range(S):
                c = color(px + (sx + 0.5) / S, py + (sy + 0.5) / S)
                a = c[3] / 255
                acc[0] += c[0] * a
                acc[1] += c[1] * a
                acc[2] += c[2] * a
                acc[3] += a
        a = acc[3]
        rows += bytes([int(acc[0] / a) if a else 0, int(acc[1] / a) if a else 0,
                       int(acc[2] / a) if a else 0, int(255 * a / (S * S))])


def chunk(t, d):
    return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d))


png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", N, N, 8, 6, 0, 0, 0)) +
       chunk(b"IDAT", zlib.compress(bytes(rows), 9)) + chunk(b"IEND", b""))
open(sys.argv[1], "wb").write(png)
print("icône écrite", len(png), "octets")
