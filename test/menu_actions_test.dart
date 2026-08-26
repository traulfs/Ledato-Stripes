import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledato_stripes/main.dart';

/// Klickt die Einträge des Datei-Menüs so durch, wie es ein Benutzer täte —
/// die Gegenprobe zu den reinen AppState-Tests: Menüeintrag vorhanden,
/// Dialog erscheint, Aktion wirkt sich auf die Szene aus.
/// [WidgetTester.pumpAndSettle] ist hier unbrauchbar: der Editor hält einen
/// dauerhaft laufenden Ticker für die Effekt-Animation, es wird also nie
/// „ruhig". Stattdessen genug Frames für Menü- und Dialog-Animationen pumpen.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('ledato_menu_test');
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
    // Der Autosave der App schreibt auf dem realen Dateisystem, während der
    // Test in der Testuhr läuft — beim Aufräumen kann also noch ein
    // Schreibvorgang unterwegs sein. POSIX stört das nicht, Windows
    // verweigert das Löschen eines Verzeichnisses mit offener Datei
    // („wird von einem anderen Prozess verwendet", errno 32).
    //
    // Also mehrfach versuchen und das Verzeichnis notfalls liegen lassen:
    // es ist ein Wegwerf-Verzeichnis im Temp-Ordner des Systems, und ob es
    // sich aufräumen lässt, sagt nichts über das Verhalten aus, das dieser
    // Test prüft.
    for (var attempt = 0; attempt < 40; attempt++) {
      try {
        if (await tmp.exists()) await tmp.delete(recursive: true);
        return;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
  });

  /// Startet die App in einem Fenster, das breit genug für das feste
  /// Seitenpanel ist, und wartet den initialen load() ab.
  Future<void> pumpApp(WidgetTester tester) async {
    // Im Widget-Test rendert die Ersatzschrift deutlich breiter als die echte,
    // wodurch das bestehende Effekt-Dropdown im 360-px-Panel überläuft (in der
    // App passt es). Nur diese Layout-Meldung wird geschluckt, jeder andere
    // Fehler schlägt weiterhin fehl. Muss im Testkörper stehen: das
    // Test-Binding setzt FlutterError.onError beim Teststart selbst.
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('overflowed by')) return;
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    // Im Test ist devicePixelRatio 3.0 — ohne Rücksetzen wären 1400 physische
    // Pixel nur ~466 logische und die App liefe im Kompakt-Layout, in dem das
    // Stripe-Panel hinter einem Drawer steckt statt fest neben der Leinwand.
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const LedatoApp());
    await settle(tester);
  }

  Future<void> openFileMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Datei'));
    await settle(tester);
  }

  testWidgets('LED-Matrix erstellen legt die Stripes an', (tester) async {
    await pumpApp(tester);

    await openFileMenu(tester);
    expect(find.text('LED-Matrix erstellen'), findsOneWidget);
    await tester.tap(find.text('LED-Matrix erstellen'));
    await settle(tester);

    // Vorbelegung 16 Spalten × 8 Zeilen auf 1 Stripe.
    expect(find.text('LED-Matrix erstellen'), findsOneWidget); // Dialogtitel
    expect(find.textContaining('128 LEDs'), findsOneWidget);
    expect(find.textContaining('Mäander'), findsOneWidget);

    await tester.tap(find.text('Erstellen'));
    await settle(tester);

    // Das Stripe-Dropdown zeigt jetzt den neu erzeugten Matrix-Stripe.
    expect(find.text('Matrix 16×8'), findsOneWidget);
  });

  testWidgets('Matrix-Dialog blockiert unmögliche Eckdaten', (tester) async {
    await pumpApp(tester);
    await openFileMenu(tester);
    await tester.tap(find.text('LED-Matrix erstellen'));
    await settle(tester);

    // 8 Zeilen lassen sich nicht auf 3 Stripes verteilen.
    final stripesField = find.descendant(
      of: find.ancestor(
        of: find.text('Stripes'),
        matching: find.byType(Row),
      ),
      matching: find.byType(TextField),
    );
    await tester.enterText(stripesField.first, '3');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);

    expect(find.textContaining('nicht gleichmäßig'), findsOneWidget);
    final createButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Erstellen'),
    );
    expect(createButton.onPressed, isNull, reason: 'Erstellen ist gesperrt');
  });

  testWidgets('Neue Konfiguration verwirft die Szene erst nach Bestätigung', (
    tester,
  ) async {
    await pumpApp(tester);

    // Etwas zum Verwerfen anlegen.
    await openFileMenu(tester);
    await tester.tap(find.text('LED-Matrix erstellen'));
    await settle(tester);
    await tester.tap(find.text('Erstellen'));
    await settle(tester);
    expect(find.text('Matrix 16×8'), findsOneWidget);

    // Abbrechen lässt alles stehen.
    await openFileMenu(tester);
    await tester.tap(find.text('Neue Konfiguration'));
    await settle(tester);
    await tester.tap(find.text('Abbrechen'));
    await settle(tester);
    expect(find.text('Matrix 16×8'), findsOneWidget);

    // Bestätigen räumt die Szene leer.
    await openFileMenu(tester);
    await tester.tap(find.text('Neue Konfiguration'));
    await settle(tester);
    await tester.tap(find.text('Neu beginnen'));
    await settle(tester);
    expect(find.textContaining('Matrix'), findsNothing);
    expect(find.text('Stripe 1'), findsOneWidget);
  });
}
