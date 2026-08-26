import 'package:flutter_test/flutter_test.dart';
import 'package:ledato_stripes/app_state.dart';
import 'package:ledato_stripes/model.dart';
import 'package:ledato_stripes/proto_mapper.dart';
import 'package:ledato_stripes/protobuf/ledato_stripes.pb.dart' as pb;

/// Schreibt die Szene als Protobuf und liest sie zurück — genau der Weg, den
/// auch die Konfigurationsdatei für die Firmware nimmt.
List<LedPage> _roundtrip(AppState st) => documentFromProto(
  pb.Document.fromBuffer(documentToProto(st.pages, 0).writeToBuffer()),
).pages;

void main() {
  late AppState st;

  setUp(() {
    st = AppState();
    st.contentAspect = 1.0;
    st.strips.clear();
  });

  test('createMatrix legt eine logische Matrix neben den Stripes an', () {
    final created = st.createMatrix(
      columns: 16,
      rows: 8,
      stripCount: 2,
      ledsPerMeter: 60,
    )!;

    expect(st.activePage.matrices.length, 1);
    final m = st.activePage.matrices.single;
    expect(m.columns, 16);
    expect(m.rows, 8);
    expect(m.ledsPerMeter, 60);
    expect(m.wiring, MatrixWiring.serpentine);
    expect(m.origin, MatrixOrigin.topLeft);
    expect(m.ledCount, 128);

    // Die Banks verweisen auf die erzeugten Stripes, in Stapelreihenfolge.
    expect(m.banks.length, 2);
    expect(m.banks[0].stripId, created[0].id);
    expect(m.banks[1].stripId, created[1].id);
    expect(m.banks[0].firstRow, 0);
    expect(m.banks[0].rowCount, 4);
    expect(m.banks[1].firstRow, 4);
    expect(m.banks[1].rowCount, 4);
  });

  test('ledIndexAt bildet Pixel im Mäander auf LED-Indizes ab', () {
    st.createMatrix(columns: 4, rows: 4, stripCount: 2, ledsPerMeter: 60);
    final m = st.activePage.matrices.single;

    // Zeile 0 (Bank 0, vorwärts): x läuft direkt auf den Index.
    expect(m.ledIndexAt(0, 0), (bank: 0, index: 0));
    expect(m.ledIndexAt(3, 0), (bank: 0, index: 3));
    // Zeile 1 (Bank 0, rückwärts): Index 4 liegt ganz rechts.
    expect(m.ledIndexAt(3, 1), (bank: 0, index: 4));
    expect(m.ledIndexAt(0, 1), (bank: 0, index: 7));
    // Zeile 2/3 gehören zum zweiten Stripe: dessen Zählung beginnt wieder
    // bei 0, weil er seine eigene Einspeisung hat.
    expect(m.ledIndexAt(0, 2), (bank: 1, index: 0));
    expect(m.ledIndexAt(3, 2), (bank: 1, index: 3));
    // Zeile 3 ist die zweite Zeile in Bank 1, läuft also rückwärts.
    expect(m.ledIndexAt(3, 3), (bank: 1, index: 4));
    expect(m.ledIndexAt(0, 3), (bank: 1, index: 7));

    // Außerhalb der Fläche gibt es kein Pixel.
    expect(m.ledIndexAt(-1, 0), isNull);
    expect(m.ledIndexAt(0, 4), isNull);
    expect(m.ledIndexAt(4, 0), isNull);
  });

  test('progressive Verdrahtung lässt jede Zeile an derselben Kante beginnen', () {
    final m = LedMatrix(
      id: 'm',
      name: 'test',
      columns: 4,
      rows: 2,
      ledsPerMeter: 60,
      wiring: MatrixWiring.progressive,
      banks: [MatrixBank(stripId: 's', firstRow: 0, rowCount: 2)],
    );
    expect(m.ledIndexAt(0, 0), (bank: 0, index: 0));
    expect(m.ledIndexAt(0, 1), (bank: 0, index: 4));
    expect(m.ledIndexAt(3, 1), (bank: 0, index: 7));
  });

  test('Matrix überlebt Speichern und Laden vollständig', () {
    st.createMatrix(columns: 32, rows: 8, stripCount: 4, ledsPerMeter: 144);
    final before = st.activePage.matrices.single;

    final m = _roundtrip(st).single.matrices.single;
    expect(m.id, before.id);
    expect(m.name, before.name);
    expect(m.columns, 32);
    expect(m.rows, 8);
    expect(m.ledsPerMeter, 144);
    expect(m.wiring, MatrixWiring.serpentine);
    expect(m.origin, MatrixOrigin.topLeft);
    expect(m.banks.length, 4);
    for (var i = 0; i < 4; i++) {
      expect(m.banks[i].stripId, before.banks[i].stripId);
      expect(m.banks[i].firstRow, i * 2);
      expect(m.banks[i].rowCount, 2);
    }
    // Die Bank-Verweise finden ihre Stripes in der geladenen Szene wieder.
    final loadedStrips = _roundtrip(st).single.strips;
    for (final bank in m.banks) {
      expect(loadedStrips.any((s) => s.id == bank.stripId), isTrue);
    }
  });

  test('nicht-serpentine Verdrahtung und Ursprung überstehen den Roundtrip', () {
    st.createMatrix(columns: 4, rows: 2, stripCount: 1, ledsPerMeter: 30);
    st.activePage.matrices.single
      ..wiring = MatrixWiring.progressive
      ..origin = MatrixOrigin.bottomRight;

    final m = _roundtrip(st).single.matrices.single;
    expect(m.wiring, MatrixWiring.progressive);
    expect(m.origin, MatrixOrigin.bottomRight);
  });

  test('Löschen eines Matrix-Stripes entfernt die Matrix', () {
    final created = st.createMatrix(
      columns: 8,
      rows: 4,
      stripCount: 2,
      ledsPerMeter: 60,
    )!;
    expect(st.activePage.matrices, hasLength(1));

    st.removeStrip(created[1]);
    expect(st.activePage.matrices, isEmpty);
    // Der andere Stripe bleibt als gewöhnlicher Stripe bestehen.
    expect(st.strips.length, 1);
    expect(st.strips.single.id, created[0].id);
  });

  test('Seite duplizieren nimmt die Matrix mit', () async {
    st.createMatrix(columns: 8, rows: 4, stripCount: 1, ledsPerMeter: 60);
    await st.addPage();

    expect(st.activePage.matrices, hasLength(1));
    final m = st.activePage.matrices.single;
    // Die Bank zeigt auf einen Stripe, den es in der neuen Seite gibt.
    expect(st.strips.any((s) => s.id == m.banks.single.stripId), isTrue);
  });

  test('alte Konfigurationen ohne Matrix laden unverändert', () {
    // Ein Dokument, wie es vor Einführung des Feldes geschrieben wurde:
    // Page mit Stripes, ohne matrices.
    final doc = pb.Document(
      schemaVersion: kSchemaVersion,
      activePageIndex: 0,
      pages: [
        pb.Page(
          id: 'p',
          name: 'Alt',
          strips: [
            pb.Strip(
              id: 's',
              name: 'Stripe 1',
              ledsPerMeter: 60,
              enabled: true,
              sections: [pb.Section(ledCount: 60)],
            ),
          ],
        ),
      ],
    );
    final page = documentFromProto(
      pb.Document.fromBuffer(doc.writeToBuffer()),
    ).pages.single;
    expect(page.matrices, isEmpty);
    expect(page.strips.single.continuousEffect, isFalse);
  });
}
