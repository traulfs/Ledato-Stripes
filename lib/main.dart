import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'app_state.dart';
import 'editor_canvas.dart';
import 'labeled_slider.dart';
import 'model.dart';
import 'pages_screen.dart';
import 'strip_panel.dart';

void main() {
  runApp(const LedatoApp());
}

enum _FileAction {
  pickBackground,
  clearBackground,
  newConfig,
  exportConfig,
  importConfig,
  sceneWidth,
  createMatrix,
  managePages,
  toggleGrid,
  ddpServer,
}

class LedatoApp extends StatelessWidget {
  const LedatoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ledato Stripes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFFFF6000),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF15151A),
      ),
      home: const EditorScreen(),
    );
  }
}

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen>
    with SingleTickerProviderStateMixin {
  final AppState state = AppState();
  final ValueNotifier<double> time = ValueNotifier(0);
  late final Ticker _ticker;
  double _lastTickerSeconds = 0;

  @override
  void initState() {
    super.initState();
    state.load();
    _ticker = createTicker((elapsed) {
      final seconds = elapsed.inMicroseconds / 1e6;
      final dt = seconds - _lastTickerSeconds;
      _lastTickerSeconds = seconds;
      if (state.simulate) time.value = seconds;
      state.tickPlayer(dt);
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    time.dispose();
    state.dispose();
    super.dispose();
  }

  // iOS wertet beim Öffnen-Dialog ausschließlich "uniformTypeIdentifiers"
  // aus (nicht "extensions") und wirft sonst einen ArgumentError; die UTIs
  // sind daher immer mit angegeben, "extensions" bleibt für macOS/Windows/Linux.
  static const _imageTypeGroup = XTypeGroup(
    label: 'Bilder',
    extensions: ['png', 'jpg', 'jpeg', 'webp', 'bmp', 'gif'],
    uniformTypeIdentifiers: ['public.image'],
  );

  static const _ledatoTypeGroup = XTypeGroup(
    label: 'Ledato Stripes Konfiguration',
    extensions: ['ledato'],
    // Kein eigener UTI für die App deklariert — generisches Binärformat als
    // Fallback, damit iOS den Öffnen-Dialog nicht mit ArgumentError verweigert
    // (siehe Kommentar bei _imageTypeGroup).
    uniformTypeIdentifiers: ['public.data'],
  );

  Future<void> _pickBackground() async {
    try {
      final file = await openFile(acceptedTypeGroups: const [_imageTypeGroup]);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      await state.setBackgroundBytes(bytes, file.path);
    } catch (e) {
      _showError('Bild konnte nicht geöffnet werden: $e');
    }
  }

  /// iOS und Android unterstützen im file_selector-Plugin kein natives
  /// "Speichern unter" (getSaveLocation ist dort nicht implementiert) —
  /// dort wird stattdessen der native Teilen-Dialog genutzt, über den sich
  /// die Datei z. B. per "In Dateien sichern" ablegen lässt.
  Future<void> _exportConfig() async {
    final bytes = state.exportBytes();
    try {
      if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/ledato_stripes_config.ledato');
        await file.writeAsBytes(bytes);
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            subject: 'Ledato Stripes Konfiguration',
          ),
        );
        return;
      }
      final location = await getSaveLocation(
        suggestedName: 'ledato_stripes_config.ledato',
        acceptedTypeGroups: [_ledatoTypeGroup],
      );
      if (location == null) return;
      var path = location.path;
      if (!path.toLowerCase().endsWith('.ledato')) {
        path = '$path.ledato';
      }
      await File(path).writeAsBytes(bytes);
    } catch (e) {
      _showError('Konfiguration konnte nicht gespeichert werden: $e');
    }
  }

  /// Verwirft die aktuelle Konfiguration und beginnt mit einer leeren Szene.
  /// Weil das nicht per Undo zurückzuholen ist, vorher nachfragen.
  Future<void> _newConfig() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Neue Konfiguration'),
        content: const Text(
          'Alle Seiten, Stripes und das Hintergrundbild werden verworfen und '
          'durch eine leere Szene ersetzt. Das lässt sich nicht rückgängig '
          'machen — ungesicherte Arbeit vorher über „Konfiguration speichern“ '
          'sichern.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Neu beginnen'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await state.newDocument();
  }

  Future<void> _importConfig() async {
    try {
      final file = await openFile(acceptedTypeGroups: [_ledatoTypeGroup]);
      if (file == null) return;
      await state.importBytes(await file.readAsBytes());
    } catch (e) {
      _showError('Konfiguration konnte nicht geladen werden: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showDdpDialog() async {
    var ips = <String>[];
    try {
      if (!kIsWeb) {
        final interfaces = await NetworkInterface.list(
          includeLoopback: false,
          type: InternetAddressType.IPv4,
        );
        ips = [
          for (final i in interfaces)
            for (final a in i.addresses) a.address,
        ];
      }
    } catch (_) {
      // Netzwerkschnittstellen nicht ermittelbar (z. B. fehlende
      // Berechtigung) — Anzeige der IPs ist nur eine Komfort-Info.
    }
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (dialogContext) => ListenableBuilder(
        listenable: state,
        builder: (context, _) => AlertDialog(
          title: const Text('DDP-Server'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  state.ddpServerRunning
                      ? 'Läuft auf Port ${state.ddpPort}'
                      : 'Gestoppt',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (state.ddpServerRunning && ips.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Erreichbar unter: ${ips.join(', ')}'),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  key: ValueKey('ddp-port-${state.ddpPort}'),
                  initialValue: '${state.ddpPort}',
                  enabled: !state.ddpServerRunning,
                  decoration: const InputDecoration(
                    labelText: 'Port',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    final p = int.tryParse(v);
                    if (p != null && p > 0 && p < 65536) state.ddpPort = p;
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  'Ziel-ID 1–8 im DDP-Paket entspricht Stripe 1–8 in der '
                  'Reihenfolge der Konfiguration. Solange für einen Stripe '
                  'Pakete ankommen, ersetzen sie dessen Effekt live.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (state.ddpServerRunning) {
                  await state.stopDdpServer();
                } else {
                  await state.startDdpServer(state.ddpPort);
                }
              },
              child: Text(state.ddpServerRunning ? 'Stoppen' : 'Starten'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Fertig'),
            ),
          ],
        ),
      ),
    );
  }

  /// Kompakte Transportleiste unter der App-Leiste: Play/Pause, Zurück/
  /// Weiter und Name+Index der aktiven Page — nur sichtbar, wenn es
  /// überhaupt mehrere Pages gibt.
  Widget _playerBar() {
    if (state.pages.length <= 1) return const SizedBox.shrink();
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            IconButton(
              tooltip: state.playing ? 'Player pausieren' : 'Player starten',
              icon: Icon(state.playing ? Icons.pause : Icons.play_arrow),
              onPressed: state.togglePlaying,
            ),
            IconButton(
              tooltip: 'Vorherige Page',
              icon: const Icon(Icons.skip_previous),
              onPressed: state.prevPage,
            ),
            IconButton(
              tooltip: 'Nächste Page',
              icon: const Icon(Icons.skip_next),
              onPressed: state.nextPage,
            ),
            Expanded(
              child: Text(
                '${state.activePage.name}  '
                '(${state.activePageIndex + 1}/${state.pages.length})',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPagesScreen() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PagesScreen(state: state)));
  }

  Future<void> _showMatrixDialog() async {
    var columns = 16;
    var rows = 8;
    var stripCount = 1;
    var ledsPerMeter = state.selected?.ledsPerMeter ?? 60;

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) {
          final error = state.matrixError(
            columns: columns,
            rows: rows,
            stripCount: stripCount,
          );
          final pitch = 1 / ledsPerMeter;
          final widthM = (columns - 1) * pitch;
          final heightM = (rows - 1) * pitch;

          return AlertDialog(
            title: const Text('LED-Matrix erstellen'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LabeledSlider(
                    label: 'Spalten',
                    value: columns.toDouble(),
                    min: 1,
                    max: kMaxLedsPerStrip.toDouble(),
                    numberEntry: true,
                    display: '$columns',
                    onChanged: (v) => setLocal(() => columns = v.round()),
                  ),
                  LabeledSlider(
                    label: 'Zeilen',
                    value: rows.toDouble(),
                    min: 1,
                    max: 64,
                    numberEntry: true,
                    display: '$rows',
                    onChanged: (v) => setLocal(() => rows = v.round()),
                  ),
                  LabeledSlider(
                    label: 'Stripes',
                    value: stripCount.toDouble(),
                    min: 1,
                    max: kMaxStrips.toDouble(),
                    divisions: kMaxStrips - 1,
                    numberEntry: true,
                    display: '$stripCount',
                    onChanged: (v) => setLocal(() => stripCount = v.round()),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const SizedBox(width: 90, child: Text('Stripetyp')),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: ledsPerMeter,
                          isDense: true,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            for (final d in kLedDensities)
                              DropdownMenuItem(
                                value: d,
                                child: Text('$d LEDs/m'),
                              ),
                          ],
                          onChanged: (v) =>
                              setLocal(() => ledsPerMeter = v ?? ledsPerMeter),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (error != null)
                    Text(
                      error,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    )
                  else
                    Text(
                      '${columns * rows} LEDs auf $stripCount '
                      '${stripCount == 1 ? "Stripe" : "Stripes"} à '
                      '${rows ~/ stripCount} '
                      '${rows ~/ stripCount == 1 ? "Zeile" : "Zeilen"} · '
                      '${fmtMeters(widthM)} × ${fmtMeters(heightM)}\n'
                      'Verdrahtung im Mäander: jede zweite Zeile läuft '
                      'zurück. Jeder Stripe wird links oben eingespeist.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                onPressed: error != null
                    ? null
                    : () => Navigator.pop(context, true),
                child: const Text('Erstellen'),
              ),
            ],
          );
        },
      ),
    );

    if (created != true) return;
    if (state.createMatrix(
          columns: columns,
          rows: rows,
          stripCount: stripCount,
          ledsPerMeter: ledsPerMeter,
        ) ==
        null) {
      _showError('Matrix konnte nicht erstellt werden.');
    }
  }

  Future<void> _showSceneWidthDialog() async {
    await showDialog(
      context: context,
      builder: (context) => ListenableBuilder(
        listenable: state,
        builder: (context, _) => AlertDialog(
          title: const Text('Maßstab'),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LabeledSlider(
                  label: 'Bildbreite',
                  value: state.sceneWidthMeters,
                  min: 0.1,
                  max: 30,
                  display: fmtMeters(state.sceneWidthMeters),
                  numberEntry: true,
                  decimals: 2,
                  unitSuffix: 'm',
                  fieldWidth: 76,
                  onChanged: (v) {
                    state.sceneWidthMeters = v;
                    state.changed();
                  },
                ),
                Text(
                  'Reale Breite des Hintergrundbilds — darüber werden '
                  'Stripe-Längen und LED-Anzahl berechnet.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (state.background != null) ...[
                  const SizedBox(height: 12),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Seitenverhältnis vom Bild übernehmen'),
                    value: state.useImageAspect,
                    onChanged: (v) {
                      state.useImageAspect = v;
                      state.changed();
                    },
                  ),
                ],
                if (state.background == null || !state.useImageAspect) ...[
                  const SizedBox(height: 12),
                  LabeledSlider(
                    label: 'Format',
                    value: state.sceneAspect,
                    min: 0.2,
                    max: 2.0,
                    display: '${(state.sceneAspect * 100).round()} %',
                    numberEntry: true,
                    displayScale: 100,
                    unitSuffix: '%',
                    onChanged: (v) {
                      state.sceneAspect = v;
                      state.changed();
                    },
                  ),
                  Text(
                    'Seitenverhältnis (Höhe ÷ Breite) des Bildbereichs — wird '
                    'gespeichert, damit dieselbe Konfiguration auf jedem '
                    'Gerät gleich aussieht, statt sich nach Fenster- oder '
                    'Bildschirmform zu richten. Mit Hintergrundbild wird '
                    'dieses auf das gewählte Format gestreckt.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fertig'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final wide = MediaQuery.sizeOf(context).width > 900;
        final compact = MediaQuery.sizeOf(context).width < 600;
        final canvas = EditorCanvas(state: state, time: time);
        final panel = StripPanel(state: state);

        return CallbackShortcuts(
          bindings: {
            LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyZ):
                state.undo,
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyZ):
                state.undo,
            LogicalKeySet(
              LogicalKeyboardKey.meta,
              LogicalKeyboardKey.shift,
              LogicalKeyboardKey.keyZ,
            ): state.redo,
            LogicalKeySet(
              LogicalKeyboardKey.control,
              LogicalKeyboardKey.shift,
              LogicalKeyboardKey.keyZ,
            ): state.redo,
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              appBar: AppBar(
                title: const Text('Ledato Stripes'),
                actions: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                  IconButton(
                    tooltip: 'Rückgängig',
                    icon: const Icon(Icons.undo),
                    onPressed: state.canUndo ? state.undo : null,
                  ),
                  IconButton(
                    tooltip: 'Wiederholen',
                    icon: const Icon(Icons.redo),
                    onPressed: state.canRedo ? state.redo : null,
                  ),
                  SizedBox(width: compact ? 2 : 8),
                  PopupMenuButton<_FileAction>(
                    tooltip: 'Datei',
                    icon: const Icon(Icons.menu),
                    onSelected: (action) {
                      switch (action) {
                        case _FileAction.pickBackground:
                          _pickBackground();
                        case _FileAction.clearBackground:
                          state.clearBackground();
                        case _FileAction.newConfig:
                          _newConfig();
                        case _FileAction.exportConfig:
                          _exportConfig();
                        case _FileAction.importConfig:
                          _importConfig();
                        case _FileAction.sceneWidth:
                          _showSceneWidthDialog();
                        case _FileAction.createMatrix:
                          _showMatrixDialog();
                        case _FileAction.managePages:
                          _openPagesScreen();
                        case _FileAction.toggleGrid:
                          state.showLedGrid = !state.showLedGrid;
                          state.changed();
                        case _FileAction.ddpServer:
                          _showDdpDialog();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: _FileAction.pickBackground,
                        child: ListTile(
                          leading: Icon(Icons.image_outlined),
                          title: Text('Hintergrundbild wählen'),
                        ),
                      ),
                      if (state.background != null)
                        const PopupMenuItem(
                          value: _FileAction.clearBackground,
                          child: ListTile(
                            leading: Icon(Icons.hide_image_outlined),
                            title: Text('Hintergrundbild entfernen'),
                          ),
                        ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: _FileAction.newConfig,
                        child: ListTile(
                          leading: Icon(Icons.note_add_outlined),
                          title: Text('Neue Konfiguration'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: _FileAction.exportConfig,
                        child: ListTile(
                          leading: Icon(Icons.save_outlined),
                          title: Text('Konfiguration speichern'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: _FileAction.importConfig,
                        child: ListTile(
                          leading: Icon(Icons.file_open_outlined),
                          title: Text('Konfiguration laden'),
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: _FileAction.sceneWidth,
                        child: ListTile(
                          leading: Icon(Icons.straighten_outlined),
                          title: Text('Maßstab (Bildbreite)'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: _FileAction.createMatrix,
                        child: ListTile(
                          leading: Icon(Icons.grid_4x4_outlined),
                          title: Text('LED-Matrix erstellen'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: _FileAction.managePages,
                        child: ListTile(
                          leading: Icon(Icons.auto_awesome_motion_outlined),
                          title: Text('Seiten verwalten'),
                        ),
                      ),
                      PopupMenuItem(
                        enabled: state.editMode,
                        value: _FileAction.toggleGrid,
                        child: ListTile(
                          leading: Icon(
                            state.showLedGrid
                                ? Icons.grid_on
                                : Icons.grid_off,
                          ),
                          title: const Text('Ausrichtungsraster'),
                          subtitle: Text(
                            state.showLedGrid
                                ? 'Sichtbar · $kGridLedsPerMeter LEDs/m'
                                : 'Ausgeblendet',
                          ),
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: _FileAction.ddpServer,
                        child: ListTile(
                          leading: Icon(
                            state.ddpServerRunning
                                ? Icons.wifi_tethering
                                : Icons.wifi_tethering_off,
                          ),
                          title: const Text('DDP-Server'),
                          subtitle: Text(
                            state.ddpServerRunning
                                ? 'Aktiv · Port ${state.ddpPort}'
                                : 'Gestoppt',
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: compact ? 2 : 8),
                  IconButton(
                    tooltip: state.multiSelectMode
                        ? 'Mehrfachauswahl beenden'
                        : 'Mehrfachauswahl: Tippen erweitert die Auswahl '
                              'statt sie zu ersetzen',
                    isSelected: state.multiSelectMode,
                    icon: const Icon(Icons.checklist_outlined),
                    selectedIcon: const Icon(Icons.checklist),
                    onPressed: !state.editMode
                        ? null
                        : state.toggleMultiSelectMode,
                  ),
                  SizedBox(width: compact ? 2 : 8),
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: true,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: compact ? null : const Text('Bearbeiten'),
                      ),
                      ButtonSegment(
                        value: false,
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        label: compact ? null : const Text('Vorschau'),
                      ),
                    ],
                    selected: {state.editMode},
                    onSelectionChanged: (v) {
                      state.editMode = v.first;
                      state.changed();
                    },
                    showSelectedIcon: false,
                  ),
                  SizedBox(width: compact ? 2 : 8),
                  IconButton(
                    tooltip: state.simulate
                        ? 'Simulation anhalten'
                        : 'Simulation starten',
                    icon: Icon(state.simulate ? Icons.pause : Icons.play_arrow),
                    onPressed: () {
                      state.simulate = !state.simulate;
                      state.changed();
                    },
                  ),
                  SizedBox(width: compact ? 2 : 8),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              endDrawer: wide
                  ? null
                  : Drawer(width: 340, child: SafeArea(child: panel)),
              body: Column(
                children: [
                  _playerBar(),
                  Expanded(
                    child: wide
                        ? Row(
                            children: [
                              Expanded(child: canvas),
                              const VerticalDivider(width: 1),
                              SizedBox(width: 360, child: panel),
                            ],
                          )
                        : canvas,
                  ),
                ],
              ),
              floatingActionButton: wide
                  ? null
                  : Builder(
                      builder: (context) => FloatingActionButton(
                        tooltip: 'Konfiguration',
                        onPressed: () => Scaffold.of(context).openEndDrawer(),
                        child: const Icon(Icons.tune),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}
