import 'package:flutter/material.dart';

import 'app_state.dart';
import 'model.dart';

/// Seitenpanel: Stripe-Liste, Einstellungen des ausgewählten Stripes
/// und globale Darstellungsoptionen.
class StripPanel extends StatelessWidget {
  const StripPanel({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final sel = state.selected;
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _stripList(context),
            const SizedBox(height: 8),
            if (sel != null) ...[
              const Divider(),
              _stripSettings(context, sel),
            ],
            const Divider(),
            _globalSettings(context),
          ],
        );
      },
    );
  }

  // ---------- Stripe-Liste ----------

  Widget _stripList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Stripes (${state.strips.length}/$kMaxStrips)',
                style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            IconButton(
              tooltip: state.strips.length >= kMaxStrips
                  ? 'Maximal $kMaxStrips Stripes'
                  : 'Stripe hinzufügen',
              onPressed:
                  state.strips.length >= kMaxStrips ? null : () => state.addStrip(),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        for (final s in state.strips)
          ListTile(
            dense: true,
            selected: s.id == state.selectedId,
            selectedTileColor: Colors.white.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            leading: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: s.enabled ? s.color : Colors.grey.shade800,
                shape: BoxShape.circle,
                boxShadow: s.enabled
                    ? [BoxShadow(color: s.color.withValues(alpha: 0.7), blurRadius: 8)]
                    : null,
              ),
            ),
            title: Text(s.name, overflow: TextOverflow.ellipsis),
            subtitle: Text(
                '${s.ledCount} LEDs · ${_fmtMeters(state.targetLengthMeters(s))} · '
                '${s.effect.label}'),
            onTap: () => state.select(s.id),
            trailing: IconButton(
              tooltip: 'Löschen',
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => state.removeStrip(s),
            ),
          ),
      ],
    );
  }

  // ---------- Einstellungen des ausgewählten Stripes ----------

  Widget _stripSettings(BuildContext context, LedStrip s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                key: ValueKey('name-${s.id}'),
                initialValue: s.name,
                decoration: const InputDecoration(
                    labelText: 'Name', isDense: true, border: OutlineInputBorder()),
                onChanged: (v) {
                  s.name = v;
                  state.changed();
                },
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: s.enabled,
              onChanged: (v) {
                s.enabled = v;
                state.changed();
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const SizedBox(
                width: 90, child: Text('LEDs', style: TextStyle(fontSize: 13))),
            Expanded(
              child: Slider(
                value: s.ledCount.toDouble().clamp(1, kMaxLedsPerStrip.toDouble()),
                min: 1,
                max: kMaxLedsPerStrip.toDouble(),
                divisions: kMaxLedsPerStrip - 1,
                onChanged: (v) => _setLedCount(s, v.round()),
              ),
            ),
            SizedBox(
              width: 56,
              child: TextFormField(
                key: ValueKey('count-${s.id}-${s.ledCount}'),
                initialValue: '${s.ledCount}',
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                    isDense: true, border: OutlineInputBorder()),
                onFieldSubmitted: (v) {
                  final n = int.tryParse(v.trim());
                  if (n != null) _setLedCount(s, n);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: kLedDensities.contains(s.ledsPerMeter)
              ? s.ledsPerMeter
              : kLedDensities[1],
          decoration: const InputDecoration(
              labelText: 'LED-Dichte',
              isDense: true,
              border: OutlineInputBorder()),
          items: [
            for (final d in kLedDensities)
              DropdownMenuItem(value: d, child: Text('$d LEDs pro Meter')),
          ],
          onChanged: (v) {
            if (v == null) return;
            s.ledsPerMeter = v;
            state.normalizeStripLength(s);
            state.changed();
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
              'Länge: ${_fmtMeters(state.targetLengthMeters(s))}   ·   '
              'LED-Abstand ${(1000 / s.ledsPerMeter).toStringAsFixed(1).replaceAll('.', ',')} mm'),
        ),
        DropdownButtonFormField<EffectType>(
          initialValue: s.effect,
          decoration: const InputDecoration(
              labelText: 'Effekt', isDense: true, border: OutlineInputBorder()),
          items: [
            for (final e in EffectType.values)
              DropdownMenuItem(value: e, child: Text(e.label)),
          ],
          onChanged: (v) {
            if (v == null) return;
            s.effect = v;
            state.changed();
          },
        ),
        const SizedBox(height: 12),
        if (!const {EffectType.rainbow, EffectType.fire, EffectType.confetti}
            .contains(s.effect)) ...[
          _ColorRow(
            label: _usesTwoColors(s.effect) ? 'Farbe 1' : 'Farbe',
            color: s.color,
            onChanged: (c) {
              s.color = c;
              state.changed();
            },
          ),
          if (_usesTwoColors(s.effect))
            _ColorRow(
              label: 'Farbe 2',
              color: s.color2,
              onChanged: (c) {
                s.color2 = c;
                state.changed();
              },
            ),
        ],
        _sliderRow(
          label: 'Helligkeit',
          value: s.brightness,
          min: 0,
          max: 1,
          display: '${(s.brightness * 100).round()} %',
          onChanged: (v) {
            s.brightness = v;
            state.changed();
          },
        ),
        if (s.effect != EffectType.solid && s.effect != EffectType.gradient)
          _sliderRow(
            label: 'Tempo',
            value: s.speed,
            min: 0,
            max: 1,
            display: '${(s.speed * 100).round()} %',
            onChanged: (v) {
              s.speed = v;
              state.changed();
            },
          ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Richtung umkehren'),
          value: s.reversed,
          onChanged: (v) {
            s.reversed = v;
            state.changed();
          },
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const SizedBox(
                width: 90, child: Text('Form', style: TextStyle(fontSize: 13))),
            for (final (shape, icon) in const [
              (StripShape.line, Icons.horizontal_rule),
              (StripShape.rect, Icons.rectangle_outlined),
              (StripShape.circle, Icons.circle_outlined),
              (StripShape.zigzag, Icons.airline_stops),
            ])
              IconButton(
                tooltip: 'Form ersetzen: ${shape.label}',
                icon: Icon(icon, size: 20),
                onPressed: () => state.applyShapeTemplate(s, shape),
              ),
          ],
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Geschwungen (Kurve durch die Punkte)'),
          value: s.curved,
          onChanged: (v) {
            s.curved = v;
            state.changed();
          },
        ),
        const SizedBox(height: 4),
        Text(
          'Tipp: Punkte auf der Leinwand ziehen. Doppeltipp auf die Linie fügt '
          'einen Punkt ein, langes Drücken auf einen Punkt entfernt ihn. '
          'Das Dreieck markiert den Datenanschluss (LED 1). '
          'Mausrad oder Pinch zoomt, Ziehen auf freier Fläche verschiebt die Ansicht.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  void _setLedCount(LedStrip s, int n) {
    s.ledCount = n.clamp(1, kMaxLedsPerStrip);
    state.normalizeStripLength(s);
    state.changed();
  }

  /// Meterangabe im deutschen Format, z. B. "2,35 m".
  static String _fmtMeters(double m) =>
      '${m.toStringAsFixed(2).replaceAll('.', ',')} m';

  static bool _usesTwoColors(EffectType e) => const {
        EffectType.gradient,
        EffectType.wave,
        EffectType.blink,
        EffectType.colorWipe,
      }.contains(e);

  // ---------- Globale Darstellung ----------

  Widget _globalSettings(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Maßstab', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        _sliderRow(
          label: 'Bildbreite',
          value: state.sceneWidthMeters,
          min: 0.5,
          max: 30,
          display: _fmtMeters(state.sceneWidthMeters),
          onChanged: (v) {
            state.sceneWidthMeters = v;
            state.normalizeAllStrips();
            state.changed();
          },
        ),
        Text(
          'Reale Breite des Hintergrundbilds — darüber werden Stripe-Längen '
          'und LED-Anzahl berechnet.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Text('Darstellung', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _sliderRow(
          label: 'Hintergrund abdunkeln',
          value: state.backgroundDim,
          min: 0,
          max: 1,
          display: '${(state.backgroundDim * 100).round()} %',
          onChanged: (v) {
            state.backgroundDim = v;
            state.changed();
          },
        ),
        _sliderRow(
          label: 'LED-Größe',
          value: state.ledSize,
          min: 2,
          max: 16,
          display: state.ledSize.toStringAsFixed(0),
          onChanged: (v) {
            state.ledSize = v;
            state.changed();
          },
        ),
        _sliderRow(
          label: 'Leuchtschein',
          value: state.glow,
          min: 0,
          max: 2,
          display: '${(state.glow * 50).round()} %',
          onChanged: (v) {
            state.glow = v;
            state.changed();
          },
        ),
      ],
    );
  }

  Widget _sliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required String display,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 13))),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
            width: 44,
            child: Text(display,
                textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
      ],
    );
  }
}

/// Farbzeile: Vorschau-Kachel öffnet einen einfachen HSV-Farbwähler.
class _ColorRow extends StatelessWidget {
  const _ColorRow({required this.label, required this.color, required this.onChanged});

  final String label;
  final Color color;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 13))),
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => _pick(context),
            child: Container(
              width: 48,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white24),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 6,
              children: [
                for (final c in _swatches)
                  GestureDetector(
                    onTap: () => onChanged(c),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: c.toARGB32() == color.toARGB32()
                              ? Colors.white
                              : Colors.white24,
                          width: c.toARGB32() == color.toARGB32() ? 2 : 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _swatches = [
    Color(0xFFFFFFFF),
    Color(0xFFFF0000),
    Color(0xFFFF6000),
    Color(0xFFFFD000),
    Color(0xFF00FF00),
    Color(0xFF00FFD0),
    Color(0xFF0080FF),
    Color(0xFF8040FF),
    Color(0xFFFF00A0),
  ];

  Future<void> _pick(BuildContext context) async {
    var hsv = HSVColor.fromColor(color);
    final result = await showDialog<Color>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(label),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: hsv.toColor(),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 12),
                _hsvSlider('Farbton', hsv.hue, 0, 360,
                    (v) => setState(() => hsv = hsv.withHue(v))),
                _hsvSlider('Sättigung', hsv.saturation, 0, 1,
                    (v) => setState(() => hsv = hsv.withSaturation(v))),
                _hsvSlider('Wert', hsv.value, 0, 1,
                    (v) => setState(() => hsv = hsv.withValue(v))),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
            FilledButton(
                onPressed: () => Navigator.pop(context, hsv.toColor()),
                child: const Text('Übernehmen')),
          ],
        ),
      ),
    );
    if (result != null) onChanged(result);
  }

  static Widget _hsvSlider(
      String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 13))),
        Expanded(
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }
}
