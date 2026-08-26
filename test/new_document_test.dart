import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledato_stripes/app_state.dart';
import 'package:ledato_stripes/model.dart';
import 'package:ledato_stripes/proto_mapper.dart';
import 'package:ledato_stripes/protobuf/ledato_stripes.pb.dart' as pb;

/// Wartet den 600-ms-Coalesce-Timer aus [AppState.changed] ab, damit der
/// vorgemerkte Undo-Schritt tatsächlich auf dem Stack landet.
Future<void> _settleUndo() =>
    Future<void>.delayed(const Duration(milliseconds: 700));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('ledato_new_document_test');
    // AppState speichert über getApplicationSupportDirectory(); im Test zeigt
    // das auf ein Wegwerf-Verzeichnis. Je nach Zielplattform bedient
    // path_provider einen anderen Kanal — daher beide.
    for (final name in const [
      'plugins.flutter.io/path_provider',
      'plugins.flutter.io/path_provider_foundation',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            MethodChannel(name),
            (call) async => tmp.path,
          );
    }
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  /// Frisch geladener AppState (leeres Verzeichnis ⇒ Erststart-Zustand),
  /// bei dem `_loaded` gesetzt ist und Undo-Schritte mitgeschrieben werden.
  ///
  /// Wird am Testende verworfen: jede Mutation stellt einen Autosave-Timer
  /// (800 ms), und der feuert sonst noch, wenn [tmp] längst gelöscht ist —
  /// unter Windows quittiert das Schreiben in ein verschwundenes Verzeichnis
  /// das mit einer PathNotFoundException und lässt den Test nachträglich
  /// scheitern. [AppState.dispose] bricht die Timer ab.
  Future<AppState> freshLoadedState() async {
    final st = AppState();
    addTearDown(st.dispose);
    await st.load();
    return st;
  }

  test('newDocument setzt auf den Erststart-Zustand zurück', () async {
    final st = await freshLoadedState();

    // Ausgangslage: mehrere Pages, mehrere Stripes, Hintergrundbild gesetzt.
    await st.addPage();
    st.addStrip();
    st.addStrip();
    st.backgroundPath = '/irgendwo/bild.png';
    st.changed();
    await _settleUndo();

    expect(st.pages.length, greaterThan(1));
    expect(st.strips.length, greaterThan(1));
    expect(st.canUndo, isTrue, reason: 'Vorbedingung: Undo-Verlauf vorhanden');

    await st.newDocument();

    expect(st.pages.length, 1);
    expect(st.activePageIndex, 0);
    expect(st.strips.length, 1, reason: 'genau ein Default-Stripe wie beim Erststart');
    expect(st.backgroundPath, isNull);
    expect(st.background, isNull);
    // Wie beim Erststart ist der einzige Stripe direkt ausgewählt — die alte
    // Auswahl darf aber nicht überleben.
    expect(st.selectedId, st.strips.single.id);
    expect(st.selection, {(st.strips.single.id, 0)});
    expect(st.canUndo, isFalse, reason: 'Reset ist bewusst nicht undo-bar');
    expect(st.canRedo, isFalse);

    // Auch nach Ablauf des Coalesce-Timers darf kein Undo-Schritt nachwachsen.
    await _settleUndo();
    expect(st.canUndo, isFalse);
  });

  test('newDocument schreibt den leeren Stand sofort in die Autosave-Datei', () async {
    final st = await freshLoadedState();
    st.addStrip();
    await st.addPage();
    st.changed();
    await _settleUndo();

    await st.newDocument();

    final file = File('${tmp.path}/ledato_stripes_config.ledato');
    expect(await file.exists(), isTrue);
    final saved = documentFromProto(pb.Document.fromBuffer(await file.readAsBytes()));
    expect(saved.pages.length, 1);
    expect(saved.pages.single.strips.length, 1);
    expect(saved.activePageIndex, 0);
  });

  test('importBytes lässt Undo nicht in die vorherige Konfiguration zurückführen', () async {
    final st = await freshLoadedState();
    st.strips.single.name = 'Vorher';
    st.addStrip();
    st.changed();
    await _settleUndo();
    expect(st.canUndo, isTrue, reason: 'Vorbedingung: Undo-Verlauf vorhanden');

    final imported = LedPage(id: 'p1', name: 'Geladen')
      ..strips.add(
        LedStrip(
          id: 's1',
          name: 'Nachher',
          sections: [StripSection(start: const Offset(0.2, 0.3))],
        ),
      );
    await st.importBytes(
      documentToProto([imported], 0).writeToBuffer(),
    );

    expect(st.strips.single.name, 'Nachher');
    expect(st.canUndo, isFalse);
    expect(st.canRedo, isFalse);

    await _settleUndo();
    expect(st.canUndo, isFalse);
    expect(st.strips.single.name, 'Nachher');
  });
}
