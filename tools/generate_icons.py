#!/usr/bin/env python3
"""Generates the TailDeck launcher icon set with only the std-lib.

Moti: a 2x2 grid of four rounded tiles in the app palette on the dark navy
background -- the same visual language as the home grid.

Writes:
  * legacy mipmap-*/ic_launcher.png            (opaque)
  * adaptive mipmap-*/ic_launcher_foreground.png  (transparent bg)
  * mipmap-anydpi-v26/ic_launcher.xml + values/colors.xml
"""
import os
import struct
import zlib
import math

RES = os.path.join(
    os.path.dirname(os.path.realpath(__file__)),
    "..", "app", "android", "app", "src", "main", "res",
)

BG = (0x0A, 0x0E, 0x13)  # AppColors.bg
TILES = [
    (0x6C, 0x5C, 0xE7),  # indigo -- AppColors.primary
    (0x22, 0xC5, 0x5E),  # green
    (0x3B, 0x82, 0xF6),  # blue
    (0xF9, 0x73, 0x16),  # orange
]


def _sdf(px, py, tx, ty, half, radius):
    """<=0 when (px,py) is inside the rounded square."""
    dx = abs(px - tx) - (half - radius)
    dy = abs(py - ty) - (half - radius)
    dx = dx if dx > 0.0 else 0.0
    dy = dy if dy > 0.0 else 0.0
    return math.hypot(dx, dy) - radius


def render(size, motif_frac, opaque):
    """Raw RGBA bytes for a square icon."""
    ss = 2
    motif = motif_frac * size
    gap = 0.09 * motif
    tile = (motif - gap) / 2.0
    half = tile / 2.0
    radius = tile * 0.24
    offset = half + gap / 2.0
    centers = [(-offset, -offset), (offset, -offset), (-offset, offset), (offset, offset)]
    bg = BG if opaque else (0, 0, 0)
    ss2 = ss * ss
    half_canvas = size / 2.0
    out = bytearray(size * size * 4)
    for py in range(size):
        base_y = py - half_canvas
        for px in range(size):
            base_x = px - half_canvas
            rs = gs = bs = asum = 0
            for sy in range(ss):
                y = base_y + (sy + 0.5) / ss
                for sx in range(ss):
                    x = base_x + (sx + 0.5) / ss
                    cr, cg, cb = bg
                    alpha = 255 if opaque else 0
                    for (ox, oy), tile in zip(centers, TILES):
                        if _sdf(x, y, ox, oy, half, radius) <= 0.0:
                            cr, cg, cb = tile
                            alpha = 255
                            break
                    rs += cr
                    gs += cg
                    bs += cb
                    asum += alpha
            idx = (py * size + px) * 4
            out[idx] = rs // ss2
            out[idx + 1] = gs // ss2
            out[idx + 2] = bs // ss2
            out[idx + 3] = asum // ss2
    return bytes(out)


def write_png(path, size, rgba):
    def chunk(tp, data):
        return (
            struct.pack(">I", len(data))
            + tp
            + data
            + struct.pack(">I", zlib.crc32(tp + data) & 0xFFFFFFFF)
        )

    raw = bytearray()
    for y in range(size):
        raw.append(0)  # filter 0
        start = y * size * 4
        raw.extend(rgba[start:start + size * 4])

    ihdr = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", ihdr)
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)
    print(f"  {os.path.basename(path)} {size}x{size}")


LEGACY = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
FOREGROUND = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}


def main():
    print("legacy launcher icons:")
    for dens, size in LEGACY.items():
        write_png(
            os.path.join(RES, f"mipmap-{dens}", "ic_launcher.png"),
            size,
            render(size, 0.80, opaque=True),
        )

    print("adaptive foregrounds:")
    for dens, size in FOREGROUND.items():
        write_png(
            os.path.join(RES, f"mipmap-{dens}", "ic_launcher_foreground.png"),
            size,
            render(size, 0.56, opaque=False),
        )

    anydpi = os.path.join(RES, "mipmap-anydpi-v26")
    os.makedirs(anydpi, exist_ok=True)
    with open(os.path.join(anydpi, "ic_launcher.xml"), "w") as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <background android:drawable="@color/ic_launcher_background"/>\n'
            '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
            "</adaptive-icon>\n"
        )

    with open(os.path.join(RES, "values", "colors.xml"), "w") as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            "<resources>\n"
            '    <color name="ic_launcher_background">#0A0E13</color>\n'
            "</resources>\n"
        )
    print("adaptive-icon xml + colors written")


if __name__ == "__main__":
    main()