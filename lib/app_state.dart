import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';

import 'geometry.dart';
import 'model.dart';
import 'yaml_config.dart';

/// Zentraler App-Zustand: Stripes, Hintergrundbild, globale Darstellung.
/// Änderungen werden verzögert automatisch als YAML-Datei gespeichert.
class AppState extends ChangeNotifier {
  final List<LedStrip> strips = [];
  String? selectedId;
  bool simulate = true; // true = Simulation läuft, false = Editiermodus-Standbild
  bool editMode = true; // Handles/Polylinien anzeigen und bearbeiten

  ui.Image? background;
  String? backgroundPath;
  double backgroundDim = 0.5; // Abdunklung des Hintergrunds 0..1
  double ledSize = 6; // Basisgröße einer LED in Pixel
  double glow = 1.0; // Stärke des Leuchtscheins 0..2

  /// Metrischer Maßstab: reale Breite des Bildbereichs in Metern.
  double sceneWidthMeters = 5.0;

  /// Seitenverhältnis (Höhe/Breite) des Bildbereichs; wird von der Leinwand
  /// beim Layout gesetzt und für Längenberechnungen benötigt.
  double contentAspect = 1.0;

  /// Stützpunkte eines Stripes in Metern.
  List<Offset> meterPoints(LedStrip s) => [
        for (final p in s.points)
          Offset(p.dx * sceneWidthMeters,
              p.dy * sceneWidthMeters * contentAspect),
      ];

  /// Physische Länge des Stripes in Metern (entlang der ggf. gebogenen Form).
  double stripLengthMeters(LedStrip s) {
    var total = 0.0;
    for (final seg in sampledSegments(meterPoints(s), s.curved)) {
      for (var i = 0; i < seg.length - 1; i++) {
        total += (seg[i + 1] - seg[i]).distance;
      }
    }
    return total;
  }

  /// Physische Länge des Stripes: Anzahl LEDs ÷ Dichte.
  double targetLengthMeters(LedStrip s) => s.ledCount / s.ledsPerMeter;

  /// Skaliert die gezeichnete Form um ihren Mittelpunkt so, dass ihre
  /// Bogenlänge exakt der physischen Stripe-Länge entspricht — der Stripe
  /// verhält sich wie ein Band fester Länge, das man nur biegt, und bleibt
  /// dabei an Ort und Stelle.
  void normalizeStripLength(LedStrip s) {
    final target = targetLengthMeters(s);
    final current = stripLengthMeters(s);
    if (s.points.length < 2 || current < 1e-6) {
      final start = s.points.isEmpty ? const Offset(0.1, 0.5) : s.points.first;
      s.points = [start, start + Offset(target / sceneWidthMeters, 0)];
      return;
    }
    final k = target / current;
    if ((k - 1).abs() < 1e-4) return;
    final c = _bbox(s.points).center;
    s.points = [for (final p in s.points) c + (p - c) * k];
  }

  static Rect _bbox(List<Offset> pts) {
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (final p in pts) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Verschiebt die Form (ohne sie zu verzerren) möglichst in den Bildbereich;
  /// ist sie größer als das Bild, wird sie zentriert.
  void _shiftIntoView(LedStrip s) {
    final b = _bbox(s.points);
    double shift(double min, double max) {
      const m = 0.02;
      if (max - min > 1 - 2 * m) return 0.5 - (min + max) / 2;
      if (min < m) return m - min;
      if (max > 1 - m) return (1 - m) - max;
      return 0;
    }

    final d = Offset(shift(b.left, b.right), shift(b.top, b.bottom));
    if (d != Offset.zero) {
      s.points = [for (final p in s.points) p + d];
    }
  }

  void normalizeAllStrips() {
    for (final s in strips) {
      normalizeStripLength(s);
    }
  }

  Timer? _saveTimer;
  bool _loaded = false;

  LedStrip? get selected {
    for (final s in strips) {
      if (s.id == selectedId) return s;
    }
    return null;
  }

  void select(String? id) {
    selectedId = id;
    notifyListeners();
  }

  LedStrip? addStrip() {
    if (strips.length >= kMaxStrips) return null;
    final n = strips.length + 1;
    final y = 0.15 + 0.1 * ((n - 1) % 8);
    final strip = LedStrip(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: 'Stripe $n',
      points: [Offset(0.1, y), Offset(0.9, y)],
      color: _defaultColors[(n - 1) % _defaultColors.length],
    );
    strips.add(strip);
    selectedId = strip.id;
    normalizeStripLength(strip);
    changed();
    return strip;
  }

  /// Ersetzt die Stützpunkte des Stripes durch eine Form-Vorlage,
  /// zentriert auf der bisherigen Position des Stripes. Die Vorlage wird
  /// über [contentAspect] entzerrt, damit z. B. ein Kreis auch auf einem
  /// breiten Bild rund ist, und anschließend auf die Stripe-Länge skaliert.
  void applyShapeTemplate(LedStrip s, StripShape shape) {
    final c = s.points.isEmpty ? const Offset(0.5, 0.5) : _bbox(s.points).center;

    List<Offset> rel;
    var curved = false;
    switch (shape) {
      case StripShape.line:
        rel = const [Offset(-0.35, 0), Offset(0.35, 0)];
      case StripShape.rect:
        rel = const [
          Offset(-0.28, -0.18),
          Offset(0.28, -0.18),
          Offset(0.28, 0.18),
          Offset(-0.28, 0.18),
          Offset(-0.28, -0.18),
        ];
      case StripShape.circle:
        const r = 0.22;
        rel = [
          for (var k = 0; k <= 8; k++)
            Offset(r * math.cos(k * math.pi / 4), r * math.sin(k * math.pi / 4)),
        ];
        curved = true;
      case StripShape.zigzag:
        const x = 0.3;
        const rows = [-0.18, -0.06, 0.06, 0.18];
        rel = [
          for (var k = 0; k < rows.length; k++) ...[
            Offset(k.isEven ? -x : x, rows[k]),
            Offset(k.isEven ? x : -x, rows[k]),
          ],
        ];
    }

    // y-Offsets entzerren, damit die Form auf dem Bild unverzerrt erscheint.
    final ay = contentAspect > 1e-6 ? 1 / contentAspect : 1.0;
    s.points = [
      for (final p in rel) Offset(c.dx + p.dx, c.dy + p.dy * ay),
    ];
    s.curved = curved;
    normalizeStripLength(s);
    _shiftIntoView(s);
    changed();
  }

  void removeStrip(LedStrip s) {
    strips.remove(s);
    if (selectedId == s.id) selectedId = null;
    changed();
  }

  /// Nach jeder Mutation aufrufen: benachrichtigt die UI und speichert verzögert.
  void changed() {
    notifyListeners();
    if (!_loaded || kIsWeb) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), save);
  }

  Future<void> setBackgroundBytes(Uint8List bytes, String? path) async {
    background = await decodeImageFromList(bytes);
    backgroundPath = path;
    changed();
  }

  void clearBackground() {
    background = null;
    backgroundPath = null;
    changed();
  }

  // ---------- Persistenz ----------

  Future<File> _configFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/ledato_stripes_config.yaml');
  }

  Future<File> _legacyJsonFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/ledato_stripes_config.json');
  }

  Future<void> save() async {
    if (kIsWeb) return;
    final file = await _configFile();
    await file.writeAsString(encodeConfigYaml(this));
  }

  Future<void> load() async {
    try {
      if (!kIsWeb) {
        var file = await _configFile();
        if (!await file.exists()) {
          await _migrateLegacyJsonIfPresent();
          file = await _configFile();
        }
        if (await file.exists()) {
          await _loadFromYamlFile(file);
        }
      }
    } catch (e) {
      debugPrint('Konfiguration konnte nicht geladen werden: $e');
    }
    if (strips.isEmpty) addStrip();
    _loaded = true;
    notifyListeners();
  }

  Future<void> _loadFromYamlFile(File file) async {
    final path = applyConfigYaml(this, await file.readAsString());
    if (path != null && await File(path).exists()) {
      await setBackgroundBytes(await File(path).readAsBytes(), path);
    }
  }

  /// Liest eine Konfiguration im alten JSON-Format einmalig ein und
  /// speichert sie sofort im neuen YAML-Format weiter, damit bestehende
  /// Konfigurationen den Formatwechsel überstehen.
  Future<void> _migrateLegacyJsonIfPresent() async {
    final legacy = await _legacyJsonFile();
    if (!await legacy.exists()) return;
    final data = jsonDecode(await legacy.readAsString()) as Map<String, dynamic>;
    strips
      ..clear()
      ..addAll((data['strips'] as List)
          .map((e) => LedStrip.fromJson(e as Map<String, dynamic>))
          .take(kMaxStrips));
    backgroundDim = (data['backgroundDim'] as num?)?.toDouble() ?? 0.5;
    ledSize = (data['ledSize'] as num?)?.toDouble() ?? 6;
    glow = (data['glow'] as num?)?.toDouble() ?? 1.0;
    sceneWidthMeters = (data['sceneWidthMeters'] as num?)?.toDouble() ?? 5.0;
    final path = data['backgroundPath'] as String?;
    if (path != null && await File(path).exists()) {
      await setBackgroundBytes(await File(path).readAsBytes(), path);
    }
    final file = await _configFile();
    await file.writeAsString(encodeConfigYaml(this));
  }

  // ---------- Export / Import (YAML-Datei nach Wahl des Nutzers) ----------

  String exportYamlText() => encodeConfigYaml(this);

  Future<void> importYamlText(String text) async {
    final path = applyConfigYaml(this, text);
    background = null;
    backgroundPath = null;
    if (path != null && await File(path).exists()) {
      await setBackgroundBytes(await File(path).readAsBytes(), path);
    } else {
      changed();
    }
  }

  static const _defaultColors = [
    Color(0xFFFF6000),
    Color(0xFF00C8FF),
    Color(0xFF40FF40),
    Color(0xFFFF2080),
    Color(0xFFFFD000),
    Color(0xFF8040FF),
    Color(0xFFFF4020),
    Color(0xFF00FFB0),
  ];
}
