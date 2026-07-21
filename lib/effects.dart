import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'model.dart';

/// Liefert die Farbe der LED [index] eines Abschnitts [sec] mit [count]
/// LEDs (lokaler Index/Anzahl innerhalb des Abschnitts) zum Zeitpunkt [t]
/// (Sekunden). Effekt, Farbe(n), Helligkeit, Tempo und Richtung stammen
/// vollständig vom Abschnitt — jeder Abschnitt läuft damit unabhängig von
/// den anderen. Nur der Ein/Aus-Schalter kommt vom Stripe [s].
///
/// Die Berechnung ist rein deterministisch aus (Konfiguration, index, t),
/// damit die Simulation ohne Zustand pro LED auskommt.
Color ledColor(LedStrip s, StripSection sec, int count, int index, double t) {
  if (!s.enabled || count <= 0) return const Color(0x00000000);
  final n = count;
  final i = sec.reversed ? n - 1 - index : index;
  final pos = n == 1 ? 0.0 : i / (n - 1); // 0..1 entlang des Abschnitts
  // Geschwindigkeit nichtlinear mappen, damit der Regler feinfühlig ist.
  final speed = 0.05 + sec.speed * sec.speed * 4.0;
  final seedHash = sec.hashCode;

  Color c;
  switch (sec.effect) {
    case EffectType.solid:
      c = sec.color;
    case EffectType.gradient:
      c = Color.lerp(sec.color, sec.color2, pos)!;
    case EffectType.rainbow:
      final hue = ((pos * 1.5 - t * speed * 0.25) % 1.0 + 1.0) % 1.0;
      c = HSVColor.fromAHSV(1, hue * 360, 1, 1).toColor();
    case EffectType.chase:
      // Laufender Punkt mit Schweif.
      final head = (t * speed * 60) % n;
      var d = (i - head) % n;
      if (d > 0) d -= n; // Schweif liegt hinter dem Kopf
      final tail = math.max(4.0, n * 0.12);
      final v = d <= 0 && -d < tail
          ? math.pow(1 + d / tail, 2).toDouble()
          : 0.0;
      c = _scale(sec.color, 0.03 + 0.97 * v);
    case EffectType.theater:
      final phase = (t * speed * 8).floor() % 3;
      c = (i % 3 == phase) ? sec.color : _scale(sec.color, 0.04);
    case EffectType.breathe:
      final v = 0.5 - 0.5 * math.cos(t * speed * 2 * math.pi * 0.5);
      c = Color.lerp(_scale(sec.color, 0.05), sec.color, v)!;
    case EffectType.sparkle:
      final frame = (t * (2 + speed * 20)).floor();
      final h = _hash(i * 7919 + frame * 104729 + seedHash);
      final v = h < 0.08 ? 1.0 : 0.12;
      c = _scale(sec.color, v);
    case EffectType.scanner:
      // Punkt pendelt hin und her, mit weichem Leuchtkegel.
      if (n < 2) {
        c = sec.color;
      } else {
        final u = (t * speed * 30) % (2.0 * (n - 1));
        final head = u < n - 1 ? u : 2.0 * (n - 1) - u;
        final sigma = math.max(1.2, n * 0.02);
        final v = math.exp(-math.pow(i - head, 2) / (2 * sigma * sigma));
        c = _scale(sec.color, 0.03 + 0.97 * v);
      }
    case EffectType.colorWipe:
      // Farbe 1 füllt den Stripe, dann wischt Farbe 2 darüber, im Wechsel.
      final prog = (t * speed * 60) % (2.0 * n);
      final p = prog % n;
      final firstHalf = prog < n;
      c = i < p == firstHalf ? sec.color : sec.color2;
    case EffectType.wave:
      // Laufende Sinuswelle zwischen den beiden Farben.
      final v = 0.5 + 0.5 * math.sin(2 * math.pi * (pos * 3 - t * speed * 1.5));
      c = Color.lerp(sec.color2, sec.color, v)!;
    case EffectType.blink:
      final phase = (t * (0.5 + speed * 4)).floor();
      c = phase.isEven ? sec.color : sec.color2;
    case EffectType.strobe:
      final period = 1.0 / (1 + speed * 9);
      c = (t % period) < period * 0.15 ? sec.color : _scale(sec.color, 0.02);
    case EffectType.confetti:
      // Zufällige Pixel leuchten in Zufallsfarben auf und verblassen.
      final rate = 1 + speed * 4;
      final g = (t * rate).floor();
      final frac = t * rate - g;
      final h = _hash(i * 6151 + g * 104729 + seedHash);
      if (h < 0.12) {
        final hue = _hash(i * 3079 + g * 92821) * 360;
        c = HSVColor.fromAHSV(1, hue, 1, 1 - frac).toColor();
      } else {
        c = const Color(0xFF000000);
      }
    case EffectType.fire:
      // Flackernde Hitze, zur Stripe-Spitze hin kühler (feste Feuerpalette).
      final f = t * (4 + speed * 12);
      final f0 = f.floor();
      final n1 = _hash(i * 4813 + f0 * 76801 + seedHash);
      final n2 = _hash(i * 4813 + (f0 + 1) * 76801 + seedHash);
      final flicker = n1 + (n2 - n1) * (f - f0);
      final heat = ((1.1 - pos * 0.7) * (0.35 + 0.65 * flicker)).clamp(
        0.0,
        1.0,
      );
      c = _heatColor(heat);
  }
  return _scale(c, sec.brightness);
}

/// Feuerpalette: schwarz → rot → orange → gelb/weiß.
Color _heatColor(double h) {
  final v = h.clamp(0.0, 1.0);
  if (v < 0.4) {
    return Color.from(alpha: 1, red: v / 0.4, green: 0, blue: 0);
  }
  if (v < 0.8) {
    return Color.from(alpha: 1, red: 1, green: (v - 0.4) / 0.4 * 0.65, blue: 0);
  }
  final w = (v - 0.8) / 0.2;
  return Color.from(alpha: 1, red: 1, green: 0.65 + 0.35 * w, blue: 0.6 * w);
}

Color _scale(Color c, double f) {
  final v = f.clamp(0.0, 1.0);
  return Color.from(alpha: c.a, red: c.r * v, green: c.g * v, blue: c.b * v);
}

/// Deterministischer Pseudozufall in [0,1).
double _hash(int x) {
  var h = x;
  h = ((h >> 16) ^ h) * 0x45d9f3b;
  h = ((h >> 16) ^ h) * 0x45d9f3b;
  h = (h >> 16) ^ h;
  return (h & 0xFFFF) / 0x10000;
}
