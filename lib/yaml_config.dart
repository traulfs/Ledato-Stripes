import 'package:flutter/painting.dart';
import 'package:yaml/yaml.dart';

import 'app_state.dart';
import 'model.dart';

/// Erzeugt eine lesbare, von Hand editierbare YAML-Konfiguration.
///
/// Bewusst kein generischer YAML-Writer: Das Schema ist klein und fest
/// (globale Einstellungen + Liste von Stripes mit Punktepaaren), ein
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
        ..writeln('    ledCount: ${s.ledCount}')
        ..writeln('    curved: ${s.curved}')
        ..writeln('    reversed: ${s.reversed}')
        ..writeln('    effect: ${s.effect.name}')
        ..writeln('    color: ${_hex(s.color)}')
        ..writeln('    color2: ${_hex(s.color2)}')
        ..writeln('    brightness: ${_num(s.brightness)}')
        ..writeln('    speed: ${_num(s.speed)}')
        ..writeln('    points:');
      for (final p in s.points) {
        buf.writeln('      - [${_num(p.dx)}, ${_num(p.dy)}]');
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
        'Ungültige YAML-Konfiguration: kein Objekt auf oberster Ebene.');
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
  final points = <Offset>[];
  final rawPoints = m['points'];
  if (rawPoints is YamlList) {
    for (final p in rawPoints) {
      if (p is YamlList && p.length >= 2) {
        final x = p[0], y = p[1];
        if (x is num && y is num) {
          points.add(Offset(x.toDouble(), y.toDouble()));
        }
      }
    }
  }
  if (points.length < 2) {
    points
      ..clear()
      ..addAll(const [Offset(0.1, 0.5), Offset(0.9, 0.5)]);
  }

  return LedStrip(
    id: (m['id'] ?? DateTime.now().microsecondsSinceEpoch.toString())
        .toString(),
    name: (m['name'] ?? 'Stripe').toString(),
    ledsPerMeter: _intField(m['ledsPerMeter'], 60),
    ledCount: _intField(m['ledCount'], 60).clamp(1, kMaxLedsPerStrip),
    points: points,
    effect:
        EffectType.values.asNameMap()[m['effect']?.toString()] ?? EffectType.solid,
    color: _colorField(m['color'], const Color(0xFFFF6000)),
    color2: _colorField(m['color2'], const Color(0xFF0040FF)),
    brightness: _numField(m['brightness'], 1.0),
    speed: _numField(m['speed'], 0.5),
    reversed: m['reversed'] == true,
    enabled: m['enabled'] != false,
    curved: m['curved'] == true,
  );
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

String _hex(Color c) => '"#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}"';

// ---------- Parsen ----------

double _numField(dynamic v, double fallback) => v is num ? v.toDouble() : fallback;

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
