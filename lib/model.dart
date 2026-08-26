import 'dart:math' as math;
import 'dart:ui';

/// Maximalwerte laut Anforderung.
const int kMaxStrips = 8;
const int kMaxLedsPerStrip = 300;

/// Verfügbare LED-Dichten (Pixel pro Meter), z. B. WS2815-Varianten.
const List<int> kLedDensities = [30, 60, 144];

/// LED-Dichte des Ausrichtungsrasters im Bearbeiten-Modus — fest bei 60
/// LEDs/m, unabhängig von der Dichte des gerade gewählten Stripes.
const int kGridLedsPerMeter = 60;

/// Reale Breite eines LED-Stripes in Millimetern — bestimmt zusammen mit
/// dem Maßstab (Bildbreite in Metern) die Darstellungsgröße der LEDs.
const double kStripWidthMm = 12.0;

/// Rundet einen Winkel (Radiant) auf die nächste ganze Gradzahl — der Winkel
/// eines Abschnitts ist immer nur in vollen Grad einstellbar, egal ob per
/// Schieberegler, Zahleneingabe oder Ziehen am Drehgriff auf der Leinwand.
double snapAngleToWholeDegrees(double radians) =>
    (radians * 180 / math.pi).roundToDouble() * (math.pi / 180);

enum EffectType {
  solid('Statische Farbe'),
  gradient('Farbverlauf'),
  rainbow('Regenbogen'),
  chase('Lauflicht'),
  theater('Theater-Chase'),
  scanner('Scanner (Knight Rider)'),
  colorWipe('Farbwischer'),
  wave('Welle'),
  breathe('Atmen'),
  blink('Wechselblinken'),
  strobe('Stroboskop'),
  sparkle('Funkeln'),
  confetti('Konfetti'),
  fire('Feuer');

  const EffectType(this.label);
  final String label;
}

/// Ein frei platzierbares, gerades Teilstück eines Stripes: Anfangspunkt
/// (normalisierte Bildkoordinate, 0..1) plus Winkel — die Länge ergibt sich
/// aus LED-Anzahl ÷ Stripe-Dichte, es gibt also keine unabhängig formbare
/// Kurve. Mehrere Abschnitte eines Stripes müssen nicht zusammenhängen
/// (z. B. Lücke hinter einem Schrank, Ecke ohne direkten Sichtbezug) —
/// elektrisch/adressierungstechnisch bilden sie dennoch einen einzigen
/// durchgehenden Stripe. Jeder Abschnitt hat seine eigene komplette Optik
/// (Effekt, Farbe(n), Helligkeit, Tempo, Richtung) und läuft damit
/// unabhängig von den anderen Abschnitten — wie ein eigener kleiner Stripe.
class StripSection {
  StripSection({
    required this.start,
    this.angle = 0.0,
    this.ledCount = 60,
    this.effect = EffectType.solid,
    this.color = const Color(0xFFFF6000),
    this.color2 = const Color(0xFF0040FF),
    this.brightness = 1.0,
    this.speed = 0.5,
    this.reversed = false,
  });

  Offset start; // normalisierte Bildkoordinate (0..1) von LED 1
  double angle; // Radiant im metergetreuen Raum; 0 = nach rechts
  int ledCount; // LEDs in diesem Abschnitt
  EffectType effect;
  Color color;
  Color color2;
  double brightness; // 0..1
  double speed; // 0..1
  bool reversed;

  StripSection clone() => StripSection(
    start: start,
    angle: angle,
    ledCount: ledCount,
    effect: effect,
    color: color,
    color2: color2,
    brightness: brightness,
    speed: speed,
    reversed: reversed,
  );
}

/// Ein LED-Stripe: Name, LED-Dichte und Ein/Aus-Schalter, sowie einer oder
/// mehreren Abschnitten (Sections). Der Stripe selbst hat keine Farbe/Optik
/// — das liegt vollständig bei den Abschnitten. LEDs werden über alle
/// Abschnitte hinweg fortlaufend nummeriert und angesteuert, so wie ein real
/// durchverkabelter Stripe.
class LedStrip {
  LedStrip({
    required this.id,
    required this.name,
    this.ledsPerMeter = 60,
    required this.sections,
    this.enabled = true,
    this.continuousEffect = false,
  });

  final String id;
  String name;
  int
  ledsPerMeter; // LED-Dichte: 30, 60 oder 144 Pixel pro Meter (gesamter Stripe)
  List<StripSection> sections;
  bool enabled;

  /// Lässt Effekte über alle Abschnitte hinweg durchlaufen, als wäre der
  /// Stripe ein einziges langes Stück — ein Lauflicht wandert dann z. B.
  /// durch eine im Mäander verlegte Matrix, statt in jeder Zeile neu zu
  /// beginnen. Aus (Standard) rechnet jeder Abschnitt für sich, was für
  /// unabhängig platzierte Abschnitte meist das Gewollte ist.
  bool continuousEffect;

  /// Gesamtzahl LEDs über alle Abschnitte hinweg.
  int get ledCount => sections.fold(0, (sum, sec) => sum + sec.ledCount);

  /// Tiefe Kopie für Undo/Redo-Schnappschüsse.
  LedStrip clone() => LedStrip(
    id: id,
    name: name,
    ledsPerMeter: ledsPerMeter,
    sections: [for (final sec in sections) sec.clone()],
    enabled: enabled,
    continuousEffect: continuousEffect,
  );

  /// Liest eine Konfiguration im alten JSON-Format (vor Einführung von YAML,
  /// Abschnitten und dem Start+Winkel-Modell) für die einmalige Migration:
  /// eine flache Punkteliste wird zu Anfangspunkt + Winkel (aus erstem und
  /// letztem Punkt) mit der damaligen Stripe-LED-Anzahl, dem damaligen
  /// Effekt und der damaligen Optik (die zu dieser Zeit noch stripeweit war).
  factory LedStrip.fromJson(Map<String, dynamic> json) {
    final raw = (json['points'] as List).cast<num>();
    final points = <Offset>[
      for (var i = 0; i + 1 < raw.length; i += 2)
        Offset(raw[i].toDouble(), raw[i + 1].toDouble()),
    ];
    final start = points.isNotEmpty ? points.first : const Offset(0.1, 0.5);
    final angle = points.length >= 2
        ? math.atan2(
            points.last.dy - points.first.dy,
            points.last.dx - points.first.dx,
          )
        : 0.0;
    return LedStrip(
      id: json['id'] as String,
      name: json['name'] as String,
      ledsPerMeter: (json['ledsPerMeter'] as num?)?.toInt() ?? 60,
      enabled: json['enabled'] as bool? ?? true,
      sections: [
        StripSection(
          start: start,
          angle: angle,
          ledCount: ((json['ledCount'] as num?)?.toInt() ?? 60).clamp(
            1,
            kMaxLedsPerStrip,
          ),
          effect:
              EffectType.values.asNameMap()[json['effect']] ?? EffectType.solid,
          color: Color((json['color'] as num).toInt()),
          color2: Color((json['color2'] as num).toInt()),
          brightness: (json['brightness'] as num).toDouble(),
          speed: (json['speed'] as num).toDouble(),
          reversed: json['reversed'] as bool? ?? false,
        ),
      ],
    );
  }
}

/// Verdrahtungsart der Zeilen einer Matrix.
enum MatrixWiring {
  /// Mäander: jede zweite Zeile eines Stripes läuft rückwärts, das Kabel
  /// schlängelt sich ohne Rückleitung durch den Block.
  serpentine('Mäander'),

  /// Jede Zeile beginnt an derselben Kante, zwischen den Zeilen liegt eine
  /// Rückleitung.
  progressive('Zeilenweise');

  const MatrixWiring(this.label);
  final String label;
}

/// Ecke, in der Zeile 0 / Spalte 0 liegt und in der der erste Stripe
/// eingespeist wird.
enum MatrixOrigin {
  topLeft('Oben links'),
  topRight('Oben rechts'),
  bottomLeft('Unten links'),
  bottomRight('Unten rechts');

  const MatrixOrigin(this.label);
  final String label;
}

/// Ein Stripe als zusammenhängender Zeilenblock einer Matrix.
class MatrixBank {
  MatrixBank({
    required this.stripId,
    required this.firstRow,
    required this.rowCount,
  });

  final String stripId;
  final int firstRow;
  final int rowCount;

  MatrixBank clone() =>
      MatrixBank(stripId: stripId, firstRow: firstRow, rowCount: rowCount);
}

/// Logische LED-Matrix aus einem oder mehreren Stripes.
///
/// Bewusst nur die *logische* Struktur: wo die Zeilen in der Szene liegen,
/// steht weiterhin in den Stripes und ihren Abschnitten — die bleiben damit
/// frei verschiebbar. Hier steht, was ein Controller braucht, um (x, y) auf
/// einen LED-Index abzubilden, siehe [ledIndexAt]. Genau diese Angaben
/// landen im Protobuf und damit in der Konfiguration für die Firmware.
class LedMatrix {
  LedMatrix({
    required this.id,
    required this.name,
    required this.columns,
    required this.rows,
    required this.ledsPerMeter,
    required this.banks,
    this.wiring = MatrixWiring.serpentine,
    this.origin = MatrixOrigin.topLeft,
  });

  final String id;
  String name;
  int columns;
  int rows;
  MatrixWiring wiring;
  MatrixOrigin origin;

  /// LED-Dichte aller beteiligten Stripes; zugleich der Pixelabstand
  /// (Zeilenabstand = Spaltenabstand = 1 ÷ [ledsPerMeter] Meter).
  int ledsPerMeter;

  /// Die Stripes der Matrix, von der Ursprungsecke weg gestapelt. Die
  /// Position in dieser Liste + 1 ist die DDP-destination des Stripes.
  List<MatrixBank> banks;

  int get ledCount => columns * rows;

  /// Bank (Stripe) und LED-Index *innerhalb dieses Stripes* für ein Pixel —
  /// dieselbe Rechnung, die die Firmware anstellt. Gibt null zurück, wenn
  /// (x, y) außerhalb liegt oder keine Bank die Zeile abdeckt.
  ({int bank, int index})? ledIndexAt(int x, int y) {
    if (x < 0 || x >= columns || y < 0 || y >= rows) return null;
    for (var b = 0; b < banks.length; b++) {
      final bank = banks[b];
      if (y < bank.firstRow || y >= bank.firstRow + bank.rowCount) continue;
      final local = y - bank.firstRow;
      final backwards =
          wiring == MatrixWiring.serpentine && local.isOdd;
      final col = backwards ? columns - 1 - x : x;
      return (bank: b, index: local * columns + col);
    }
    return null;
  }

  LedMatrix clone() => LedMatrix(
    id: id,
    name: name,
    columns: columns,
    rows: rows,
    wiring: wiring,
    origin: origin,
    ledsPerMeter: ledsPerMeter,
    banks: [for (final b in banks) b.clone()],
  );
}

/// Eine vollständige, eigenständige Lichtszene: Stripes samt Hintergrund,
/// Maßstab und Darstellungseinstellungen. Der Player (siehe [AppState])
/// schaltet zwischen Pages um, jede mit ihrer eigenen Anzeigedauer.
class LedPage {
  LedPage({
    required this.id,
    required this.name,
    this.durationMs = 5000,
    this.sceneWidthMeters = 5.0,
    this.sceneAspect = 0.6,
    this.useImageAspect = true,
    this.backgroundPath,
    this.backgroundDim = 0.5,
    this.glow = 1.0,
    List<LedStrip>? strips,
    List<LedMatrix>? matrices,
  }) : strips = strips ?? [],
       matrices = matrices ?? [];

  final String id;
  String name;
  int durationMs; // Anzeigedauer im Player, in Millisekunden
  double sceneWidthMeters;
  double sceneAspect;
  bool useImageAspect;
  String? backgroundPath;
  double backgroundDim;
  double glow;
  List<LedStrip> strips;

  /// Logische Matrizen dieser Szene; jede verweist über [MatrixBank.stripId]
  /// auf ihre Stripes in [strips].
  List<LedMatrix> matrices;

  /// Tiefe Kopie für Undo/Redo-Schnappschüsse.
  LedPage clone() => LedPage(
    id: id,
    name: name,
    durationMs: durationMs,
    sceneWidthMeters: sceneWidthMeters,
    sceneAspect: sceneAspect,
    useImageAspect: useImageAspect,
    backgroundPath: backgroundPath,
    backgroundDim: backgroundDim,
    glow: glow,
    strips: [for (final s in strips) s.clone()],
    matrices: [for (final m in matrices) m.clone()],
  );
}
