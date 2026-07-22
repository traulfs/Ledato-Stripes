import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';

import 'ddp_server.dart';
import 'model.dart';
import 'yaml_config.dart';

/// Zentraler App-Zustand: Stripes, Hintergrundbild, globale Darstellung.
/// Änderungen werden verzögert automatisch als YAML-Datei gespeichert.
class AppState extends ChangeNotifier {
  final List<LedStrip> strips = [];
  String? selectedId;
  int selectedSectionIndex = 0;
  bool simulate =
      true; // true = Simulation läuft, false = Editiermodus-Standbild
  bool editMode = true; // Handles/Linien anzeigen und bearbeiten
  bool showLedGrid =
      false; // Ausrichtungsraster (60 LEDs/m) im Bearbeiten-Modus

  // ---------- DDP-Server ----------
  //
  // Ein UDP-Server (Standardport 4048) macht die 8 Stripes per DDP
  // (Distributed Display Protocol, z. B. von xLights oder WLED genutzt)
  // ansprechbar: die 1-Byte-Zieladresse eines Pakets (1..8) wählt den
  // Stripe anhand seiner Position in [strips]. Solange für einen Stripe
  // frische Pakete ankommen, überschreiben dessen Farben den internen
  // Effekt (siehe [ddpColorFor]); die Übersteuerung ist reine Anzeigesache
  // und läuft nicht über [changed()] (kein Undo-Schritt, keine Autospeicherung).

  /// Wie lange zuletzt empfangene DDP-Farben eines Stripes gültig bleiben,
  /// bevor ohne neue Pakete wieder der interne Effekt greift.
  static const Duration ddpStaleTimeout = Duration(seconds: 2);

  DdpServer? _ddpServer;
  int ddpPort = kDdpDefaultPort;
  final Map<String, _DdpOverride> _ddpOverrides = {};

  bool get ddpServerRunning => _ddpServer?.isRunning ?? false;

  Future<void> startDdpServer([int? port]) async {
    if (kIsWeb) return;
    _ddpServer ??= DdpServer(onFrame: _onDdpFrame);
    ddpPort = port ?? ddpPort;
    await _ddpServer!.start(port: ddpPort);
    notifyListeners();
  }

  Future<void> stopDdpServer() async {
    await _ddpServer?.stop();
    notifyListeners();
  }

  void _onDdpFrame(int destination, int pixelStart, List<Color> colors) {
    if (destination < 1 || destination > strips.length) return;
    final strip = strips[destination - 1];
    final ov = _ddpOverrides.putIfAbsent(
      strip.id,
      () => _DdpOverride(strip.ledCount),
    );
    if (ov.colors.length != strip.ledCount) {
      ov.colors = List<Color?>.filled(strip.ledCount, null);
    }
    for (var i = 0; i < colors.length; i++) {
      final idx = pixelStart + i;
      if (idx >= 0 && idx < ov.colors.length) ov.colors[idx] = colors[i];
    }
    ov.lastUpdate = DateTime.now();
    notifyListeners();
  }

  /// Per DDP empfangene Farbe für die LED [globalIndex] (fortlaufend über
  /// alle Abschnitte des Stripes) des Stripes [stripId], oder `null` falls
  /// keine (noch gültige) Übersteuerung vorliegt.
  Color? ddpColorFor(String stripId, int globalIndex) {
    final ov = _ddpOverrides[stripId];
    if (ov == null) return null;
    if (DateTime.now().difference(ov.lastUpdate) > ddpStaleTimeout) {
      return null;
    }
    if (globalIndex < 0 || globalIndex >= ov.colors.length) return null;
    return ov.colors[globalIndex];
  }

  ui.Image? background;
  String? backgroundPath;
  double backgroundDim = 0.5; // Abdunklung des Hintergrunds 0..1
  double ledSize = 6; // Basisgröße einer LED in Pixel
  double glow = 1.0; // Stärke des Leuchtscheins 0..2

  /// Metrischer Maßstab: reale Breite des Bildbereichs in Metern.
  double sceneWidthMeters = 5.0;

  /// Seitenverhältnis (Höhe/Breite) des Bildbereichs; wird von der Leinwand
  /// beim Layout gesetzt und für die Winkel-Umrechnung benötigt.
  double contentAspect = 1.0;

  /// Physischer Abstand zwischen erster und letzter LED eines Abschnitts:
  /// (LED-Anzahl − 1) ÷ Stripe-Dichte. So liegt der Endpunkt eines
  /// Abschnitts exakt auf der letzten LED (kein zusätzlicher halber Pitch
  /// als Rand).
  double sectionTargetLengthMeters(LedStrip s, StripSection sec) =>
      sec.ledCount > 1 ? (sec.ledCount - 1) / s.ledsPerMeter : 0.0;

  /// Physische Gesamtlänge des Stripes — Summe über alle Abschnitte.
  double targetLengthMeters(LedStrip s) => s.sections.fold(
    0.0,
    (sum, sec) => sum + sectionTargetLengthMeters(s, sec),
  );

  /// Endpunkt eines Abschnitts (normalisierte Bildkoordinate), berechnet aus
  /// Anfangspunkt, Winkel und Länge. Der Winkel wird im metergetreuen Raum
  /// interpretiert (nicht im rohen 0..1-Bildraum), damit er unabhängig vom
  /// Bildseitenverhältnis immer real gerade erscheint — Meter- und
  /// Bildschirm-Pixel-Raum sind über eine gleichförmige (winkeltreue)
  /// Skalierung verbunden, nur die Umrechnung von normalisierten Koordinaten
  /// in Meter hängt vom Seitenverhältnis ab.
  Offset sectionEnd(LedStrip s, StripSection sec) {
    final len = sectionTargetLengthMeters(s, sec);
    final dxMeters = len * math.cos(sec.angle);
    final dyMeters = len * math.sin(sec.angle);
    final ay = contentAspect > 1e-6 ? contentAspect : 1.0;
    return Offset(
      sec.start.dx + dxMeters / sceneWidthMeters,
      sec.start.dy + dyMeters / (sceneWidthMeters * ay),
    );
  }

  /// Setzt die LED-Anzahl eines Abschnitts; die Summe über alle Abschnitte
  /// des Stripes bleibt dabei auf [kMaxLedsPerStrip] begrenzt.
  void setSectionLedCount(LedStrip s, StripSection sec, int n) {
    final others = s.ledCount - sec.ledCount;
    final maxForThis = (kMaxLedsPerStrip - others).clamp(1, kMaxLedsPerStrip);
    sec.ledCount = n.clamp(1, maxForThis);
    changed();
  }

  Timer? _saveTimer;
  bool _loaded = false;

  LedStrip? get selected {
    for (final s in strips) {
      if (s.id == selectedId) return s;
    }
    return null;
  }

  /// Der gerade zur Bearbeitung ausgewählte Abschnitt des ausgewählten
  /// Stripes (Index wird auf die vorhandenen Abschnitte geklemmt).
  StripSection? get selectedSection {
    final s = selected;
    if (s == null || s.sections.isEmpty) return null;
    return s.sections[selectedSectionIndex.clamp(0, s.sections.length - 1)];
  }

  void select(String? id) {
    selectedId = id;
    selectedSectionIndex = 0;
    notifyListeners();
  }

  void selectSection(int index) {
    final s = selected;
    if (s == null || s.sections.isEmpty) return;
    selectedSectionIndex = index.clamp(0, s.sections.length - 1);
    notifyListeners();
  }

  LedStrip? addStrip() {
    if (strips.length >= kMaxStrips) return null;
    final n = strips.length + 1;
    final y = 0.15 + 0.1 * ((n - 1) % 8);
    final strip = LedStrip(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: 'Stripe $n',
      sections: [
        StripSection(
          start: Offset(0.1, y),
          color: _defaultColors[(n - 1) % _defaultColors.length],
        ),
      ],
    );
    strips.add(strip);
    selectedId = strip.id;
    selectedSectionIndex = 0;
    changed();
    return strip;
  }

  /// Fügt direkt nach dem gerade ausgewählten Abschnitt einen weiteren,
  /// unabhängig platzierbaren Abschnitt mit dessen Eigenschaften ein (Optik,
  /// LED-Anzahl, Winkel) — LEDs zählen nahtlos über die Abschnittsgrenze
  /// hinweg weiter, als wäre es ein durchgehendes Stück. Startet als gerade
  /// Fortsetzung am Ende des ausgewählten Abschnitts; die LED-Anzahl wird bei
  /// Bedarf auf das verbleibende Budget des Stripes (max. [kMaxLedsPerStrip]
  /// insgesamt) gekappt.
  void addSection(LedStrip s) {
    final remaining = kMaxLedsPerStrip - s.ledCount;
    if (remaining <= 0) return;
    if (s.sections.isEmpty) {
      s.sections.add(
        StripSection(
          start: const Offset(0.1, 0.5),
          ledCount: remaining < 60 ? remaining : 60,
          color: _defaultColors.first,
        ),
      );
      selectedSectionIndex = 0;
      changed();
      return;
    }
    final baseIdx = selectedSectionIndex.clamp(0, s.sections.length - 1);
    final base = s.sections[baseIdx];
    final start = sectionEnd(s, base);
    final section = base.clone()
      ..start = Offset(start.dx.clamp(0.02, 0.98), start.dy.clamp(0.02, 0.98))
      ..ledCount = math.min(base.ledCount, remaining);
    s.sections.insert(baseIdx + 1, section);
    selectedSectionIndex = baseIdx + 1;
    changed();
  }

  /// Entfernt einen Abschnitt (ein Stripe muss mindestens einen behalten).
  void removeSection(LedStrip s, int index) {
    if (s.sections.length <= 1 || index < 0 || index >= s.sections.length) {
      return;
    }
    s.sections.removeAt(index);
    if (selectedSectionIndex >= s.sections.length) {
      selectedSectionIndex = s.sections.length - 1;
    }
    changed();
  }

  void removeStrip(LedStrip s) {
    strips.remove(s);
    if (selectedId == s.id) {
      selectedId = null;
      selectedSectionIndex = 0;
    }
    changed();
  }

  // ---------- Undo / Redo ----------
  //
  // Statt vor jeder einzelnen Aktion explizit einen Schnappschuss zu ziehen,
  // wird der Stand vor dem *ersten* Aufruf von [changed()] einer zusammen-
  // hängenden Änderungsserie gemerkt und erst nach einer kurzen Ruhephase auf
  // den Undo-Stack gelegt. Dadurch wird z. B. ein ganzer Drag-Vorgang (der
  // pro Frame [changed()] aufruft) zu genau einem Undo-Schritt.

  final List<_Snapshot> _undoStack = [];
  final List<_Snapshot> _redoStack = [];
  _Snapshot? _pendingUndo;
  Timer? _undoCoalesceTimer;
  static const _maxUndoDepth = 50;

  bool get canUndo => _pendingUndo != null || _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  void _commitPendingUndo() {
    final pending = _pendingUndo;
    if (pending == null) return;
    _undoStack.add(pending);
    if (_undoStack.length > _maxUndoDepth) _undoStack.removeAt(0);
    _pendingUndo = null;
  }

  /// Undo/Redo lösen selbst keinen neuen Undo-Schritt aus und benachrichtigen
  /// direkt, statt über [changed()] zu laufen (das würde den gerade erst
  /// befüllten Redo-Stack sofort wieder leeren).
  void undo() {
    _undoCoalesceTimer?.cancel();
    _commitPendingUndo();
    if (_undoStack.isEmpty) return;
    _redoStack.add(_Snapshot(this));
    _undoStack.removeLast().restoreTo(this);
    notifyListeners();
    _scheduleSave();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_Snapshot(this));
    _redoStack.removeLast().restoreTo(this);
    notifyListeners();
    _scheduleSave();
  }

  /// Nach jeder Mutation aufrufen: benachrichtigt die UI, merkt den Zustand
  /// für Undo vor und speichert verzögert.
  void changed() {
    notifyListeners();
    if (_loaded) {
      _pendingUndo ??= _Snapshot(this);
      _redoStack.clear();
      _undoCoalesceTimer?.cancel();
      _undoCoalesceTimer = Timer(
        const Duration(milliseconds: 600),
        _commitPendingUndo,
      );
    }
    _scheduleSave();
  }

  void _scheduleSave() {
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
    final data =
        jsonDecode(await legacy.readAsString()) as Map<String, dynamic>;
    strips
      ..clear()
      ..addAll(
        (data['strips'] as List)
            .map((e) => LedStrip.fromJson(e as Map<String, dynamic>))
            .take(kMaxStrips),
      );
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

  @override
  void dispose() {
    _saveTimer?.cancel();
    _undoCoalesceTimer?.cancel();
    _ddpServer?.stop();
    super.dispose();
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

/// Per DDP empfangene Farben eines Stripes (ein Eintrag je LED, `null` wo
/// noch keine Daten angekommen sind) plus Zeitpunkt des letzten Pakets, um
/// die Übersteuerung nach [AppState.ddpStaleTimeout] verfallen zu lassen.
class _DdpOverride {
  _DdpOverride(int ledCount)
    : colors = List<Color?>.filled(ledCount, null),
      lastUpdate = DateTime.now();

  List<Color?> colors;
  DateTime lastUpdate;
}

/// Schnappschuss des editierbaren Zustands für Undo/Redo. Das Hintergrundbild
/// selbst gehört bewusst nicht dazu (seltene, gezielte Aktion statt Editier-
/// schritt) — Undo betrifft Stripes (inkl. Abschnitte), Auswahl und die
/// globale Darstellung.
class _Snapshot {
  _Snapshot(AppState s)
    : strips = [for (final strip in s.strips) strip.clone()],
      selectedId = s.selectedId,
      selectedSectionIndex = s.selectedSectionIndex,
      sceneWidthMeters = s.sceneWidthMeters,
      backgroundDim = s.backgroundDim,
      ledSize = s.ledSize,
      glow = s.glow;

  final List<LedStrip> strips;
  final String? selectedId;
  final int selectedSectionIndex;
  final double sceneWidthMeters;
  final double backgroundDim;
  final double ledSize;
  final double glow;

  void restoreTo(AppState s) {
    s.strips
      ..clear()
      ..addAll([for (final strip in strips) strip.clone()]);
    s.selectedId = s.strips.any((e) => e.id == selectedId) ? selectedId : null;
    s.selectedSectionIndex = selectedSectionIndex;
    s.sceneWidthMeters = sceneWidthMeters;
    s.backgroundDim = backgroundDim;
    s.ledSize = ledSize;
    s.glow = glow;
  }
}
