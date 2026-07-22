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
  });

  final String id;
  String name;
  int
  ledsPerMeter; // LED-Dichte: 30, 60 oder 144 Pixel pro Meter (gesamter Stripe)
  List<StripSection> sections;
  bool enabled;

  /// Gesamtzahl LEDs über alle Abschnitte hinweg.
  int get ledCount => sections.fold(0, (sum, sec) => sum + sec.ledCount);

  /// Tiefe Kopie für Undo/Redo-Schnappschüsse.
  LedStrip clone() => LedStrip(
    id: id,
    name: name,
    ledsPerMeter: ledsPerMeter,
    sections: [for (final sec in sections) sec.clone()],
    enabled: enabled,
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
