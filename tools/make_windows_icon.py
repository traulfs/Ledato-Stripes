#!/usr/bin/env python3
"""Erzeugt das Windows-App-Icon aus assets/icon/app_icon.png.

Windows zeigt dasselbe Icon in sehr unterschiedlichen Größen an — 16 px im
Fenstertitel, 32 px in der Taskleiste, 256 px in der Explorer-Großansicht.
Eine .ico-Datei kann all diese Größen zugleich enthalten; Windows nimmt dann
die passende, statt aus 256 px herunterzuskalieren. flutter_launcher_icons
schreibt für Windows nur eine einzige Größe, deshalb dieses Skript.

Die Größen bis 128 px werden als unkomprimiertes DIB (BMP) abgelegt, nur
256 px als PNG — das ist die Aufteilung, die auch etablierte Icon-Werkzeuge
verwenden und die jede Windows-Version und jede Icon-API versteht. (Pillows
eigener ICO-Export schreibt inzwischen durchgängig PNG, was erst ab Vista
sicher unterstützt wird.)

Voraussetzung:  pip install pillow

Aufruf:  python3 tools/make_windows_icon.py
"""

from __future__ import annotations

import io
import pathlib
import struct
import sys

SIZES = [16, 24, 32, 48, 64, 128, 256]
PNG_FROM = 256  # ab dieser Kantenlänge PNG statt DIB

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets" / "icon" / "app_icon.png"
TARGET = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"


def dib_payload(image) -> bytes:
    """Ein Icon-Bild als 32-bit-DIB: BITMAPINFOHEADER, XOR-Bilddaten, AND-Maske."""
    w, h = image.size
    px = image.load()

    # BITMAPINFOHEADER — die Höhe zählt doppelt, weil XOR-Bild und AND-Maske
    # zusammen als ein Bitmap gelten.
    header = struct.pack(
        "<IiiHHIIiiII", 40, w, h * 2, 1, 32, 0, 0, 0, 0, 0, 0
    )

    # XOR-Bilddaten: BGRA, zeilenweise von unten nach oben.
    xor = bytearray()
    for y in range(h - 1, -1, -1):
        for x in range(w):
            r, g, b, a = px[x, y]
            xor += bytes((b, g, r, a))

    # AND-Maske: 1 Bit je Pixel (1 = transparent), Zeilen auf 4 Byte gepolstert.
    row_bytes = ((w + 31) // 32) * 4
    mask = bytearray()
    for y in range(h - 1, -1, -1):
        row = bytearray(row_bytes)
        for x in range(w):
            if px[x, y][3] < 128:
                row[x // 8] |= 0x80 >> (x % 8)
        mask += row

    return bytes(header) + bytes(xor) + bytes(mask)


def png_payload(image) -> bytes:
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")
    return buffer.getvalue()


def main() -> None:
    try:
        from PIL import Image
    except ImportError:
        sys.exit("Pillow wird benötigt: pip install pillow")

    if not SOURCE.exists():
        sys.exit(f"Quellbild nicht gefunden: {SOURCE}")

    source = Image.open(SOURCE).convert("RGBA")
    if source.width != source.height:
        sys.exit(f"Quellbild ist nicht quadratisch: {source.width}×{source.height}")
    if source.width < max(SIZES):
        sys.exit(f"Quellbild ist mit {source.width} px kleiner als {max(SIZES)} px")

    payloads = []
    for size in SIZES:
        scaled = source.resize((size, size), Image.LANCZOS)
        payloads.append(
            png_payload(scaled) if size >= PNG_FROM else dib_payload(scaled)
        )

    # ICONDIR, dann je Größe ein 16 Byte großer ICONDIRENTRY, dann die Bilder.
    offset = 6 + 16 * len(SIZES)
    out = bytearray(struct.pack("<HHH", 0, 1, len(SIZES)))
    for size, payload in zip(SIZES, payloads):
        # 256 wird als 0 kodiert — das Feld ist nur ein Byte breit.
        dimension = 0 if size >= 256 else size
        out += struct.pack(
            "<BBBBHHII", dimension, dimension, 0, 0, 1, 32, len(payload), offset
        )
        offset += len(payload)
    for payload in payloads:
        out += payload

    TARGET.write_bytes(out)
    print(
        f"{TARGET.relative_to(ROOT)}: "
        f"{', '.join(f'{s}×{s}' for s in SIZES)} ({len(out)} Byte)"
    )


if __name__ == "__main__":
    main()
