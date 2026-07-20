import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'app_state.dart';
import 'effects.dart';
import 'geometry.dart';
import 'model.dart';

/// Leinwand: zeichnet Hintergrundbild + Stripes und verarbeitet Gesten
/// zum Platzieren (Punkte ziehen, Stripe verschieben, Punkte einfügen/löschen)
/// sowie Zoom & Pan der Ansicht (Pinch, Trackpad, Mausrad, Ziehen auf
/// freier Fläche).
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

  // Aktiver Drag: entweder ein einzelner Punkt, der ganze Stripe oder die Ansicht.
  LedStrip? _dragStrip;
  int _dragPointIndex = -1;
  bool _panView = false;
  Offset _prevFocal = Offset.zero;
  double _prevScale = 1.0;

  Rect _contentRect = Rect.zero; // Bereich, auf den sich die 0..1-Koordinaten beziehen

  AppState get st => widget.state;

  /// Rechteck, in das das Hintergrundbild eingepasst wird (contain).
  Rect _computeContentRect(Size size) {
    final img = st.background;
    if (img == null) return Offset.zero & size;
    final fitted = applyBoxFit(
      BoxFit.contain,
      Size(img.width.toDouble(), img.height.toDouble()),
      size,
    ).destination;
    return Alignment.center.inscribe(fitted, Offset.zero & size);
  }

  Offset _screenToWorld(Offset p) => (p - _view) / _zoom;

  Offset _toCanvas(Offset norm) => Offset(
        _contentRect.left + norm.dx * _contentRect.width,
        _contentRect.top + norm.dy * _contentRect.height,
      );

  Offset _toNorm(Offset world) => Offset(
        ((world.dx - _contentRect.left) / _contentRect.width).clamp(0.0, 1.0),
        ((world.dy - _contentRect.top) / _contentRect.height).clamp(0.0, 1.0),
      );

  /// Abstand Punkt–Strecke und Projektionsparameter t (0..1).
  static (double, double) _distToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 == 0) return ((p - a).distance, 0);
    var t = ((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2;
    t = t.clamp(0.0, 1.0);
    return ((p - (a + ab * t)).distance, t);
  }

  /// Findet den Stripe (und ggf. Punkt-Index) unter dem Weltpunkt [pos].
  /// Der Trefferradius bleibt unabhängig vom Zoom konstant auf dem Bildschirm.
  (LedStrip, int)? _hitTest(Offset pos) {
    final r = _hitRadius / _zoom;
    // Zuerst Handles des selektierten Stripes bevorzugen.
    final sel = st.selected;
    if (sel != null) {
      for (var i = 0; i < sel.points.length; i++) {
        if ((_toCanvas(sel.points[i]) - pos).distance < r) return (sel, i);
      }
    }
    for (final s in st.strips.reversed) {
      for (var i = 0; i < s.points.length; i++) {
        if ((_toCanvas(s.points[i]) - pos).distance < r) return (s, i);
      }
      final segs = sampledSegments(
          [for (final p in s.points) _toCanvas(p)], s.curved, samples: 12);
      for (final seg in segs) {
        for (var i = 0; i < seg.length - 1; i++) {
          final (d, _) = _distToSegment(pos, seg[i], seg[i + 1]);
          if (d < r) return (s, -1);
        }
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
    _dragPointIndex = -1;
    _panView = true;

    // Ein Finger/Mauszeiger im Bearbeiten-Modus: Stripe/Punkt greifen.
    // Trackpad-Gesten (Zwei-Finger-Scroll/Pinch) steuern immer die Ansicht.
    if (st.editMode && d.pointerCount <= 1 && d.kind != PointerDeviceKind.trackpad) {
      final hit = _hitTest(_screenToWorld(d.localFocalPoint));
      if (hit != null) {
        _dragStrip = hit.$1;
        _dragPointIndex = hit.$2;
        _panView = false;
        st.select(hit.$1.id);
      }
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final focal = d.localFocalPoint;
    final s = _dragStrip;

    if (s != null) {
      if (_dragPointIndex >= 0) {
        s.points[_dragPointIndex] = _toNorm(_screenToWorld(focal));
      } else {
        // Ganzen Stripe verschieben.
        final delta = (focal - _prevFocal) / _zoom;
        final norm = Offset(delta.dx / _contentRect.width, delta.dy / _contentRect.height);
        for (var i = 0; i < s.points.length; i++) {
          s.points[i] = Offset(
            (s.points[i].dx + norm.dx).clamp(0.0, 1.0),
            (s.points[i].dy + norm.dy).clamp(0.0, 1.0),
          );
        }
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
    final s = _dragStrip;
    _dragStrip = null;
    _dragPointIndex = -1;
    _panView = false;
    if (s != null) {
      // Nach dem Formen auf die feste physische Länge zurückskalieren.
      st.normalizeStripLength(s);
      st.changed();
    }
  }

  void _onTapUp(TapUpDetails d) {
    if (!st.editMode) return;
    final hit = _hitTest(_screenToWorld(d.localPosition));
    st.select(hit?.$1.id);
  }

  /// Doppeltipp auf ein Segment fügt dort einen Stützpunkt ein.
  void _onDoubleTapDown(TapDownDetails d) {
    if (!st.editMode) return;
    final sel = st.selected;
    if (sel == null) return;
    final pos = _screenToWorld(d.localPosition);
    var bestDist = _hitRadius * 1.5 / _zoom;
    var insertAt = -1;
    var bestPoint = Offset.zero;
    final segs = sampledSegments(
        [for (final p in sel.points) _toCanvas(p)], sel.curved, samples: 12);
    for (var si = 0; si < segs.length; si++) {
      final seg = segs[si];
      for (var i = 0; i < seg.length - 1; i++) {
        final (dist, t) = _distToSegment(pos, seg[i], seg[i + 1]);
        if (dist < bestDist) {
          bestDist = dist;
          insertAt = si + 1; // in die Kontrollpunkt-Liste hinter Segment si
          bestPoint = seg[i] + (seg[i + 1] - seg[i]) * t;
        }
      }
    }
    if (insertAt > 0) {
      sel.points.insert(insertAt, _toNorm(bestPoint));
      st.normalizeStripLength(sel);
      st.changed();
    }
  }

  /// Langes Drücken auf einen Stützpunkt entfernt ihn (min. 2 bleiben).
  void _onLongPressStart(LongPressStartDetails d) {
    if (!st.editMode) return;
    final hit = _hitTest(_screenToWorld(d.localPosition));
    if (hit == null || hit.$2 < 0) return;
    final s = hit.$1;
    if (s.points.length <= 2) return;
    s.points.removeAt(hit.$2);
    st.normalizeStripLength(s);
    st.changed();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      _contentRect = _computeContentRect(constraints.biggest);
      // Seitenverhältnis für die metrische Längenberechnung bereitstellen;
      // bei Änderung (Fenstergröße, neues Bild) Stripe-Längen neu einpassen.
      final aspect = _contentRect.height / _contentRect.width;
      if ((st.contentAspect - aspect).abs() > 1e-9) {
        st.contentAspect = aspect;
        st.normalizeAllStrips();
      }
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
                onDoubleTapDown: _onDoubleTapDown,
                onLongPressStart: _onLongPressStart,
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
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
                      onPressed:
                          _zoom == 1.0 && _view == Offset.zero ? null : _resetView,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    });
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

  /// Abgetastete Form des Stripes (gerade Segmente oder Spline) als Polylinie.
  List<Offset> _shapePolyline(LedStrip s) => flattenSegments(
      sampledSegments([for (final p in s.points) _toCanvas(p)], s.curved));

  /// Platziert die [LedStrip.ledCount] LEDs mit festem metrischen Abstand
  /// (1/Dichte Meter) entlang der Form, beginnend am Datenanschluss.
  /// Die Form ist per Längen-Normalisierung genau passend skaliert.
  List<Offset> _ledPositions(LedStrip s) {
    final pts = _shapePolyline(s);
    if (pts.length < 2) return const [];
    final segLens = <double>[];
    var total = 0.0;
    for (var i = 0; i < pts.length - 1; i++) {
      final l = (pts[i + 1] - pts[i]).distance;
      segLens.add(l);
      total += l;
    }
    if (total == 0) return [pts.first];

    final mPerPx = state.sceneWidthMeters / contentRect.width;
    final spacingPx = (1.0 / s.ledsPerMeter) / mPerPx;
    final count = s.ledCount.clamp(1, kMaxLedsPerStrip);

    final result = <Offset>[];
    var seg = 0;
    var segStart = 0.0;
    for (var i = 0; i < count; i++) {
      // LED sitzt in der Mitte ihres Schnittsegments, wie beim realen Stripe.
      final target = math.min((i + 0.5) * spacingPx, total);
      while (seg < segLens.length - 1 && segStart + segLens[seg] < target) {
        segStart += segLens[seg];
        seg++;
      }
      final f = segLens[seg] == 0 ? 0.0 : (target - segStart) / segLens[seg];
      result.add(pts[seg] + (pts[seg + 1] - pts[seg]) * f.clamp(0.0, 1.0));
    }
    return result;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF101014));

    canvas.save();
    canvas.translate(view.dx, view.dy);
    canvas.scale(zoom);

    // Sichtbarer Ausschnitt in Weltkoordinaten (für das Raster).
    final visible = Rect.fromLTWH(
        -view.dx / zoom, -view.dy / zoom, size.width / zoom, size.height / zoom);

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

    final t = time.value;
    for (final s in state.strips) {
      final leds = _ledPositions(s);
      if (leds.isEmpty) continue;

      final ledR = state.ledSize;
      final glowR = ledR * (1.5 + state.glow * 2.5);
      final glowPaint = Paint()
        ..blendMode = BlendMode.plus
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowR * 0.6);
      final corePaint = Paint()..blendMode = BlendMode.plus;

      for (var i = 0; i < leds.length; i++) {
        final c = state.simulate
            ? ledColor(s, leds.length, i, t)
            : ledColor(s, leds.length, i, 0);
        if (c.a == 0) continue;
        final lum = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
        if (state.glow > 0 && lum > 0.02) {
          glowPaint.color = c.withValues(alpha: 0.55 * math.min(1, lum + 0.2));
          canvas.drawCircle(leds[i], glowR, glowPaint);
        }
        corePaint.color = c;
        canvas.drawCircle(leds[i], ledR * 0.55, corePaint);
        // Heller Kern für "überstrahlte" LEDs.
        if (lum > 0.6) {
          corePaint.color = Color.lerp(c, const Color(0xFFFFFFFF), 0.6)!
              .withValues(alpha: 0.9);
          canvas.drawCircle(leds[i], ledR * 0.3, corePaint);
        }
      }

      if (state.editMode) _paintEditOverlay(canvas, s, leds);
    }

    canvas.restore();
  }

  /// Editier-Overlay: Linien und Handles behalten unabhängig vom Zoom
  /// ihre Bildschirmgröße (alle Maße durch [zoom] geteilt).
  void _paintEditOverlay(Canvas canvas, LedStrip s, List<Offset> leds) {
    final isSel = s.id == state.selectedId;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (isSel ? 2 : 1) / zoom
      ..color = isSel ? const Color(0xCCFFFFFF) : const Color(0x44FFFFFF);
    final shape = _shapePolyline(s);
    final path = Path()..moveTo(shape.first.dx, shape.first.dy);
    for (final p in shape.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, line);

    // Richtungsmarkierung: Anfang (Datenanschluss) als Dreieck.
    if (leds.length >= 2) {
      final a = leds.first;
      final dir = (leds[1] - a);
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
      canvas.drawPath(tri, Paint()..color = isSel ? Colors.white : Colors.white38);
      canvas.restore();
    }

    for (var i = 0; i < s.points.length; i++) {
      final c = _toCanvas(s.points[i]);
      canvas.drawCircle(c, 6 / zoom,
          Paint()..color = isSel ? const Color(0xFF2196F3) : const Color(0x662196F3));
      canvas.drawCircle(
          c,
          6 / zoom,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5 / zoom
            ..color = Colors.white70);
    }
  }

  void _paintGrid(Canvas canvas, Rect visible) {
    final p = Paint()
      ..color = const Color(0x14FFFFFF)
      ..strokeWidth = 1 / zoom;
    const step = 40.0;
    final x0 = (visible.left / step).floor() * step;
    final y0 = (visible.top / step).floor() * step;
    for (var x = x0; x < visible.right; x += step) {
      canvas.drawLine(Offset(x, visible.top), Offset(x, visible.bottom), p);
    }
    for (var y = y0; y < visible.bottom; y += step) {
      canvas.drawLine(Offset(visible.left, y), Offset(visible.right, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _StripPainter old) =>
      old.contentRect != contentRect ||
      old.state != state ||
      old.zoom != zoom ||
      old.view != view;
}
