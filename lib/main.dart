import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

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

  Future<void> _pickBackground() async {
    const typeGroup = XTypeGroup(
      label: 'Bilder',
      extensions: ['png', 'jpg', 'jpeg', 'webp', 'bmp', 'gif'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    await state.setBackgroundBytes(bytes, file.path);
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
