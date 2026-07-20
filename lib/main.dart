import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'app_state.dart';
import 'editor_canvas.dart';
import 'strip_panel.dart';

void main() {
  runApp(const LedatoApp());
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
        await SharePlus.instance.share(ShareParams(
          files: [XFile(file.path)],
          subject: 'Ledato Stripes Konfiguration',
        ));
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final wide = MediaQuery.sizeOf(context).width > 900;
        final canvas = EditorCanvas(state: state, time: time);
        final panel = StripPanel(state: state);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Ledato Stripes'),
            actions: [
              IconButton(
                tooltip: 'Hintergrundbild wählen',
                icon: const Icon(Icons.image_outlined),
                onPressed: _pickBackground,
              ),
              if (state.background != null)
                IconButton(
                  tooltip: 'Hintergrundbild entfernen',
                  icon: const Icon(Icons.hide_image_outlined),
                  onPressed: state.clearBackground,
                ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Konfiguration als YAML speichern',
                icon: const Icon(Icons.save_outlined),
                onPressed: _exportConfig,
              ),
              IconButton(
                tooltip: 'Konfiguration aus YAML laden',
                icon: const Icon(Icons.file_open_outlined),
                onPressed: _importConfig,
              ),
              const SizedBox(width: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                      value: true,
                      icon: Icon(Icons.edit_outlined, size: 18),
                      label: Text('Bearbeiten')),
                  ButtonSegment(
                      value: false,
                      icon: Icon(Icons.visibility_outlined, size: 18),
                      label: Text('Vorschau')),
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
                tooltip: state.simulate ? 'Simulation anhalten' : 'Simulation starten',
                icon: Icon(state.simulate ? Icons.pause : Icons.play_arrow),
                onPressed: () {
                  state.simulate = !state.simulate;
                  state.changed();
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          endDrawer:
              wide ? null : Drawer(width: 340, child: SafeArea(child: panel)),
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
        );
      },
    );
  }
}
