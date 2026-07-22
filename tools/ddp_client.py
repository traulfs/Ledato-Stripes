#!/usr/bin/env python3
"""DDP-Client zum Testen des in Ledato Stripes eingebauten DDP-Servers.

Sendet fortlaufend Pixel-Frames per UDP (DDP-Protokoll, siehe
http://www.3waylabs.com/ddp/) an die App. Die 1-Byte-Zieladresse eines
Pakets entspricht der Position des Stripes in der App-Konfiguration
(1 = erster Stripe, 2 = zweiter, ...).

Beispiele:
    # 8 Stripes a 60 LEDs, jeder mit einem anderen Demo-Effekt
    python3 ddp_client.py --host 192.168.1.50

    # Nur zwei Stripes (150 und 60 LEDs), beide im Regenbogen-Effekt
    python3 ddp_client.py --host 192.168.1.50 --leds 150,60 --effect rainbow

    # LED-Anzahl aus einer exportierten Ledato-Stripes-YAML übernehmen
    python3 ddp_client.py --host 192.168.1.50 --config config.yaml

    # Verfügbare Effekte auflisten
    python3 ddp_client.py --list-effects

Keine externen Abhängigkeiten nötig, außer für --config (dort wird PyYAML
verwendet, falls installiert: `pip install pyyaml`).
"""

from __future__ import annotations

import argparse
import colorsys
import math
import random
import socket
import struct
import sys
import time
from typing import Callable, List, Tuple

Pixel = Tuple[int, int, int]
Effect = Callable[[int, float], List[Pixel]]

DDP_DEFAULT_PORT = 4048
DDP_HEADER_LEN = 10
DDP_FLAGS_VER1 = 0x40
DDP_FLAGS_PUSH = 0x01
DDP_TYPE_RGB24 = 0x0B
DDP_MAX_LEDS_PER_PACKET = 480  # 1440 Byte Nutzlast, siehe DDP-Spezifikation


def clamp255(v: float) -> int:
    return max(0, min(255, int(v)))


def hsv(h: float, s: float, v: float) -> Pixel:
    r, g, b = colorsys.hsv_to_rgb(h % 1.0, s, v)
    return (clamp255(r * 255), clamp255(g * 255), clamp255(b * 255))


# ---------- Effekte ----------
# Jeder Effekt bekommt die LED-Anzahl des Stripes und die seit Start
# vergangene Zeit in Sekunden und liefert eine Liste von (r,g,b)-Tupeln.


def fx_solid(n: int, t: float, color: Pixel = (255, 140, 0)) -> List[Pixel]:
    return [color] * n


def fx_rainbow(n: int, t: float) -> List[Pixel]:
    return [hsv(i / max(n, 1) + t * 0.15, 1.0, 1.0) for i in range(n)]


def fx_chase(n: int, t: float, width: int = 3, color: Pixel = (0, 180, 255)) -> List[Pixel]:
    pos = (t * n * 0.4) % n
    out = [(0, 0, 0)] * n
    for i in range(width):
        idx = int(pos + i) % n
        out[idx] = color
    return out


def fx_theater_chase(n: int, t: float, color: Pixel = (255, 40, 200)) -> List[Pixel]:
    offset = int(t * 8) % 3
    return [color if (i + offset) % 3 == 0 else (0, 0, 0) for i in range(n)]


def fx_color_wipe(n: int, t: float, color: Pixel = (40, 255, 90)) -> List[Pixel]:
    cycle = 2.5  # Sekunden für einen vollen Durchlauf
    frac = (t % cycle) / cycle
    lit = int(frac * n)
    return [color if i < lit else (0, 0, 0) for i in range(n)]


def fx_breathe(n: int, t: float, color: Pixel = (255, 0, 80)) -> List[Pixel]:
    level = (math.sin(t * 2.0) + 1) / 2  # 0..1
    return [tuple(clamp255(c * level) for c in color)] * n


def fx_sparkle(n: int, t: float, color: Pixel = (255, 255, 255)) -> List[Pixel]:
    out = [(0, 0, 0)] * n
    for _ in range(max(1, n // 12)):
        out[random.randrange(n)] = color
    return out


def fx_fire(n: int, t: float) -> List[Pixel]:
    # Einfache Flamme: zufällige Helligkeit pro LED, in Orange/Rot-Palette
    # gemappt, mit leichtem "Glimmen" nahe dem unteren Ende der Skala.
    out = []
    for i in range(n):
        heat = random.uniform(0.4, 1.0) * (1 - 0.5 * i / max(n, 1))
        r = clamp255(255 * min(1.0, heat * 1.4))
        g = clamp255(120 * heat * heat)
        b = clamp255(20 * heat * heat * heat)
        out.append((r, g, b))
    return out


EFFECTS: dict[str, Effect] = {
    "solid": fx_solid,
    "rainbow": fx_rainbow,
    "chase": fx_chase,
    "theater": fx_theater_chase,
    "wipe": fx_color_wipe,
    "breathe": fx_breathe,
    "sparkle": fx_sparkle,
    "fire": fx_fire,
}


# ---------- DDP-Versand ----------


def send_ddp_frame(sock: socket.socket, addr: Tuple[str, int], destination: int, pixels: List[Pixel]) -> None:
    """Sendet einen Stripe als eines oder mehrere DDP-Pakete (Fragmentierung
    nur nötig, falls mehr LEDs als in ein Paket passen — bei Ledato Stripes
    max. 300 LEDs, also praktisch nie)."""
    total = len(pixels)
    offset = 0
    while offset < total:
        chunk = pixels[offset : offset + DDP_MAX_LEDS_PER_PACKET]
        data = b"".join(struct.pack("BBB", *p) for p in chunk)
        header = struct.pack(
            ">BBBBIH",
            DDP_FLAGS_VER1 | DDP_FLAGS_PUSH,
            0,  # sequenceNum (0 = deaktiviert)
            DDP_TYPE_RGB24,
            destination,
            offset * 3,  # Kanal-Offset in Bytes
            len(data),
        )
        sock.sendto(header + data, addr)
        offset += len(chunk)


# ---------- Konfiguration laden ----------


def load_led_counts_from_config(path: str) -> List[int]:
    try:
        import yaml
    except ImportError:
        sys.exit(
            "Für --config wird PyYAML benötigt: pip install pyyaml "
            "(oder stattdessen --leds verwenden)."
        )
    with open(path, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f)
    counts = []
    for strip in data.get("strips", []):
        sections = strip.get("sections", [])
        counts.append(sum(int(s.get("ledCount", 0)) for s in sections))
    if not counts:
        sys.exit(f"Keine Stripes in {path} gefunden.")
    return counts


def parse_leds_arg(value: str) -> List[int]:
    try:
        counts = [int(x.strip()) for x in value.split(",") if x.strip()]
    except ValueError:
        raise argparse.ArgumentTypeError("--leds erwartet z. B. \"60,150,90\"")
    if not counts:
        raise argparse.ArgumentTypeError("--leds darf nicht leer sein")
    return counts


def main() -> None:
    parser = argparse.ArgumentParser(
        description="DDP-Client: sendet Test-Effekte an den Ledato-Stripes-DDP-Server.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("--host", default="127.0.0.1", help="Ziel-IP der App (Standard: 127.0.0.1)")
    parser.add_argument("--port", type=int, default=DDP_DEFAULT_PORT, help=f"DDP-Port (Standard: {DDP_DEFAULT_PORT})")
    parser.add_argument("--config", help="Pfad zu einer exportierten Ledato-Stripes-YAML (LED-Anzahl je Stripe daraus übernehmen)")
    parser.add_argument("--leds", type=parse_leds_arg, help='Kommagetrennte LED-Anzahl je Stripe, z. B. "60,150,90" (ignoriert, falls --config gesetzt)')
    parser.add_argument("--effect", choices=sorted(EFFECTS), help="Ein Effekt für alle Stripes gleichzeitig (ohne Angabe: reihum ein anderer Effekt je Stripe)")
    parser.add_argument("--fps", type=float, default=30.0, help="Bildwiederholrate (Standard: 30)")
    parser.add_argument("--duration", type=float, help="Laufzeit in Sekunden (Standard: unbegrenzt, Strg+C zum Beenden)")
    parser.add_argument("--list-effects", action="store_true", help="Verfügbare Effektnamen auflisten und beenden")
    args = parser.parse_args()

    if args.list_effects:
        print("Verfügbare Effekte:", ", ".join(sorted(EFFECTS)))
        return

    if args.config:
        led_counts = load_led_counts_from_config(args.config)
    elif args.leds:
        led_counts = args.leds
    else:
        led_counts = [60] * 8

    names = sorted(EFFECTS)
    if args.effect:
        effect_for_strip = [EFFECTS[args.effect]] * len(led_counts)
    else:
        effect_for_strip = [EFFECTS[names[i % len(names)]] for i in range(len(led_counts))]

    print(f"Ziel: {args.host}:{args.port}")
    for i, (n, fx) in enumerate(zip(led_counts, effect_for_strip), start=1):
        print(f"  Stripe {i}: {n} LEDs, Effekt '{fx.__name__.removeprefix('fx_')}'")
    print("Strg+C zum Beenden.")

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    addr = (args.host, args.port)
    frame_interval = 1.0 / args.fps if args.fps > 0 else 0
    start = time.monotonic()
    try:
        while args.duration is None or time.monotonic() - start < args.duration:
            frame_start = time.monotonic()
            t = frame_start - start
            for i, (n, fx) in enumerate(zip(led_counts, effect_for_strip), start=1):
                pixels = fx(n, t)
                send_ddp_frame(sock, addr, i, pixels)
            elapsed = time.monotonic() - frame_start
            if frame_interval > elapsed:
                time.sleep(frame_interval - elapsed)
    except KeyboardInterrupt:
        print("\nBeendet.")
    finally:
        sock.close()


if __name__ == "__main__":
    main()
