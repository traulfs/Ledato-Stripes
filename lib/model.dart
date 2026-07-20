import 'dart:ui';

/// Maximalwerte laut Anforderung.
const int kMaxStrips = 8;
const int kMaxLedsPerStrip = 300;

/// Verfügbare LED-Dichten (Pixel pro Meter), z. B. WS2815-Varianten.
const List<int> kLedDensities = [30, 60, 144];

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

/// Form-Vorlagen, die die Stützpunkte eines Stripes ersetzen.
enum StripShape {
  line('Linie'),
  rect('Rechteck'),
  circle('Kreis'),
  zigzag('Zickzack');

  const StripShape(this.label);
  final String label;
}

/// Ein LED-Stripe: Verlauf als Polylinie in normalisierten
/// Bildkoordinaten (0..1 relativ zum Hintergrundbild bzw. zur Leinwand).
class LedStrip {
  LedStrip({
    required this.id,
    required this.name,
    this.ledsPerMeter = 60,
    this.ledCount = 60,
    required this.points,
    this.effect = EffectType.solid,
    this.color = const Color(0xFFFF6000),
    this.color2 = const Color(0xFF0040FF),
    this.brightness = 1.0,
    this.speed = 0.5,
    this.reversed = false,
    this.enabled = true,
    this.curved = false,
  });

  final String id;
  String name;
  int ledsPerMeter; // LED-Dichte: 30, 60 oder 144 Pixel pro Meter
  int ledCount; // Anzahl LEDs; die Länge ergibt sich als ledCount / ledsPerMeter
  List<Offset> points;
  EffectType effect;
  Color color;
  Color color2;
  double brightness; // 0..1
  double speed; // 0..1
  bool reversed;
  bool enabled;
  bool curved; // Kurve (Spline) durch die Punkte statt gerader Segmente

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ledsPerMeter': ledsPerMeter,
        'ledCount': ledCount,
        'points': points.expand((p) => [p.dx, p.dy]).toList(),
        'effect': effect.name,
        'color': color.toARGB32(),
        'color2': color2.toARGB32(),
        'brightness': brightness,
        'speed': speed,
        'reversed': reversed,
        'enabled': enabled,
        'curved': curved,
      };

  factory LedStrip.fromJson(Map<String, dynamic> json) {
    final raw = (json['points'] as List).cast<num>();
    final points = <Offset>[
      for (var i = 0; i + 1 < raw.length; i += 2)
        Offset(raw[i].toDouble(), raw[i + 1].toDouble()),
    ];
    return LedStrip(
      id: json['id'] as String,
      name: json['name'] as String,
      ledsPerMeter: (json['ledsPerMeter'] as num?)?.toInt() ?? 60,
      ledCount:
          ((json['ledCount'] as num?)?.toInt() ?? 60).clamp(1, kMaxLedsPerStrip),
      points: points,
      effect: EffectType.values.asNameMap()[json['effect']] ?? EffectType.solid,
      color: Color((json['color'] as num).toInt()),
      color2: Color((json['color2'] as num).toInt()),
      brightness: (json['brightness'] as num).toDouble(),
      speed: (json['speed'] as num).toDouble(),
      reversed: json['reversed'] as bool? ?? false,
      enabled: json['enabled'] as bool? ?? true,
      curved: json['curved'] as bool? ?? false,
    );
  }
}
