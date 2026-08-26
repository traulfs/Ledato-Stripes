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
import 'proto_mapper.dart';
import 'protobuf/ledato_stripes.pb.dart' as pb;
import 'yaml_config.dart';

/// Zentraler App-Zustand: Pages (vollständige Lichtszenen) samt Player, der
/// zwischen ihnen umschaltet. Änderungen werden verzögert automatisch als
/// Protobuf-Datei gespeichert.
/// Ein Abschnitt in der Mehrfachauswahl: Stripe-ID + Abschnitt-Index. Ein
/// ganzer ausgewählter Stripe ist einfach die Menge aller seiner Indizes,
/// dafür gibt es keinen eigenen Fall.
typedef SelectionKey = (String stripId, int sectionIndex);

class AppState extends ChangeNotifier {
  /// Alle Lichtszenen (Pages) und die Page, die gerade bearbeitet/angezeigt
  /// wird. Sämtliche bisherigen Einzelfelder für „die“ Szene (Stripes,
  /// Maßstab, Hintergrund, …) sind jetzt Getter/Setter, die auf
  /// [activePage] delegieren — Canvas, Panel, DDP-Server etc. merken davon
  /// nichts und brauchen keine Änderung.
  List<LedPage> pages = [
    LedPage(id: DateTime.now().microsecondsSinceEpoch.toString(), name: 'Page 1'),
  ];
  int activePageIndex = 0;

  LedPage get activePage => pages[activePageIndex.clamp(0, pages.length - 1)];

  List<LedStrip> get strips => activePage.strips;

  String? get backgroundPath => activePage.backgroundPath;
  set backgroundPath(String? v) => activePage.backgroundPath = v;

  double get backgroundDim => activePage.backgroundDim;
  set backgroundDim(double v) => activePage.backgroundDim = v;

  double get glow => activePage.glow;
  set glow(double v) => activePage.glow = v;

  /// Metrischer Maßstab: reale Breite des Bildbereichs in Metern.
  double get sceneWidthMeters => activePage.sceneWidthMeters;
  set sceneWidthMeters(double v) => activePage.sceneWidthMeters = v;

  /// Seitenverhältnis (Höhe/Breite) des Bildbereichs, wenn es nicht aus dem
  /// Hintergrundbild übernommen wird (siehe [useImageAspect]).
  double get sceneAspect => activePage.sceneAspect;
  set sceneAspect(double v) => activePage.sceneAspect = v;

  /// Mit Hintergrundbild: ob das Seitenverhältnis aus dessen realen
  /// Pixelmaßen übernommen wird (true, Standard) oder stattdessen frei über
  /// [sceneAspect] eingestellt werden kann (false).
  bool get useImageAspect => activePage.useImageAspect;
  set useImageAspect(bool v) => activePage.useImageAspect = v;

  // ---------- Pages ----------

  /// Wählt eine andere Page als aktive Szene: leert Auswahl und den
  /// (bewusst pro Page geführten) Undo-Verlauf und lädt deren
  /// Hintergrundbild neu.
  Future<void> setActivePage(int index) async {
    if (pages.isEmpty) return;
    activePageIndex = index.clamp(0, pages.length - 1);
    pageElapsedMs = 0;
    selection.clear();
    selectedId = null;
    selectedSectionIndex = 0;
    _undoStack.clear();
    _redoStack.clear();
    _pendingUndo = null;
    _undoCoalesceTimer?.cancel();
    await _reloadActiveBackground();
    notifyListeners();
    _scheduleSave();
  }

  Future<void> _reloadActiveBackground() async {
    final path = activePage.backgroundPath;
    if (path == null) {
      background = null;
      return;
    }
    try {
      final file = File(path);
      background = await file.exists()
          ? await decodeImageFromList(await file.readAsBytes())
          : null;
    } catch (_) {
      background = null;
    }
  }

  LedPage _copyPage(LedPage src, String name) {
    final copy = src.clone();
    return LedPage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      durationMs: copy.durationMs,
      sceneWidthMeters: copy.sceneWidthMeters,
      sceneAspect: copy.sceneAspect,
      useImageAspect: copy.useImageAspect,
      backgroundPath: copy.backgroundPath,
      backgroundDim: copy.backgroundDim,
      glow: copy.glow,
      strips: copy.strips,
    );
  }

  /// Dupliziert die aktuell aktive Page als Vorlage für eine neue, hängt
  /// sie an und aktiviert sie.
  Future<LedPage> addPage() async {
    final page = _copyPage(activePage, 'Page ${pages.length + 1}');
    pages.add(page);
    await setActivePage(pages.length - 1);
    return page;
  }

  Future<void> duplicatePage(int index) async {
    if (index < 0 || index >= pages.length) return;
    final page = _copyPage(pages[index], '${pages[index].name} Kopie');
    pages.insert(index + 1, page);
    await setActivePage(index + 1);
  }

  /// Entfernt eine Page (mindestens eine muss erhalten bleiben).
  Future<void> removePage(int index) async {
    if (pages.length <= 1 || index < 0 || index >= pages.length) return;
    pages.removeAt(index);
    final newActive = activePageIndex > index
        ? activePageIndex - 1
        : activePageIndex;
    await setActivePage(newActive.clamp(0, pages.length - 1));
  }

  /// Verschiebt eine Page von [from] nach [to] (beide bereits die
  /// Ziel-Indizes nach dem Entfernen, wie z. B. `ReorderableListView`
  /// sie nach Anpassung des klassischen Off-by-one liefert).
  void reorderPage(int from, int to) {
    if (from < 0 ||
        from >= pages.length ||
        to < 0 ||
        to >= pages.length ||
        from == to) {
      return;
    }
    final page = pages.removeAt(from);
    pages.insert(to, page);
    if (activePageIndex == from) {
      activePageIndex = to;
    } else if (from < activePageIndex && to >= activePageIndex) {
      activePageIndex -= 1;
    } else if (from > activePageIndex && to <= activePageIndex) {
      activePageIndex += 1;
    }
    notifyListeners();
    _scheduleSave();
  }

  void renamePage(LedPage page, String name) {
    page.name = name;
    notifyListeners();
    _scheduleSave();
  }

  void setPageDuration(LedPage page, int ms) {
    page.durationMs = ms.clamp(200, 3600000);
    notifyListeners();
    _scheduleSave();
  }

  // ---------- Player ----------
  //
  // Schaltet Pages automatisch nach ihrer jeweiligen Anzeigedauer weiter.
  // Läuft über denselben Ticker, der schon die Effekt-Simulation treibt
  // (siehe EditorScreen in main.dart) — kein zusätzlicher Timer nötig.

  bool playing = false;
  double pageElapsedMs = 0;

  void togglePlaying() {
    playing = !playing;
    notifyListeners();
  }

  Future<void> nextPage() =>
      setActivePage((activePageIndex + 1) % pages.length);

  Future<void> prevPage() =>
      setActivePage((activePageIndex - 1 + pages.length) % pages.length);

  /// Von main.dart einmal pro Frame aufgerufen.
  void tickPlayer(double dtSeconds) {
    if (!playing || pages.length <= 1) return;
    pageElapsedMs += dtSeconds * 1000;
    if (pageElapsedMs >= activePage.durationMs) {
      pageElapsedMs = 0;
      nextPage();
    }
  }

  String? selectedId;
  int selectedSectionIndex = 0;

  /// Mehrfachauswahl für gemeinsames Verschieben/Optik-Bearbeiten. Enthält,
  /// solange nicht leer, immer auch das "primäre" Element
  /// ([selectedId]/[selectedSectionIndex]) — die beiden alten Felder bleiben
  /// bestehen und treiben weiterhin Dropdown, Rename-Dialog etc.; [selection]
  /// ist rein additiv dazu und wird nicht mit Undo/Speichern erfasst (siehe
  /// [toggleInSelection]).
  final Set<SelectionKey> selection = {};

  /// Symbolleisten-Umschalter: ist er aktiv, erweitert ein einfacher Klick/
  /// Tap die Auswahl statt sie zu ersetzen — Ersatz für die Umschalt-/Cmd-
  /// Taste auf Touch-Geräten ohne Zusatztasten.
  bool multiSelectMode = false;

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

  /// Eigener Notifier für empfangene DDP-Farben, getrennt von
  /// [notifyListeners] — DDP-Pakete kommen viel häufiger rein, als die
  /// restliche UI (App-Leiste, Seitenpanel, Drawer) neu gebaut werden muss.
  /// Nur die Leinwand hört darauf (siehe [EditorCanvas]), damit z. B. das
  /// Öffnen des Einstellungs-Drawers nicht durch jedes einzelne Paket
  /// ausgebremst wird.
  final ChangeNotifier ddpRepaint = ChangeNotifier();

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
    ddpRepaint.notifyListeners();
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

  ui.Image? background; // entschlüsseltes Bild der aktiven Page (Laufzeit)

  /// Tatsächlich für die Winkel-/Längen-Umrechnung verwendetes
  /// Seitenverhältnis (Höhe/Breite) — wird von der Leinwand beim Layout
  /// gesetzt: mit Hintergrundbild aus dessen realen Pixelmaßen, sonst aus
  /// [sceneAspect].
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
    selection.clear();
    if (id != null) selection.add((id, 0));
    notifyListeners();
  }

  void selectSection(int index) {
    final s = selected;
    if (s == null || s.sections.isEmpty) return;
    selectedSectionIndex = index.clamp(0, s.sections.length - 1);
    selection
      ..clear()
      ..add((s.id, selectedSectionIndex));
    notifyListeners();
  }

  // ---------- Mehrfachauswahl ----------

  /// Ersetzt die gesamte Auswahl durch genau dieses eine Element (normaler
  /// Klick/Tap ohne Zusatztaste bzw. ohne aktiven [multiSelectMode]).
  void selectOnly(String stripId, int sectionIndex) {
    selectedId = stripId;
    selectedSectionIndex = sectionIndex;
    selection
      ..clear()
      ..add((stripId, sectionIndex));
    notifyListeners();
  }

  /// Fügt ein Element hinzu oder entfernt es (Umschalt-/Cmd-Klick bzw. Tap
  /// bei aktivem [multiSelectMode]).
  void toggleInSelection(String stripId, int sectionIndex) {
    final key = (stripId, sectionIndex);
    if (!selection.remove(key)) {
      selection.add(key);
      selectedId = stripId;
      selectedSectionIndex = sectionIndex;
    } else if (selectedId == stripId && selectedSectionIndex == sectionIndex) {
      // Primäres Element wurde abgewählt — ein verbliebenes übernimmt die
      // Rolle, sonst ist nichts mehr ausgewählt.
      if (selection.isNotEmpty) {
        final next = selection.first;
        selectedId = next.$1;
        selectedSectionIndex = next.$2;
      } else {
        selectedId = null;
        selectedSectionIndex = 0;
      }
    }
    notifyListeners();
  }

  /// Fügt mehrere Elemente auf einmal hinzu (Ergebnis eines Auswahlrahmens)
  /// — immer additiv zur bestehenden Auswahl.
  void addRangeToSelection(Iterable<SelectionKey> keys) {
    if (keys.isEmpty) return;
    selection.addAll(keys);
    final primary = selection.first;
    selectedId = primary.$1;
    selectedSectionIndex = primary.$2;
    notifyListeners();
  }

  /// Entfernt mehrere Elemente auf einmal (z. B. „ganzen Stripe abwählen“).
  void removeRangeFromSelection(Iterable<SelectionKey> keys) {
    if (keys.isEmpty) return;
    selection.removeAll(keys);
    final id = selectedId;
    if (id != null && !selection.contains((id, selectedSectionIndex))) {
      if (selection.isNotEmpty) {
        final next = selection.first;
        selectedId = next.$1;
        selectedSectionIndex = next.$2;
      } else {
        selectedId = null;
        selectedSectionIndex = 0;
      }
    }
    notifyListeners();
  }

  void clearSelection() {
    selectedId = null;
    selectedSectionIndex = 0;
    selection.clear();
    notifyListeners();
  }

  void toggleMultiSelectMode() {
    multiSelectMode = !multiSelectMode;
    notifyListeners();
  }

  /// Wendet [mutate] auf jeden Abschnitt der aktuellen Mehrfachauswahl an
  /// und fasst das Ergebnis in einem einzigen Undo-Schritt zusammen (analog
  /// zu den Einzel-Editierfeldern, die selbst [changed] aufrufen).
  void editSelection(void Function(StripSection) mutate) {
    if (selection.isEmpty) return;
    for (final s in strips) {
      for (var i = 0; i < s.sections.length; i++) {
        if (selection.contains((s.id, i))) mutate(s.sections[i]);
      }
    }
    changed();
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
    selection
      ..clear()
      ..add((strip.id, 0));
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
    // Abschnitt-Indizes dieses Stripes verschieben sich potenziell —
    // bestehende Mehrfachauswahl-Einträge dafür verwerfen, statt sie auf
    // die falsche Sektion zeigen zu lassen.
    selection.removeWhere((k) => k.$1 == s.id);
    if (s.sections.isEmpty) {
      s.sections.add(
        StripSection(
          start: const Offset(0.1, 0.5),
          ledCount: remaining < 60 ? remaining : 60,
          color: _defaultColors.first,
        ),
      );
      selectedSectionIndex = 0;
      selection.add((s.id, 0));
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
    selection.add((s.id, baseIdx + 1));
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
    // Nachfolgende Indizes haben sich verschoben — Mehrfachauswahl für
    // diesen Stripe auf das verbliebene primäre Element zurücksetzen.
    selection.removeWhere((k) => k.$1 == s.id);
    if (selectedId == s.id) selection.add((s.id, selectedSectionIndex));
    changed();
  }

  void removeStrip(LedStrip s) {
    strips.remove(s);
    if (selectedId == s.id) {
      selectedId = null;
      selectedSectionIndex = 0;
    }
    selection.removeWhere((k) => k.$1 == s.id);
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
    _resyncSelectionAfterRestore();
    notifyListeners();
    _scheduleSave();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_Snapshot(this));
    _redoStack.removeLast().restoreTo(this);
    _resyncSelectionAfterRestore();
    notifyListeners();
    _scheduleSave();
  }

  /// Nach Undo/Redo kann die alte Mehrfachauswahl auf inzwischen andere
  /// Abschnitte zeigen — auf das (bereits neu validierte) primäre Element
  /// zurücksetzen statt sie einfach zu übernehmen.
  void _resyncSelectionAfterRestore() {
    selection.clear();
    final id = selectedId;
    if (id != null) selection.add((id, selectedSectionIndex));
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
    if (useImageAspect) sceneAspect = contentAspect.clamp(0.2, 2.0);
    background = null;
    backgroundPath = null;
    changed();
  }

  // ---------- Persistenz ----------
  //
  // Gespeichert wird als rohe Protobuf-Bytes (siehe proto_mapper.dart),
  // keine Hülle/Versionsrahmen nötig — die Version steckt im Dokument
  // selbst ([kSchemaVersion]). Bestehende alte Konfigurationen (YAML, davor
  // JSON) werden beim ersten Start einmalig eingelesen, als einzelne Page
  // übernommen und sofort im neuen Format zurückgeschrieben.

  Future<File> _configFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/ledato_stripes_config.ledato');
  }

  Future<File> _legacyYamlFile() async {
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
    await file.writeAsBytes(documentToProto(pages, activePageIndex).writeToBuffer());
  }

  Future<void> load() async {
    // Immer mindestens eine Page, bevor irgendein Migrations-/Ladepfad auf
    // die (auf activePage delegierten) Felder zugreift.
    pages = [
      LedPage(id: DateTime.now().microsecondsSinceEpoch.toString(), name: 'Page 1'),
    ];
    activePageIndex = 0;
    try {
      if (!kIsWeb) {
        final file = await _configFile();
        if (await file.exists()) {
          await _loadFromProtoFile(file);
        } else {
          final yamlFile = await _legacyYamlFile();
          final jsonFile = await _legacyJsonFile();
          if (await yamlFile.exists()) {
            await _migrateLegacyYaml(yamlFile);
          } else if (await jsonFile.exists()) {
            await _migrateLegacyJson(jsonFile);
          }
        }
      }
    } catch (e) {
      debugPrint('Konfiguration konnte nicht geladen werden: $e');
    }
    if (pages.isEmpty) {
      pages.add(
        LedPage(id: DateTime.now().microsecondsSinceEpoch.toString(), name: 'Page 1'),
      );
    }
    if (activePageIndex >= pages.length) activePageIndex = 0;
    if (strips.isEmpty) addStrip();
    await _reloadActiveBackground();
    _loaded = true;
    notifyListeners();
  }

  Future<void> _loadFromProtoFile(File file) async {
    final doc = pb.Document.fromBuffer(await file.readAsBytes());
    final result = documentFromProto(doc);
    pages
      ..clear()
      ..addAll(result.pages);
    activePageIndex = result.activePageIndex;
  }

  /// Liest eine alte YAML-Konfiguration einmalig ein (als einzige Page) und
  /// speichert sie sofort im neuen Protobuf-Format weiter.
  Future<void> _migrateLegacyYaml(File file) async {
    final path = applyConfigYaml(this, await file.readAsString());
    if (path != null && await File(path).exists()) {
      await setBackgroundBytes(await File(path).readAsBytes(), path);
    }
    await save();
  }

  /// Liest eine uralte JSON-Konfiguration (vor Einführung von YAML)
  /// einmalig ein und speichert sie sofort im neuen Protobuf-Format weiter.
  Future<void> _migrateLegacyJson(File file) async {
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    strips
      ..clear()
      ..addAll(
        (data['strips'] as List)
            .map((e) => LedStrip.fromJson(e as Map<String, dynamic>))
            .take(kMaxStrips),
      );
    backgroundDim = (data['backgroundDim'] as num?)?.toDouble() ?? 0.5;
    glow = (data['glow'] as num?)?.toDouble() ?? 1.0;
    sceneWidthMeters = (data['sceneWidthMeters'] as num?)?.toDouble() ?? 5.0;
    final path = data['backgroundPath'] as String?;
    if (path != null && await File(path).exists()) {
      await setBackgroundBytes(await File(path).readAsBytes(), path);
    }
    await save();
  }

  // ---------- Export / Import (Protobuf-Datei nach Wahl des Nutzers) ----------

  Uint8List exportBytes() =>
      Uint8List.fromList(documentToProto(pages, activePageIndex).writeToBuffer());

  // ---------- Neue (leere) Konfiguration ----------

  /// Verwirft die komplette Konfiguration und startet mit dem Zustand, den
  /// auch ein allererster App-Start hätte: eine leere Page mit einem
  /// einzelnen Default-Stripe, ohne Hintergrundbild.
  Future<void> newDocument() async {
    pages = [
      LedPage(id: DateTime.now().microsecondsSinceEpoch.toString(), name: 'Page 1'),
    ];
    activePageIndex = 0;
    pageElapsedMs = 0;
    background = null;
    selection.clear();
    selectedId = null;
    selectedSectionIndex = 0;
    // addStrip() ruft changed() und würde damit einen Undo-Schritt anlegen —
    // deshalb erst den Stripe erzeugen, dann die Historie leeren.
    addStrip();
    _undoStack.clear();
    _redoStack.clear();
    _pendingUndo = null;
    _undoCoalesceTimer?.cancel();
    notifyListeners();
    await save();
  }

  Future<void> importBytes(Uint8List bytes) async {
    final doc = pb.Document.fromBuffer(bytes);
    final result = documentFromProto(doc);
    pages
      ..clear()
      ..addAll(result.pages);
    if (pages.isEmpty) {
      pages.add(
        LedPage(id: DateTime.now().microsecondsSinceEpoch.toString(), name: 'Page 1'),
      );
    }
    activePageIndex = result.activePageIndex.clamp(0, pages.length - 1);
    selection.clear();
    selectedId = null;
    selectedSectionIndex = 0;
    // Undo darf nicht in die vorher geladene Konfiguration zurückführen.
    _undoStack.clear();
    _redoStack.clear();
    _pendingUndo = null;
    _undoCoalesceTimer?.cancel();
    await _reloadActiveBackground();
    notifyListeners();
    _scheduleSave();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _undoCoalesceTimer?.cancel();
    _ddpServer?.stop();
    ddpRepaint.dispose();
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
      sceneAspect = s.sceneAspect,
      useImageAspect = s.useImageAspect,
      backgroundDim = s.backgroundDim,
      glow = s.glow;

  final List<LedStrip> strips;
  final String? selectedId;
  final int selectedSectionIndex;
  final double sceneWidthMeters;
  final double sceneAspect;
  final bool useImageAspect;
  final double backgroundDim;
  final double glow;

  void restoreTo(AppState s) {
    s.strips
      ..clear()
      ..addAll([for (final strip in strips) strip.clone()]);
    s.selectedId = s.strips.any((e) => e.id == selectedId) ? selectedId : null;
    s.selectedSectionIndex = selectedSectionIndex;
    s.sceneWidthMeters = sceneWidthMeters;
    s.sceneAspect = sceneAspect;
    s.useImageAspect = useImageAspect;
    s.backgroundDim = backgroundDim;
    s.glow = glow;
  }
}
