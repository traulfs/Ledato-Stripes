import 'dart:ui';

/// Tastet die Form eines Stripes ab: pro Kontrollsegment eine Teil-Polylinie.
///
/// Bei [curved] wird eine Catmull-Rom-Kurve durch die Stützpunkte gelegt
/// (der Stripe "biegt" sich weich durch die Punkte). Sind erster und letzter
/// Punkt identisch, gilt die Form als geschlossen und ist auch am Übergang
/// glatt (z. B. Kreis/Ring).
List<List<Offset>> sampledSegments(
  List<Offset> pts,
  bool curved, {
  int samples = 16,
}) {
  if (pts.length < 2) return const [];
  if (!curved) {
    return [
      for (var i = 0; i < pts.length - 1; i++) [pts[i], pts[i + 1]],
    ];
  }
  final n = pts.length;
  final closed = n > 2 && (pts.first - pts.last).distance < 1e-6;
  Offset at(int i) {
    if (closed) {
      final m = n - 1; // letzter Punkt ist Duplikat des ersten
      return pts[((i % m) + m) % m];
    }
    return pts[i.clamp(0, n - 1)];
  }

  final result = <List<Offset>>[];
  for (var i = 0; i < n - 1; i++) {
    final p0 = at(i - 1), p1 = at(i), p2 = at(i + 1), p3 = at(i + 2);
    result.add([
      for (var j = 0; j <= samples; j++)
        _catmullRom(p0, p1, p2, p3, j / samples),
    ]);
  }
  return result;
}

/// Verbindet die Teil-Polylinien zu einer durchgehenden Polylinie.
List<Offset> flattenSegments(List<List<Offset>> segs) {
  final out = <Offset>[];
  for (final s in segs) {
    out.addAll(out.isEmpty ? s : s.skip(1));
  }
  return out;
}

Offset _catmullRom(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
  final t2 = t * t, t3 = t2 * t;
  double f(double a, double b, double c, double d) =>
      0.5 *
      (2 * b +
          (-a + c) * t +
          (2 * a - 5 * b + 4 * c - d) * t2 +
          (-a + 3 * b - 3 * c + d) * t3);
  return Offset(f(p0.dx, p1.dx, p2.dx, p3.dx), f(p0.dy, p1.dy, p2.dy, p3.dy));
}
