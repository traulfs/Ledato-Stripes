#!/usr/bin/env python3
"""DDP-Client, der aus den zwei Uhr-Stripes eine analoge Uhr macht.

Fest auf das aktuelle Uhr-Layout zugeschnitten: Stripe 1 (Ziel-ID 1) hat
12 Sektionen zu je 6 LEDs (72 LEDs), die abwechselnd nach außen und nach
innen zeigen (siehe SECTION_SPECS) — welches LED-Ende (Index 0 oder das
letzte) physisch näher am Zentrum liegt, wechselt pro Sektion je nach
Start-/Winkel-Geometrie in der App-Konfiguration. Stripe 2 (Ziel-ID 2)
ist ein durchgehender Ring aus 60 LEDs.

Anzeige:
    Stripe 1: Die physisch inneren LEDs (eine mehr als die äußeren) einer
              Sektion = Stunde (blau), wenn diese Sektion der aktuellen
              Stunde (0..11) entspricht. Die Sektion der nächstliegenden
              5-Minuten-Marke leuchtet komplett rot (Minute). Fallen
              Stunden- und Minuten-Sektion zusammen, teilen sich beide
              die Sektion zu gleichen Teilen (halb blau, halb rot). Als
              Kontur der Uhrenform leuchten die äußeren LEDs aller
              übrigen Sektionen leicht grün.
    Stripe 2: Minute (rot) und Sekunde (gelb) je als einzelne LED-Position
              (1:1 auf 0..59). Bei Überlagerung gewinnt die Sekunde. Alle
              übrigen LEDs des Rings leuchten leicht grün (Kontur der
              Ringform). Keine Stundenanzeige auf diesem Stripe.

Beispiele:
    python3 ddp_clock.py --host 192.168.1.50

    # Mit --speed schneller durchlaufen lassen (zum Testen)
    python3 ddp_clock.py --speed 60

    # Feste Uhrzeit anzeigen (zum Testen einzelner Positionen)
    python3 ddp_clock.py --time 14:35:07
"""

from __future__ import annotations

import argparse
import socket
import time
from datetime import datetime
from typing import List, Tuple

from ddp_client import DDP_DEFAULT_PORT, send_ddp_frame

Pixel = Tuple[int, int, int]

OFF: Pixel = (0, 0, 0)
RED: Pixel = (255, 0, 0)
YELLOW: Pixel = (255, 255, 0)
BLUE: Pixel = (0, 0, 255)
FAINT_GREEN: Pixel = (0, 50, 0)  # Kontur der Uhrenform, wo keine Zeit angezeigt wird

STRIPE1_DEST = 1  # Sektionen: Stunde (innen) + Minutenmarke (außen)
STRIPE2_DEST = 2  # durchgehender Ring: Sekunde + Minute + Stunde als Zeiger

# (LED-Anzahl der Sektion, LED-Index 0 liegt physisch innen?) — aus der
# App-Konfiguration ermittelt: die 12 Sektionen von Stripe 1 wechseln sich
# ab, weil ihre Start-/Winkel-Geometrie abwechselnd nach außen bzw. innen
# zeigt.
SectionSpec = Tuple[int, bool]
SECTION_SPECS: List[SectionSpec] = [(6, i % 2 == 0) for i in range(12)]
POINTER_TOTAL = 60  # LEDs auf Stripe 2


def stripe1_frame(
    hour12: int, minute: int, section_specs: List[SectionSpec]
) -> List[Pixel]:
    sections = len(section_specs)
    minute_mark = round(minute / 5) % sections
    pixels: List[Pixel] = []
    for i, (n, inner_first) in enumerate(section_specs):
        is_hour = i == hour12
        is_minute = i == minute_mark
        if is_hour and is_minute:
            # Konkurrenz um dieselbe Sektion: beide bekommen gleich viele LEDs.
            inner_n = n // 2
            outer_n = n - inner_n
            hour_block = [BLUE] * inner_n
            minute_block = [RED] * outer_n
        elif is_minute:
            # Minute allein leuchtet über die ganze Sektion.
            inner_n = min(n // 2 + 1, n)
            outer_n = n - inner_n
            hour_block = [RED] * inner_n
            minute_block = [RED] * outer_n
        else:
            # Stunde eine LED länger als Minute, sonst Kontur (leicht grün).
            inner_n = min(n // 2 + 1, n)
            outer_n = n - inner_n
            hour_block = [BLUE if is_hour else OFF] * inner_n
            minute_block = [FAINT_GREEN] * outer_n
        if inner_first:
            pixels.extend(hour_block)
            pixels.extend(minute_block)
        else:
            pixels.extend(minute_block)
            pixels.extend(hour_block)
    return pixels


def stripe2_frame(second: int, minute: int, total: int) -> List[Pixel]:
    # Kontur der Ringform: alle sonst ungenutzten LEDs leicht grün.
    pixels = [FAINT_GREEN] * total
    # Reihenfolge = Priorität bei Überlagerung: Sekunde vor Minute.
    pixels[minute % total] = RED
    pixels[second % total] = YELLOW
    return pixels


def main() -> None:
    parser = argparse.ArgumentParser(
        description="DDP-Client: zeigt eine analoge Uhr auf den zwei Uhr-Stripes an.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("--host", default="127.0.0.1", help="Ziel-IP der App (Standard: 127.0.0.1)")
    parser.add_argument("--port", type=int, default=DDP_DEFAULT_PORT, help=f"DDP-Port (Standard: {DDP_DEFAULT_PORT})")
    parser.add_argument("--fps", type=float, default=5.0, help="Bildwiederholrate (Standard: 5)")
    parser.add_argument("--speed", type=float, default=1.0, help="Zeitraffer-Faktor, z. B. 60 = eine simulierte Minute pro Sekunde (Standard: 1, Echtzeit)")
    parser.add_argument("--time", help="Feste Startzeit HH:MM:SS statt Systemzeit (läuft ab da mit --speed weiter)")
    parser.add_argument("--duration", type=float, help="Laufzeit in Sekunden (Standard: unbegrenzt, Strg+C zum Beenden)")
    args = parser.parse_args()

    if args.time:
        t0 = datetime.strptime(args.time, "%H:%M:%S")
        sim_start_seconds = t0.hour * 3600 + t0.minute * 60 + t0.second
    else:
        now = datetime.now()
        sim_start_seconds = now.hour * 3600 + now.minute * 60 + now.second

    print(f"Ziel: {args.host}:{args.port}")
    print(
        f"Stripe 1: {sum(n for n, _ in SECTION_SPECS)} LEDs in {len(SECTION_SPECS)} Sektionen "
        f"(Stunde blau innen, Minute rot außen)  |  "
        f"Stripe 2: {POINTER_TOTAL} LEDs (Sekunde gelb, Minute rot)"
    )
    print("Strg+C zum Beenden.")

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    addr = (args.host, args.port)
    frame_interval = 1.0 / args.fps if args.fps > 0 else 0
    start = time.monotonic()
    try:
        while args.duration is None or time.monotonic() - start < args.duration:
            frame_start = time.monotonic()
            elapsed_sim = (frame_start - start) * args.speed
            total_seconds = int(sim_start_seconds + elapsed_sim) % 86400
            hour = (total_seconds // 3600) % 12
            minute = (total_seconds // 60) % 60
            second = total_seconds % 60

            send_ddp_frame(
                sock,
                addr,
                STRIPE1_DEST,
                stripe1_frame(hour, minute, SECTION_SPECS),
            )
            send_ddp_frame(
                sock,
                addr,
                STRIPE2_DEST,
                stripe2_frame(second, minute, POINTER_TOTAL),
            )

            elapsed = time.monotonic() - frame_start
            if frame_interval > elapsed:
                time.sleep(frame_interval - elapsed)
    except KeyboardInterrupt:
        print("\nBeendet.")
    finally:
        sock.close()


if __name__ == "__main__":
    main()
