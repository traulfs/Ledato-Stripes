import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'app_state.dart';
import 'effects.dart';
import 'model.dart';

/// Leinwand: zeichnet Hintergrundbild + Stripes (aus einem oder mehreren
/// geraden Abschnitten: Startpunkt + Winkel, Länge aus LED-Anzahl/Dichte)
/// und verarbeitet Gesten zum Platzieren (Startpunkt verschieben, per
/// Endgriff drehen) sowie Zoom & Pan der Ansicht (Pinch, Trackpad, Mausrad,
/// Ziehen auf freier Fläche).
class EditorCanvas extends StatefulWidget {
  const EditorCanvas({super.key, required this.state, required this.time});

  final AppState state;
  final ValueNotifier<double> time; // Simulationszeit in Sekunden

  @override
  State<EditorCanvas> createState() => _EditorCanvasState();
}

class _EditorCanvasState extends State<EditorCanvas> {
  static const double _hitRadius = 18;
  static const double _minZoom = 0.3;
  static const double _maxZoom = 8.0;

  // Ansichtstransformation: screen = world * _zoom + _view
  double _zoom = 1.0;
  Offset _view = Offset.zero;

  // Aktiver Drag: ein Abschnitt (verschieben oder drehen) oder die Ansicht.
  LedStrip? _dragStrip;
  int _dragSectionIndex = -1;
  bool _dragIsRotate = false;
  bool _panView = false;
  Offset _prevFocal = Offset.zero;
  double _prevScale = 1.0;

  Rect _contentRect =
      Rect.zero; // Bereich, auf den sich die 0..1-Koordinaten beziehen

  AppState get st => widget.state;

  /// Rechteck, in das das Hintergrundbild eingepasst wird (contain). Ohne
  /// Bild wird stattdessen [AppState.sceneAspect] als virtuelles
  /// Seitenverhältnis eingepasst — sonst wäre der Bildbereich genauso groß
  /// wie das Leinwand-Widget und damit von Fenster-/Bildschirmform des
  /// jeweiligen Geräts abhängig: dieselbe Konfiguration sähe je nach Gerät
  /// (breites Fenster vs. hochkantiges Handy-Display) völlig verzerrt aus,
  /// da Winkel und Abstände relativ zu diesem Seitenverhältnis interpretiert
  /// werden (siehe [AppState.sectionEnd]).
  Rect _computeContentRect(Size size) {
    final img = st.background;
    final refSize = img != null
        ? Size(img.width.toDouble(), img.height.toDouble())
        : Size(1, st.sceneAspect);
    final fitted = applyBoxFit(BoxFit.contain, refSize, size).destination;
    return Alignment.center.inscribe(fitted, Offset.zero & size);
  }

  Offset _screenToWorld(Offset p) => (p - _view) / _zoom;

  Offset _toCanvas(Offset norm) => Offset(
    _contentRect.left + norm.dx * _contentRect.width,
    _contentRect.top + norm.dy * _contentRect.height,
  );

  /// Abstand Punkt–Strecke.
  static double _distToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 == 0) return (p - a).distance;
    var t = ((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2;
    t = t.clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  /// Findet Stripe, Abschnitt und Griff-Art unter dem Weltpunkt [pos].
  /// `isRotate == true` bedeutet: Endgriff getroffen (dreht den Abschnitt um
  /// seinen Startpunkt), sonst Start-Griff oder Linie (verschiebt den
  /// gesamten Abschnitt). Der Trefferradius bleibt unabhängig vom Zoom
  /// konstant auf dem Bildschirm.
  (LedStrip, int, bool)? _hitTest(Offset pos) {
    final r = _hitRadius / _zoom;
    // Zuerst Griffe des gerade ausgewählten Abschnitts bevorzugen.
    final sel = st.selected;
    if (sel != null && sel.sections.isNotEmpty) {
      final si = st.selectedSectionIndex.clamp(0, sel.sections.length - 1);
      final sec = sel.sections[si];
      final endC = _toCanvas(st.sectionEnd(sel, sec));
      if ((endC - pos).distance < r) return (sel, si, true);
      final startC = _toCanvas(sec.start);
      if ((startC - pos).distance < r) return (sel, si, false);
    }
    for (final s in st.strips.reversed) {
      for (var si = 0; si < s.sections.length; si++) {
        final sec = s.sections[si];
        final startC = _toCanvas(sec.start);
        final endC = _toCanvas(st.sectionEnd(s, sec));
        if ((endC - pos).distance < r) return (s, si, true);
        if ((startC - pos).distance < r) return (s, si, false);
        if (_distToSegment(pos, startC, endC) < r) return (s, si, false);
      }
    }
    return null;
  }

  // ---------- Zoom & Pan ----------

  /// Zoomt um [factor] und hält dabei den Bildschirmpunkt [focal] fest.
  void _applyZoom(double factor, Offset focal) {
    final newZoom = (_zoom * factor).clamp(_minZoom, _maxZoom);
    if (newZoom == _zoom) return;
    setState(() {
      _view = focal - (focal - _view) * (newZoom / _zoom);
      _zoom = newZoom;
    });
  }

  void _resetView() => setState(() {
    _zoom = 1.0;
    _view = Offset.zero;
  });

  void _onPointerSignal(PointerSignalEvent e) {
    if (e is PointerScrollEvent) {
      _applyZoom(math.exp(-e.scrollDelta.dy * 0.002), e.localPosition);
    }
  }

  // ---------- Gesten ----------

  void _onScaleStart(ScaleStartDetails d) {
    _prevFocal = d.localFocalPoint;
    _prevScale = 1.0;
    _dragStrip = null;
    _dragSectionIndex = -1;
    _dragIsRotate = false;
    _panView = true;

    // Ein Finger/Mauszeiger im Bearbeiten-Modus: Abschnitt greifen.
    // Trackpad-Gesten (Zwei-Finger-Scroll/Pinch) steuern immer die Ansicht.
    if (st.editMode &&
        d.pointerCount <= 1 &&
        d.kind != PointerDeviceKind.trackpad) {
      final hit = _hitTest(_screenToWorld(d.localFocalPoint));
      if (hit != null) {
        _dragStrip = hit.$1;
        _dragSectionIndex = hit.$2;
        _dragIsRotate = hit.$3;
        _panView = false;
        st.select(hit.$1.id);
        st.selectSection(hit.$2);
      }
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final focal = d.localFocalPoint;
    final s = _dragStrip;

    if (s != null &&
        _dragSectionIndex >= 0 &&
        _dragSectionIndex < s.sections.length) {
      final sec = s.sections[_dragSectionIndex];
      final world = _screenToWorld(focal);
      if (_dragIsRotate) {
        // Nur der Winkel ändert sich, um den festen Startpunkt herum — die
        // Länge bleibt exakt LED-Anzahl/Dichte (nicht frei ziehbar).
        final startC = _toCanvas(sec.start);
        final dx = world.dx - startC.dx;
        final dy = world.dy - startC.dy;
        if (dx != 0 || dy != 0) {
          sec.angle = snapAngleToWholeDegrees(math.atan2(dy, dx));
        }
      } else {
        // Ganzen Abschnitt verschieben — andere Abschnitte bleiben an Ort
        // und Stelle.
        final delta = (focal - _prevFocal) / _zoom;
        final norm = Offset(
          delta.dx / _contentRect.width,
          delta.dy / _contentRect.height,
        );
        sec.start = Offset(
          (sec.start.dx + norm.dx).clamp(0.0, 1.0),
          (sec.start.dy + norm.dy).clamp(0.0, 1.0),
        );
      }
      _prevFocal = focal;
      st.changed();
      return;
    }

    if (_panView) {
      // Zoom-Anteil (Pinch/Trackpad) um den Fokuspunkt …
      if (d.scale != _prevScale && d.scale > 0) {
        _applyZoom(d.scale / _prevScale, focal);
        _prevScale = d.scale;
      }
      // … plus Pan-Anteil.
      final delta = focal - _prevFocal;
      if (delta != Offset.zero) {
        setState(() => _view += delta);
      }
      _prevFocal = focal;
    }
  }

  void _onScaleEnd() {
    _dragStrip = null;
    _dragSectionIndex = -1;
    _dragIsRotate = false;
    _panView = false;
  }

  void _onTapUp(TapUpDetails d) {
    if (!st.editMode) return;
    final hit = _hitTest(_screenToWorld(d.localPosition));
    st.select(hit?.$1.id);
    if (hit != null) st.selectSection(hit.$2);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _contentRect = _computeContentRect(constraints.biggest);
        // Seitenverhältnis für die Winkel-Umrechnung bereitstellen.
        st.contentAspect = _contentRect.height / _contentRect.width;
        final center = constraints.biggest.center(Offset.zero);
        return Stack(
          children: [
            Positioned.fill(
              child: Listener(
                onPointerSignal: _onPointerSignal,
                child: GestureDetector(
                  onScaleStart: _onScaleStart,
                  onScaleUpdate: _onScaleUpdate,
                  onScaleEnd: (_) => _onScaleEnd(),
                  onTapUp: _onTapUp,
                  child: ClipRect(
                    child: CustomPaint(
                      size: constraints.biggest,
                      painter: _StripPainter(
                        state: st,
                        time: widget.time,
                        contentRect: _contentRect,
                        zoom: _zoom,
                        view: _view,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Zoom-Steuerung
            Positioned(
              right: 12,
              bottom: 12,
              child: Card(
                color: Colors.black.withValues(alpha: 0.55),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Herauszoomen',
                        icon: const Icon(Icons.remove, size: 18),
                        onPressed: () => _applyZoom(1 / 1.25, center),
                      ),
                      SizedBox(
                        width: 48,
                        child: Text(
                          '${(_zoom * 100).round()} %',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Hineinzoomen',
                        icon: const Icon(Icons.add, size: 18),
                        onPressed: () => _applyZoom(1.25, center),
                      ),
                      IconButton(
                        tooltip: 'Ansicht zurücksetzen (100 %)',
                        icon: const Icon(Icons.fit_screen_outlined, size: 18),
                        onPressed: _zoom == 1.0 && _view == Offset.zero
                            ? null
                            : _resetView,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StripPainter extends CustomPainter {
  _StripPainter({
    required this.state,
    required this.time,
    required this.contentRect,
    required this.zoom,
    required this.view,
  }) : super(repaint: Listenable.merge([state, time]));

  final AppState state;
  final ValueNotifier<double> time;
  final Rect contentRect;
  final double zoom;
  final Offset view;

  Offset _toCanvas(Offset norm) => Offset(
    contentRect.left + norm.dx * contentRect.width,
    contentRect.top + norm.dy * contentRect.height,
  );

  /// Platziert die LEDs jedes Abschnitts gleichmäßig auf der geraden Strecke
  /// von Start- zu Endpunkt (Anfang = LED 1, Ende = letzte LED, kein
  /// zusätzlicher Rand). Die Ergebnisliste ist die fortlaufende
  /// Adressierung des gesamten Stripes: Abschnitt 1 zuerst, dann Abschnitt 2
  /// usw. Jeder Eintrag trägt seinen Abschnitt und lokalen Index mit, damit
  /// jeder Abschnitt seinen eigenen Effekt unabhängig von den anderen
  /// berechnen kann.
  List<(Offset pos, StripSection section, int localIndex)> _placedLeds(
    LedStrip s,
  ) {
    final result = <(Offset, StripSection, int)>[];
    for (final sec in s.sections) {
      if (sec.ledCount <= 0) continue;
      final startC = _toCanvas(sec.start);
      final endC = _toCanvas(state.sectionEnd(s, sec));
      final n = math.min(sec.ledCount, kMaxLedsPerStrip - result.length);
      for (var i = 0; i < n; i++) {
        final t = n <= 1 ? 0.0 : i / (n - 1);
        result.add((Offset.lerp(startC, endC, t)!, sec, i));
      }
    }
    return result;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF101014),
    );

    canvas.save();
    canvas.translate(view.dx, view.dy);
    canvas.scale(zoom);

    // Sichtbarer Ausschnitt in Weltkoordinaten (für das Raster).
    final visible = Rect.fromLTWH(
      -view.dx / zoom,
      -view.dy / zoom,
      size.width / zoom,
      size.height / zoom,
    );

    // Hintergrundbild, per backgroundDim abgedunkelt.
    final img = state.background;
    if (img != null) {
      paintImage(
        canvas: canvas,
        rect: contentRect,
        image: img,
        fit: BoxFit.fill,
        opacity: 1.0 - state.backgroundDim * 0.9,
        filterQuality: FilterQuality.medium,
      );
    } else if (state.backgroundDim < 1) {
      _paintGrid(canvas, visible);
    }

    if (state.editMode && state.showLedGrid) {
      _paintLedPitchGrid(canvas, visible);
    }

    final t = time.value;
    for (final s in state.strips) {
      final leds = _placedLeds(s);
      if (leds.isEmpty) continue;

      final ledR = state.ledSize;
      final glowR = ledR * (1.5 + state.glow * 2.5);
      final glowPaint = Paint()
        ..blendMode = BlendMode.plus
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowR * 0.6);
      final corePaint = Paint()..blendMode = BlendMode.plus;

      for (var globalIndex = 0; globalIndex < leds.length; globalIndex++) {
        final (pos, sec, localIndex) = leds[globalIndex];
        final c =
            state.ddpColorFor(s.id, globalIndex) ??
            (state.simulate
                ? ledColor(s, sec, sec.ledCount, localIndex, t)
                : ledColor(s, sec, sec.ledCount, localIndex, 0));
        if (c.a == 0) continue;
        final lum = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
        if (state.glow > 0 && lum > 0.02) {
          glowPaint.color = c.withValues(alpha: 0.55 * math.min(1, lum + 0.2));
          canvas.drawCircle(pos, glowR, glowPaint);
        }
        corePaint.color = c;
        canvas.drawCircle(pos, ledR * 0.55, corePaint);
        // Heller Kern für "überstrahlte" LEDs.
        if (lum > 0.6) {
          corePaint.color = Color.lerp(
            c,
            const Color(0xFFFFFFFF),
            0.6,
          )!.withValues(alpha: 0.9);
          canvas.drawCircle(pos, ledR * 0.3, corePaint);
        }
      }

      if (state.editMode) _paintEditOverlay(canvas, s, leds);
    }

    canvas.restore();
  }

  /// Editier-Overlay: Linien und Griffe behalten unabhängig vom Zoom ihre
  /// Bildschirmgröße (alle Maße durch [zoom] geteilt).
  void _paintEditOverlay(
    Canvas canvas,
    LedStrip s,
    List<(Offset pos, StripSection section, int localIndex)> leds,
  ) {
    final isSelStrip = s.id == state.selectedId;
    final selSectionIdx = isSelStrip && s.sections.isNotEmpty
        ? state.selectedSectionIndex.clamp(0, s.sections.length - 1)
        : -1;

    Offset? prevEnd;
    for (var si = 0; si < s.sections.length; si++) {
      final sec = s.sections[si];
      final isSelSection = si == selSectionIdx;
      final startC = _toCanvas(sec.start);
      final endC = _toCanvas(state.sectionEnd(s, sec));

      final line = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (isSelSection ? 2 : (isSelStrip ? 1.4 : 1)) / zoom
        ..color = isSelSection
            ? const Color(0xCCFFFFFF)
            : (isSelStrip ? const Color(0x88FFFFFF) : const Color(0x44FFFFFF));
      canvas.drawLine(startC, endC, line);

      // Gestrichelte Verbindung zur vorherigen Abschnitts-Endstelle: rein
      // informativ, markiert elektrische Kontinuität ohne Sichtbezug.
      if (isSelStrip && prevEnd != null) {
        _drawDashedLine(canvas, prevEnd, startC);
      }
      prevEnd = endC;

      // Start-Griff (verschiebt den Abschnitt).
      canvas.drawCircle(
        startC,
        6 / zoom,
        Paint()
          ..color = isSelSection
              ? const Color(0xFF2196F3)
              : const Color(0x662196F3),
      );
      canvas.drawCircle(
        startC,
        6 / zoom,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 / zoom
          ..color = Colors.white70,
      );
      // End-/Dreh-Griff (dreht den Abschnitt um den Startpunkt).
      canvas.drawCircle(
        endC,
        5 / zoom,
        Paint()
          ..color = isSelSection
              ? const Color(0xFFFF9800)
              : const Color(0x66FF9800),
      );
      canvas.drawCircle(
        endC,
        5 / zoom,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 / zoom
          ..color = Colors.white70,
      );
    }

    // Richtungsmarkierung: Anfang (Datenanschluss) als Dreieck — markiert den
    // Beginn von LED 1 im ersten Abschnitt, nicht jeden Abschnittsanfang.
    if (leds.length >= 2) {
      final a = leds.first.$1;
      final dir = (leds[1].$1 - a);
      final ang = math.atan2(dir.dy, dir.dx);
      canvas.save();
      canvas.translate(a.dx, a.dy);
      canvas.rotate(ang);
      canvas.scale(1 / zoom);
      final tri = Path()
        ..moveTo(-10, -6)
        ..lineTo(-2, 0)
        ..lineTo(-10, 6)
        ..close();
      canvas.drawPath(
        tri,
        Paint()..color = isSelStrip ? Colors.white : Colors.white38,
      );
      canvas.restore();
    }
  }

  void _drawDashedLine(Canvas canvas, Offset a, Offset b) {
    const dashLen = 6.0, gapLen = 4.0;
    final total = (b - a).distance;
    if (total < 1) return;
    final dir = (b - a) / total;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 / zoom
      ..color = const Color(0x99FFC107);
    var dist = 0.0;
    while (dist < total) {
      final segEnd = math.min(dist + dashLen, total);
      canvas.drawLine(a + dir * dist, a + dir * segEnd, paint);
      dist = segEnd + gapLen;
    }
  }

  /// Ausrichtungsraster: Linien im exakten Abstand der LED-Teilung bei
  /// [kGridLedsPerMeter] LEDs/m, als Platzierungshilfe unabhängig von der
  /// Dichte des gerade gewählten Stripes. Meter- und Bildpixel-Raum sind
  /// gleichförmig verbunden (siehe [AppState.sectionEnd]), daher ist der
  /// Pixelabstand pro Meter in x und y identisch.
  void _paintLedPitchGrid(Canvas canvas, Rect visible) {
    final pxPerMeter = contentRect.width / state.sceneWidthMeters;
    if (pxPerMeter <= 0) return;
    final step = pxPerMeter / kGridLedsPerMeter;
    if (step * zoom < 3) return; // zu fein, um sinnvoll dargestellt zu werden
    final area = contentRect.intersect(visible);
    if (area.isEmpty) return;
    final p = Paint()
      ..color = const Color(0x33FFFFFF)
      ..strokeWidth = 1 / zoom;
    var x =
        contentRect.left +
        ((area.left - contentRect.left) / step).floor() * step;
    for (; x <= area.right; x += step) {
      canvas.drawLine(Offset(x, area.top), Offset(x, area.bottom), p);
    }
    var y =
        contentRect.top + ((area.top - contentRect.top) / step).floor() * step;
    for (; y <= area.bottom; y += step) {
      canvas.drawLine(Offset(area.left, y), Offset(area.right, y), p);
    }
  }

  /// Platzhalter-Raster ohne Hintergrundbild, auf [contentRect] begrenzt
  /// (den durch [AppState.sceneAspect] festgelegten Szenenbereich), damit
  /// dessen Grenzen sichtbar bleiben statt das ganze Fenster zu füllen.
  void _paintGrid(Canvas canvas, Rect visible) {
    final area = contentRect.intersect(visible);
    if (area.isEmpty) return;
    final p = Paint()
      ..color = const Color(0x14FFFFFF)
      ..strokeWidth = 1 / zoom;
    const step = 40.0;
    final x0 =
        contentRect.left +
        ((area.left - contentRect.left) / step).floor() * step;
    final y0 =
        contentRect.top + ((area.top - contentRect.top) / step).floor() * step;
    for (var x = x0; x < area.right; x += step) {
      canvas.drawLine(Offset(x, area.top), Offset(x, area.bottom), p);
    }
    for (var y = y0; y < area.bottom; y += step) {
      canvas.drawLine(Offset(area.left, y), Offset(area.right, y), p);
    }
    canvas.drawRect(
      contentRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 / zoom
        ..color = const Color(0x33FFFFFF),
    );
  }

  @override
  bool shouldRepaint(covariant _StripPainter old) =>
      old.contentRect != contentRect ||
      old.state != state ||
      old.zoom != zoom ||
      old.view != view;
}
