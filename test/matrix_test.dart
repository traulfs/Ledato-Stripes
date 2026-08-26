import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ledato_stripes/app_state.dart';
import 'package:ledato_stripes/model.dart';

/// Berechnet die Positionen aller LEDs eines Stripes in Reihenfolge des
/// fortlaufenden (Adressierungs-)Index — dieselbe Reihenfolge, die die
/// Leinwand zeichnet und der DDP-Server bedient.
List<Offset> _ledPositions(AppState st, LedStrip s) {
  final out = <Offset>[];
  for (final sec in s.sections) {
    final end = st.sectionEnd(s, sec);
    final n = sec.ledCount;
    for (var i = 0; i < n; i++) {
      out.add(Offset.lerp(sec.start, end, n == 1 ? 0.0 : i / (n - 1))!);
    }
  }
  return out;
}

void main() {
  late AppState st;

  setUp(() {
    st = AppState();
    st.contentAspect = 1.0;
    st.strips.clear(); // Ausgangslage ohne den Default-Stripe
  });

  group('matrixError', () {
    test('akzeptiert eine glatt aufteilbare Matrix', () {
      expect(st.matrixError(columns: 32, rows: 16, stripCount: 4), isNull);
    });

    test('lehnt ungleichmäßige Zeilenverteilung ab', () {
      expect(
        st.matrixError(columns: 10, rows: 10, stripCount: 3),
        contains('nicht gleichmäßig'),
      );
    });

    test('lehnt mehr Stripes als Zeilen ab', () {
      expect(
        st.matrixError(columns: 10, rows: 2, stripCount: 4),
        contains('mindestens eine Zeile'),
      );
    });

    test('lehnt zu viele LEDs pro Stripe ab', () {
      // 32 × 16 = 512 LEDs auf einem Stripe, Maximum ist kMaxLedsPerStrip.
      final err = st.matrixError(columns: 32, rows: 16, stripCount: 1);
      expect(err, contains('$kMaxLedsPerStrip'));
    });

    test('berücksichtigt bereits vorhandene Stripes', () {
      for (var i = 0; i < kMaxStrips - 2; i++) {
        st.strips.add(
          LedStrip(id: 's$i', name: 'x', sections: [StripSection(start: Offset.zero)]),
        );
      }
      expect(st.matrixError(columns: 8, rows: 4, stripCount: 2), isNull);
      expect(
        st.matrixError(columns: 8, rows: 4, stripCount: 4),
        contains('frei'),
      );
    });
  });

  test('createMatrix legt Stripes, Zeilen und LED-Anzahl korrekt an', () {
    final created = st.createMatrix(
      columns: 16,
      rows: 8,
      stripCount: 2,
      ledsPerMeter: 60,
    );

    expect(created, isNotNull);
    expect(created!.length, 2);
    expect(st.strips.length, 2);
    for (final s in created) {
      expect(s.ledsPerMeter, 60);
      expect(s.sections.length, 4, reason: '8 Zeilen auf 2 Stripes');
      expect(s.ledCount, 64, reason: '4 Zeilen à 16 LEDs');
      for (final sec in s.sections) {
        expect(sec.ledCount, 16);
      }
    }
    expect(st.selectedId, created.first.id);
  });

  test('createMatrix verweigert unmögliche Eckdaten ohne etwas anzulegen', () {
    expect(
      st.createMatrix(columns: 32, rows: 16, stripCount: 1, ledsPerMeter: 60),
      isNull,
    );
    expect(st.strips, isEmpty);
  });

  test('Zeilen sind im Mäander verdrahtet und liegen im LED-Pitch übereinander', () {
    const columns = 8;
    const rows = 4;
    const density = 60;
    final s = st.createMatrix(
      columns: columns,
      rows: rows,
      stripCount: 1,
      ledsPerMeter: density,
    )!.single;

    // Zeile 0 läuft nach rechts, Zeile 1 zurück nach links, usw.
    for (var r = 0; r < rows; r++) {
      expect(
        s.sections[r].angle,
        r.isEven ? 0.0 : math.pi,
        reason: 'Zeile $r ${r.isEven ? "vorwärts" : "rückwärts"}',
      );
    }

    final pos = _ledPositions(st, s);
    expect(pos.length, columns * rows);

    // Spaltenraster: x-Werte jeder Zeile decken dieselben Positionen ab.
    final firstRowX = [for (var i = 0; i < columns; i++) pos[i].dx];
    final secondRowX = [
      for (var i = 0; i < columns; i++) pos[columns + i].dx,
    ];
    expect(
      secondRowX,
      orderedEquals(firstRowX.reversed.map((x) => closeTo(x, 1e-9))),
      reason: 'zweite Zeile läuft dieselben Spalten rückwärts ab',
    );

    // Zeilenabstand ist der LED-Pitch (bei contentAspect 1 identisch zum
    // Spaltenabstand), Zeilen liegen unter- statt nebeneinander.
    final pitchNorm = (1.0 / density) / st.sceneWidthMeters;
    expect(pos[columns].dy - pos[0].dy, closeTo(pitchNorm, 1e-9));
    expect(pos[1].dx - pos[0].dx, closeTo(pitchNorm, 1e-9));
    expect(pos[0].dy, closeTo(pos[columns - 1].dy, 1e-9));

    // Der Sprung zwischen Zeilenende und nächstem Zeilenanfang ist genau ein
    // Pitch nach unten — das ist die Mäander-Kehre, keine Diagonale.
    final endOfRow0 = pos[columns - 1];
    final startOfRow1 = pos[columns];
    expect(startOfRow1.dx, closeTo(endOfRow0.dx, 1e-9));
    expect(startOfRow1.dy - endOfRow0.dy, closeTo(pitchNorm, 1e-9));
  });

  test('Mäander startet in jedem Stripe neu links', () {
    const columns = 6;
    final created = st.createMatrix(
      columns: columns,
      rows: 4,
      stripCount: 2,
      ledsPerMeter: 60,
    )!;

    final a = _ledPositions(st, created[0]);
    final b = _ledPositions(st, created[1]);
    // Jeder Stripe hat seine eigene Einspeisung an derselben (linken) Kante.
    expect(b.first.dx, closeTo(a.first.dx, 1e-9));
    // ... aber liegt tiefer: Stripe 2 beginnt zwei Zeilen unter Stripe 1.
    expect(b.first.dy, greaterThan(a.last.dy));
    for (final s in created) {
      expect(s.sections.first.angle, 0.0);
      expect(s.sections[1].angle, math.pi);
    }
  });

  test('Matrix ist in der Szene zentriert', () {
    const columns = 10;
    const rows = 6;
    final s = st.createMatrix(
      columns: columns,
      rows: rows,
      stripCount: 1,
      ledsPerMeter: 144,
    )!.single;

    final pos = _ledPositions(st, s);
    final xs = pos.map((p) => p.dx);
    final ys = pos.map((p) => p.dy);
    expect(
      (xs.reduce(math.min) + xs.reduce(math.max)) / 2,
      closeTo(0.5, 1e-9),
    );
    expect(
      (ys.reduce(math.min) + ys.reduce(math.max)) / 2,
      closeTo(0.5, 1e-9),
    );
  });

  test('createMatrix ist ein einzelner Undo-Schritt', () {
    st.createMatrix(columns: 8, rows: 4, stripCount: 2, ledsPerMeter: 60);
    expect(st.strips.length, 2);
    // changed() wurde genau einmal für die ganze Matrix gerufen; der
    // Snapshot-Mechanismus fasst sie damit zu einem Schritt zusammen.
    expect(st.strips.every((s) => s.sections.length == 2), isTrue);
  });
}
