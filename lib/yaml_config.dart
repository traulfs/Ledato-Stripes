import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:yaml/yaml.dart';

import 'app_state.dart';
import 'model.dart';

/// Erzeugt eine lesbare, von Hand editierbare YAML-Konfiguration.
///
/// Bewusst kein generischer YAML-Writer: Das Schema ist klein und fest
/// (globale Einstellungen + Liste von Stripes mit ihren Abschnitten), ein
/// direkt geschriebener Text ist hier einfacher als eine generische
/// Map/List-Serialisierung und garantiert stabile Formatierung.
String encodeConfigYaml(AppState st) {
  final buf = StringBuffer()
    ..writeln('# Ledato Stripes Konfiguration')
    ..writeln('sceneWidthMeters: ${_num(st.sceneWidthMeters)}')
    ..writeln('backgroundPath: ${_str(st.backgroundPath)}')
    ..writeln('backgroundDim: ${_num(st.backgroundDim)}')
    ..writeln('ledSize: ${_num(st.ledSize)}')
    ..writeln('glow: ${_num(st.glow)}');

  if (st.strips.isEmpty) {
    buf.writeln('strips: []');
  } else {
    buf.writeln('strips:');
    for (final s in st.strips) {
      buf
        ..writeln('  - id: ${_str(s.id)}')
        ..writeln('    name: ${_str(s.name)}')
        ..writeln('    enabled: ${s.enabled}')
        ..writeln('    ledsPerMeter: ${s.ledsPerMeter}')
        ..writeln('    sections:');
      for (final sec in s.sections) {
        buf
          ..writeln(
            '      - start: [${_num(sec.start.dx)}, ${_num(sec.start.dy)}]',
          )
          ..writeln('        angleDegrees: ${_num(sec.angle * 180 / math.pi)}')
          ..writeln('        ledCount: ${sec.ledCount}')
          ..writeln('        effect: ${sec.effect.name}')
          ..writeln('        color: ${_hex(sec.color)}')
          ..writeln('        color2: ${_hex(sec.color2)}')
          ..writeln('        brightness: ${_num(sec.brightness)}')
          ..writeln('        speed: ${_num(sec.speed)}')
          ..writeln('        reversed: ${sec.reversed}');
      }
    }
  }
  return buf.toString();
}

/// Liest eine YAML-Konfiguration und überträgt sie auf [st] (Stripes und
/// globale Einstellungen, ohne das Hintergrundbild selbst zu laden).
/// Gibt den gespeicherten Bildpfad zurück, damit der Aufrufer das Bild
/// asynchron nachladen kann.
String? applyConfigYaml(AppState st, String text) {
  final doc = loadYaml(text);
  if (doc is! YamlMap) {
    throw const FormatException(
      'Ungültige YAML-Konfiguration: kein Objekt auf oberster Ebene.',
    );
  }

  st.sceneWidthMeters = _numField(doc['sceneWidthMeters'], 5.0);
  st.backgroundDim = _numField(doc['backgroundDim'], 0.5);
  st.ledSize = _numField(doc['ledSize'], 6.0);
  st.glow = _numField(doc['glow'], 1.0);

  final strips = <LedStrip>[];
  final rawStrips = doc['strips'];
  if (rawStrips is YamlList) {
    for (final item in rawStrips) {
      if (item is YamlMap) strips.add(_stripFromYaml(item));
    }
  }
  st.strips
    ..clear()
    ..addAll(strips.take(kMaxStrips));

  final path = doc['backgroundPath'];
  return path is String ? path : null;
}

LedStrip _stripFromYaml(YamlMap m) {
  // Vor Einführung der abschnittsweisen Optik lagen Effekt/Farbe(n)/
  // Helligkeit/Tempo/Richtung auf Strip-Ebene — dient als Fallback, falls
  // ein Abschnitt keine eigenen Werte mitbringt.
  final legacy = _LegacyStripLook(
    effect:
        EffectType.values.asNameMap()[m['effect']?.toString()] ??
        EffectType.solid,
    color: _colorField(m['color'], const Color(0xFFFF6000)),
    color2: _colorField(m['color2'], const Color(0xFF0040FF)),
    brightness: _numField(m['brightness'], 1.0),
    speed: _numField(m['speed'], 0.5),
    reversed: m['reversed'] == true,
  );

  final sections = <StripSection>[];
  final rawSections = m['sections'];
  if (rawSections is YamlList) {
    for (final item in rawSections) {
      if (item is YamlMap) {
        final sec = _sectionFromYaml(item, legacy);
        if (sec != null) sections.add(sec);
      }
    }
  } else {
    // Ganz altes Format (vor Einführung mehrerer Abschnitte): Punkte/LED-
    // Anzahl/Optik lagen direkt auf Strip-Ebene.
    final pts = _pointsFromYaml(m['points']);
    if (pts.isNotEmpty) {
      sections.add(
        StripSection(
          start: pts.first,
          angle: _angleFromPoints(pts),
          ledCount: _intField(m['ledCount'], 60).clamp(1, kMaxLedsPerStrip),
          effect: legacy.effect,
          color: legacy.color,
          color2: legacy.color2,
          brightness: legacy.brightness,
          speed: legacy.speed,
          reversed: legacy.reversed,
        ),
      );
    }
  }
  if (sections.isEmpty) {
    sections.add(StripSection(start: const Offset(0.1, 0.5)));
  }

  return LedStrip(
    id: (m['id'] ?? DateTime.now().microsecondsSinceEpoch.toString())
        .toString(),
    name: (m['name'] ?? 'Stripe').toString(),
    ledsPerMeter: _intField(m['ledsPerMeter'], 60),
    sections: sections,
    enabled: m['enabled'] != false,
  );
}

/// Optik-Bündel des alten, stripeweiten Formats — nur für die Migration.
class _LegacyStripLook {
  _LegacyStripLook({
    required this.effect,
    required this.color,
    required this.color2,
    required this.brightness,
    required this.speed,
    required this.reversed,
  });

  final EffectType effect;
  final Color color;
  final Color color2;
  final double brightness;
  final double speed;
  final bool reversed;
}

StripSection? _sectionFromYaml(YamlMap item, _LegacyStripLook legacy) {
  final effect =
      EffectType.values.asNameMap()[item['effect']?.toString()] ??
      legacy.effect;
  final ledCount = _intField(item['ledCount'], 60).clamp(1, kMaxLedsPerStrip);
  final color = item.containsKey('color')
      ? _colorField(item['color'], legacy.color)
      : legacy.color;
  final color2 = item.containsKey('color2')
      ? _colorField(item['color2'], legacy.color2)
      : legacy.color2;
  final brightness = item.containsKey('brightness')
      ? _numField(item['brightness'], legacy.brightness)
      : legacy.brightness;
  final speed = item.containsKey('speed')
      ? _numField(item['speed'], legacy.speed)
      : legacy.speed;
  final reversed = item.containsKey('reversed')
      ? item['reversed'] == true
      : legacy.reversed;

  final rawStart = item['start'];
  if (rawStart is YamlList && rawStart.length >= 2) {
    final x = rawStart[0], y = rawStart[1];
    if (x is num && y is num) {
      final angleDeg = item['angleDegrees'];
      final angle = angleDeg is num ? angleDeg.toDouble() * math.pi / 180 : 0.0;
      return StripSection(
        start: Offset(x.toDouble(), y.toDouble()),
        angle: angle,
        ledCount: ledCount,
        effect: effect,
        color: color,
        color2: color2,
        brightness: brightness,
        speed: speed,
        reversed: reversed,
      );
    }
  }

  // Vorheriges Format (Polylinie mit mehreren Punkten statt Start+Winkel):
  // Anfangspunkt und grobe Richtung werden übernommen, die Kurvenform wird
  // dabei zu einer Geraden vereinfacht.
  final pts = _pointsFromYaml(item['points']);
  if (pts.isNotEmpty) {
    return StripSection(
      start: pts.first,
      angle: _angleFromPoints(pts),
      ledCount: ledCount,
      effect: effect,
      color: color,
      color2: color2,
      brightness: brightness,
      speed: speed,
      reversed: reversed,
    );
  }
  return null;
}

double _angleFromPoints(List<Offset> pts) {
  if (pts.length < 2) return 0.0;
  final d = pts.last - pts.first;
  return math.atan2(d.dy, d.dx);
}

List<Offset> _pointsFromYaml(dynamic raw) {
  final points = <Offset>[];
  if (raw is YamlList) {
    for (final p in raw) {
      if (p is YamlList && p.length >= 2) {
        final x = p[0], y = p[1];
        if (x is num && y is num) {
          points.add(Offset(x.toDouble(), y.toDouble()));
        }
      }
    }
  }
  return points;
}

// ---------- Formatierung ----------

/// Zahl ohne unnötige Nachkommastellen, aber erkennbar als Dezimalzahl
/// (z. B. "1.0", "0.5", "2.3456").
String _num(double d) {
  var s = d.toStringAsFixed(4);
  s = s.replaceFirst(RegExp(r'0+$'), '');
  if (s.endsWith('.')) s += '0';
  return s;
}

String _str(String? s) {
  if (s == null) return 'null';
  final escaped = s.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
  return '"$escaped"';
}

String _hex(Color c) =>
    '"#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}"';

// ---------- Parsen ----------

double _numField(dynamic v, double fallback) =>
    v is num ? v.toDouble() : fallback;

int _intField(dynamic v, int fallback) => v is num ? v.toInt() : fallback;

Color _colorField(dynamic v, Color fallback) {
  if (v is String) {
    var h = v.trim();
    if (h.startsWith('#')) h = h.substring(1);
    final n = int.tryParse(h, radix: 16);
    if (n != null) return Color(h.length <= 6 ? (0xFF000000 | n) : n);
  }
  if (v is num) return Color(v.toInt());
  return fallback;
}
