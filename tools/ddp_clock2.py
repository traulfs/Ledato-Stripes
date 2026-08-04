#!/usr/bin/env python3
"""DDP-Client für die Uhr-Konfiguration watch2.ledato.

Fest auf das watch2-Layout zugeschnitten (aus der .ledato-Datei per
`protoc --decode` ermittelt). Es unterscheidet sich von der älteren
Watch1-Konfiguration (siehe ddp_clock.py) in zwei Punkten:

    - Stripe 1 (Ziel-ID 1) hat weiterhin 12 Speichen, aber mit je 7 statt
      6 LEDs (84 LEDs gesamt). Sektion 0 der Datei liegt bei "6 Uhr" statt
      "12 Uhr" und die Sektionen laufen entgegen der Dateireihenfolge um
      das Ziffernblatt (Sektion i entspricht Stundenposition (6 - i) % 12).
      Wie zuvor wechselt sich pro Sektion ab, welches LED-Ende (Index 0
      oder das letzte) physisch näher am Zentrum liegt.
    - Stripe 2 (Ziel-ID 2) ist kein durchgehender Ring mehr, sondern 12
      einzelne Grüppchen zu je 4 LEDs (48 LEDs gesamt) mit Lücken
      dazwischen, jeweils zwischen zwei Speichen von Stripe 1 platziert.
      Die jeweils äußerste LED einer Stripe-1-Speiche sitzt geometrisch
      genau in dieser Lücke und schließt den Ring — 48 (Stripe 2) + 12
      Speichenspitzen (Stripe 1) = 60 Positionen, wie beim alten
      durchgehenden 60-LED-Ring. Minute/Sekunde-Zeiger laufen deshalb über
      BEIDE Stripes (siehe RING/_nearest_ring_pos).

Anzeige (identisch zum Konzept von ddp_clock.py):
    Stripe 1: Die physisch inneren LEDs (eine mehr als die äußeren) einer
              Sektion = Stunde (blau), wenn diese Sektion der aktuellen
              Stunde (0..11) entspricht. Die Sektion der nächstliegenden
              5-Minuten-Marke leuchtet komplett rot (Minute). Fallen
              Stunden- und Minutensektion zusammen, teilen sich beide die
              Sektion zu gleichen Teilen (halb blau, halb rot). Als Kontur
              der Uhrenform leuchten die äußeren LEDs aller übrigen
              Sektionen leicht grün. Die äußerste LED einer Sektion kann
              zusätzlich vom Ring-Zeiger (siehe Stripe 2) überschrieben
              werden, wenn dessen Position dort liegt.
    Stripe 2 + Speichenspitzen von Stripe 1 (60 Positionen gesamt): Minute
              (rot) und Sekunde (gelb) je als einzelne Position auf diesem
              kombinierten Ring, exakt wie beim alten 60-LED-Ring — inkl.
              der zwölf Speichenspitzen als Brücken über die Lücken. Bei
              Überlagerung gewinnt die Sekunde. Alle übrigen Stripe-2-LEDs
              leuchten leicht grün (Kontur).

Beispiele:
    python3 ddp_clock2.py --host 192.168.1.50

    # Mit --speed schneller durchlaufen lassen (zum Testen)
    python3 ddp_clock2.py --speed 60

    # Feste Uhrzeit anzeigen (zum Testen einzelner Positionen)
    python3 ddp_clock2.py --time 14:35:07
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
STRIPE2_DEST = 2  # 12 Grüppchen, als flache Positionsskala behandelt

# (LED-Anzahl der Sektion, LED-Index 0 liegt physisch innen?) — aus
# watch2.ledato ermittelt: 12 Sektionen zu je 7 LEDs, die sich abwechselnd
# nach außen bzw. innen zeigend orientieren.
SectionSpec = Tuple[int, bool]
SECTION_SPECS: List[SectionSpec] = [(7, i % 2 == 0) for i in range(12)]

# Kombinierter 60-Positionen-Ring für Minute/Sekunde, aus watch2.ledato
# berechnet (Ziffernblatt-Winkel, 0° = 12 Uhr, im Uhrzeigersinn steigend;
# Bildschirmkoordinaten, y wächst nach unten). Stripe 2 allein ist kein
# durchgehender Ring — 4 eng beieinanderliegende LEDs pro Grüppchen, dann
# eine Lücke an der jeweiligen Speiche von Stripe 1. Die äußerste LED jeder
# Speiche liegt geometrisch genau in dieser Lücke und schließt den Ring
# (48 + 12 = 60 Positionen, wie beim alten durchgehenden Ring). Jeder
# Eintrag: (Stripe 1 oder 2, LED-/Sektionsindex auf diesem Stripe, Winkel).
RING: List[Tuple[int, int, float]] = [
    (1, 0, 0.02), (2, 0, 5.83), (2, 1, 11.73), (2, 2, 17.67), (2, 3, 23.54),
    (1, 1, 29.84), (2, 4, 35.70), (2, 5, 41.63), (2, 6, 47.61), (2, 7, 53.52),
    (1, 2, 60.33), (2, 8, 66.04), (2, 9, 71.96), (2, 10, 77.92), (2, 11, 83.80),
    (1, 3, 90.10), (2, 12, 95.59), (2, 13, 101.49), (2, 14, 107.46), (2, 15, 113.38),
    (1, 4, 119.73), (2, 16, 125.73), (2, 17, 131.64), (2, 18, 137.63), (2, 19, 143.57),
    (1, 5, 150.38), (2, 20, 155.35), (2, 21, 161.28), (2, 22, 167.26), (2, 23, 173.18),
    (1, 6, 179.78), (2, 24, 186.10), (2, 25, 192.02), (2, 26, 197.99), (2, 27, 203.87),
    (1, 7, 209.83), (2, 28, 215.92), (2, 29, 221.83), (2, 30, 227.81), (2, 31, 233.73),
    (1, 8, 240.11), (2, 32, 245.60), (2, 33, 251.48), (2, 34, 257.44), (2, 35, 263.34),
    (1, 9, 270.00), (2, 36, 276.27), (2, 37, 282.15), (2, 38, 288.10), (2, 39, 293.97),
    (1, 10, 300.19), (2, 40, 306.15), (2, 41, 312.05), (2, 42, 318.00), (2, 43, 323.89),
    (1, 11, 330.23), (2, 44, 336.54), (2, 45, 342.43), (2, 46, 348.39), (2, 47, 354.27),
]


def _nearest_ring_pos(target_deg: float) -> Tuple[int, int]:
    best = (RING[0][0], RING[0][1])
    best_d = 360.0
    for stripe, idx, a in RING:
        d = abs(target_deg - a) % 360
        d = min(d, 360 - d)
        if d < best_d:
            best_d = d
            best = (stripe, idx)
    return best

# Sektion i von Stripe 1 entspricht Ziffernblatt-Position i direkt (Sektion 0
# liegt bei "12 Uhr", die Sektionen laufen im Uhrzeigersinn ums Blatt).
POINTER_TOTAL = 48  # LEDs auf Stripe 2 (12 Grüppchen à 4)


def stripe1_frame(
    hour12: int,
    minute: int,
    section_specs: List[SectionSpec],
    ring_overlays: dict[int, Pixel] | None = None,
) -> List[Pixel]:
    hour_section = hour12 % 12
    minute_section = round(minute / 5) % 12
    ring_overlays = ring_overlays or {}
    pixels: List[Pixel] = []
    tip_index: dict[int, int] = {}  # Sektionsindex -> globaler Pixel-Index der äußersten LED
    offset = 0
    for i, (n, inner_first) in enumerate(section_specs):
        is_hour = i == hour_section
        is_minute = i == minute_section
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
            tip_index[i] = offset + n - 1
        else:
            pixels.extend(minute_block)
            pixels.extend(hour_block)
            tip_index[i] = offset
        offset += n
    for section_i, color in ring_overlays.items():
        pixels[tip_index[section_i]] = color
    return pixels


def stripe2_frame(total: int, ring_overlays: dict[int, Pixel] | None = None) -> List[Pixel]:
    # Kontur: alle sonst ungenutzten LEDs leicht grün.
    pixels = [FAINT_GREEN] * total
    for idx, color in (ring_overlays or {}).items():
        pixels[idx] = color
    return pixels


def main() -> None:
    parser = argparse.ArgumentParser(
        description="DDP-Client: zeigt eine analoge Uhr auf den watch2-Stripes an.",
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

    # Ohne --time/--speed-Overrides läuft die Uhr im echten Wanduhrzeit-Modus:
    # jeder Frame fragt datetime.now() direkt ab, statt eine Simulation ab
    # einem Startzeitpunkt fortzuschreiben. Grund: time.monotonic() zählt auf
    # macOS NICHT weiter, während der Rechner schläft (Deckel zu, Display-
    # Sleep) — die Wanduhrzeit aber schon. Eine auf monotonic() basierende
    # Simulation würde nach jeder Schlafphase entsprechend hinterherhängen.
    simulate = args.time is not None or args.speed != 1.0
    if simulate:
        if args.time:
            t0 = datetime.strptime(args.time, "%H:%M:%S")
            sim_start_seconds = t0.hour * 3600 + t0.minute * 60 + t0.second
        else:
            now = datetime.now()
            sim_start_seconds = now.hour * 3600 + now.minute * 60 + now.second

    print(f"Ziel: {args.host}:{args.port}")
    print(
        f"Stripe 1: {sum(n for n, _ in SECTION_SPECS)} LEDs in {len(SECTION_SPECS)} Sektionen "
        f"(Stunde blau innen)  |  Stripe 2: {POINTER_TOTAL} LEDs, "
        f"+ 12 Speichenspitzen = {len(RING)}er-Ring (Sekunde gelb, Minute rot)"
    )
    print("Strg+C zum Beenden.")

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    addr = (args.host, args.port)
    frame_interval = 1.0 / args.fps if args.fps > 0 else 0
    start = time.monotonic()
    try:
        while args.duration is None or time.monotonic() - start < args.duration:
            frame_start = time.monotonic()
            if simulate:
                elapsed_sim = (frame_start - start) * args.speed
                total_seconds = int(sim_start_seconds + elapsed_sim) % 86400
                hour = (total_seconds // 3600) % 12
                minute = (total_seconds // 60) % 60
                second = total_seconds % 60
            else:
                now = datetime.now()
                hour = now.hour % 12
                minute = now.minute
                second = now.second

            # Minute/Sekunde als Position auf dem kombinierten 60er-Ring
            # (Stripe 2 + Speichenspitzen von Stripe 1) — Reihenfolge =
            # Priorität bei Überlagerung: Sekunde nach Minute überschreibt.
            s1_overlays: dict[int, Pixel] = {}
            s2_overlays: dict[int, Pixel] = {}
            for target_deg, color in (
                (minute / 60 * 360, RED),
                (second / 60 * 360, YELLOW),
            ):
                stripe, idx = _nearest_ring_pos(target_deg)
                (s1_overlays if stripe == 1 else s2_overlays)[idx] = color

            send_ddp_frame(
                sock,
                addr,
                STRIPE1_DEST,
                stripe1_frame(hour, minute, SECTION_SPECS, s1_overlays),
            )
            send_ddp_frame(
                sock,
                addr,
                STRIPE2_DEST,
                stripe2_frame(POINTER_TOTAL, s2_overlays),
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
