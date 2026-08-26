import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledato_stripes/app_state.dart';
import 'package:ledato_stripes/effects.dart';
import 'package:ledato_stripes/model.dart';
import 'package:ledato_stripes/proto_mapper.dart';
import 'package:ledato_stripes/protobuf/ledato_stripes.pb.dart' as pb;

/// Farbe jeder LED eines Stripes in Adressierungsreihenfolge — so, wie die
/// Leinwand sie zeichnet: fortlaufender Index bei [LedStrip.continuousEffect],
/// sonst je Abschnitt von vorn.
List<Color> _frame(LedStrip s, double t) {
  final out = <Color>[];
  var global = 0;
  for (final sec in s.sections) {
    for (var i = 0; i < sec.ledCount; i++) {
      out.add(
        s.continuousEffect
            ? ledColor(s, sec, s.ledCount, global, t)
            : ledColor(s, sec, sec.ledCount, i, t),
      );
      global++;
    }
  }
  return out;
}

/// Index der hellsten LED — beim Lauflicht der Kopf des Punkts.
int _brightest(List<Color> frame) {
  var best = 0;
  var bestLum = -1.0;
  for (var i = 0; i < frame.length; i++) {
    final c = frame[i];
    final lum = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    if (lum > bestLum) {
      bestLum = lum;
      best = i;
    }
  }
  return best;
}

void main() {
  late AppState st;

  setUp(() {
    st = AppState();
    st.contentAspect = 1.0;
    st.strips.clear();
  });

  test('Matrix startet mit langsamem, durchlaufendem Lauflicht', () {
    final s = st.createMatrix(
      columns: 8,
      rows: 4,
      stripCount: 1,
      ledsPerMeter: 60,
    )!.single;

    expect(s.continuousEffect, isTrue);
    for (final sec in s.sections) {
      expect(sec.effect, EffectType.chase);
      expect(sec.speed, lessThan(0.3), reason: 'langsam');
    }
  });

  test('Lauflicht wandert über den ganzen Stripe statt in jeder Zeile neu', () {
    final s = st.createMatrix(
      columns: 8,
      rows: 4,
      stripCount: 1,
      ledsPerMeter: 60,
    )!.single;
    expect(s.ledCount, 32);

    // Über eine ganze Runde hinweg muss der Kopf des Lauflichts auch
    // Positionen jenseits der ersten Zeile erreichen.
    final heads = <int>{};
    for (var step = 0; step < 400; step++) {
      heads.add(_brightest(_frame(s, step * 0.05)));
    }
    expect(
      heads.where((h) => h >= 8).length,
      greaterThan(8),
      reason: 'der Punkt läuft durch alle vier Zeilen, nicht nur durch die erste',
    );
    expect(heads.reduce((a, b) => a > b ? a : b), greaterThanOrEqualTo(24));

    // Gegenprobe: ohne das Flag beginnt jede Zeile von vorn, dann ist in
    // jedem Bild in jeder Zeile derselbe lokale Punkt hell.
    s.continuousEffect = false;
    final frame = _frame(s, 3.0);
    final localHeadRow0 = _brightest(frame.sublist(0, 8));
    final localHeadRow1 = _brightest(frame.sublist(8, 16));
    expect(localHeadRow1, localHeadRow0);
  });

  test('durchlaufender Effekt überlebt Speichern und Laden', () {
    st.createMatrix(columns: 8, rows: 4, stripCount: 2, ledsPerMeter: 144);
    final bytes = documentToProto([
      LedPage(id: 'p', name: 'n', strips: st.strips),
    ], 0).writeToBuffer();

    final back = documentFromProto(pb.Document.fromBuffer(bytes));
    final strips = back.pages.single.strips;
    expect(strips.length, 2);
    for (final s in strips) {
      expect(s.continuousEffect, isTrue);
      expect(s.ledsPerMeter, 144);
      expect(s.sections.first.effect, EffectType.chase);
    }
  });

  test('bestehende Stripes bleiben unverändert (Flag ist aus)', () {
    final s = LedStrip(
      id: 'x',
      name: 'Alt',
      sections: [
        StripSection(start: Offset.zero, ledCount: 5, effect: EffectType.chase),
        StripSection(start: Offset.zero, ledCount: 5, effect: EffectType.chase),
      ],
    );
    expect(s.continuousEffect, isFalse);
    expect(s.clone().continuousEffect, isFalse);

    // Beide Abschnitte rechnen für sich — gleiche Farbe an gleicher lokaler
    // Position, obwohl die globalen Indizes verschieden sind.
    expect(ledColor(s, s.sections[1], 5, 2, 1.5), ledColor(s, s.sections[0], 5, 2, 1.5));
  });
}
