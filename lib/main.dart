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
import 'strip_panel.dart';

void main() {
  runApp(const LedatoApp());
}

enum _FileAction {
  pickBackground,
  clearBackground,
  exportConfig,
  importConfig,
  sceneWidth,
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

  @override
  void initState() {
    super.initState();
    state.load();
    _ticker = createTicker((elapsed) {
      if (state.simulate) time.value = elapsed.inMicroseconds / 1e6;
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

  static const _yamlTypeGroup = XTypeGroup(
    label: 'YAML',
    extensions: ['yaml', 'yml'],
    uniformTypeIdentifiers: ['public.yaml'],
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
    final text = state.exportYamlText();
    try {
      if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/ledato_stripes_config.yaml');
        await file.writeAsString(text);
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            subject: 'Ledato Stripes Konfiguration',
          ),
        );
        return;
      }
      final location = await getSaveLocation(
        suggestedName: 'ledato_stripes_config.yaml',
        acceptedTypeGroups: const [_yamlTypeGroup],
      );
      if (location == null) return;
      var path = location.path;
      final lower = path.toLowerCase();
      if (!lower.endsWith('.yaml') && !lower.endsWith('.yml')) {
        path = '$path.yaml';
      }
      await File(path).writeAsString(text);
    } catch (e) {
      _showError('Konfiguration konnte nicht gespeichert werden: $e');
    }
  }

  Future<void> _importConfig() async {
    try {
      final file = await openFile(acceptedTypeGroups: const [_yamlTypeGroup]);
      if (file == null) return;
      await state.importYamlText(await file.readAsString());
    } catch (e) {
      _showError('YAML konnte nicht geladen werden: $e');
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
                  min: 0.5,
                  max: 30,
                  display: fmtMeters(state.sceneWidthMeters),
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
                  const SizedBox(width: 8),
                  PopupMenuButton<_FileAction>(
                    tooltip: 'Datei',
                    icon: const Icon(Icons.menu),
                    onSelected: (action) {
                      switch (action) {
                        case _FileAction.pickBackground:
                          _pickBackground();
                        case _FileAction.clearBackground:
                          state.clearBackground();
                        case _FileAction.exportConfig:
                          _exportConfig();
                        case _FileAction.importConfig:
                          _importConfig();
                        case _FileAction.sceneWidth:
                          _showSceneWidthDialog();
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
                        value: _FileAction.exportConfig,
                        child: ListTile(
                          leading: Icon(Icons.save_outlined),
                          title: Text('Konfiguration als YAML speichern'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: _FileAction.importConfig,
                        child: ListTile(
                          leading: Icon(Icons.file_open_outlined),
                          title: Text('Konfiguration aus YAML laden'),
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
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: state.showLedGrid
                        ? 'Raster ausblenden'
                        : 'Raster anzeigen ($kGridLedsPerMeter LEDs/m)',
                    icon: Icon(
                      state.showLedGrid ? Icons.grid_on : Icons.grid_off,
                    ),
                    onPressed: !state.editMode
                        ? null
                        : () {
                            state.showLedGrid = !state.showLedGrid;
                            state.changed();
                          },
                  ),
                  const SizedBox(width: 8),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: true,
                        icon: Icon(Icons.edit_outlined, size: 18),
                        label: Text('Bearbeiten'),
                      ),
                      ButtonSegment(
                        value: false,
                        icon: Icon(Icons.visibility_outlined, size: 18),
                        label: Text('Vorschau'),
                      ),
                    ],
                    selected: {state.editMode},
                    onSelectionChanged: (v) {
                      state.editMode = v.first;
                      state.changed();
                    },
                    showSelectedIcon: false,
                  ),
                  const SizedBox(width: 8),
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
                  const SizedBox(width: 8),
                ],
              ),
              endDrawer: wide
                  ? null
                  : Drawer(width: 340, child: SafeArea(child: panel)),
              body: wide
                  ? Row(
                      children: [
                        Expanded(child: canvas),
                        const VerticalDivider(width: 1),
                        SizedBox(width: 360, child: panel),
                      ],
                    )
                  : canvas,
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
