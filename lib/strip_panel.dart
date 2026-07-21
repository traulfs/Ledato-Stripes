import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'app_state.dart';
import 'color_row.dart';
import 'labeled_slider.dart';
import 'model.dart';

/// Seitenpanel: Stripe-Liste (auswählen, löschen) und Einstellungen des
/// jeweils ausgewählten Stripes bzw. Abschnitts.
class StripPanel extends StatefulWidget {
  const StripPanel({super.key, required this.state});

  final AppState state;

  @override
  State<StripPanel> createState() => _StripPanelState();
}

class _StripPanelState extends State<StripPanel> {
  AppState get state => widget.state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final sel = state.selected;
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _stripSelectorRow(context),
            if (sel != null) ...[const Divider(), _stripSettings(context, sel)],
          ],
        );
      },
    );
  }

  // ---------- Stripe-Auswahl ----------

  Widget _stripSelectorRow(BuildContext context) {
    final strips = state.strips;
    final sel = state.selected;
    return Row(
      children: [
        Expanded(
          child: strips.isEmpty
              ? const Text('Keine Stripes')
              : DropdownButtonFormField<String>(
                  key: ValueKey('strip-selector-${state.selectedId}'),
                  initialValue: sel?.id,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final s in strips)
                      DropdownMenuItem(
                        value: s.id,
                        child: Text(s.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (id) {
                    if (id != null) state.select(id);
                  },
                ),
        ),
        IconButton(
          tooltip: 'Bearbeiten',
          icon: const Icon(Icons.edit_outlined),
          onPressed: sel == null ? null : () => _editStripDialog(context, sel),
        ),
        IconButton(
          tooltip: strips.length >= kMaxStrips
              ? 'Maximal $kMaxStrips Stripes'
              : 'Stripe hinzufügen',
          icon: const Icon(Icons.add),
          onPressed: strips.length >= kMaxStrips
              ? null
              : () => state.addStrip(),
        ),
        Switch(
          value: sel?.enabled ?? false,
          onChanged: sel == null
              ? null
              : (v) {
                  sel.enabled = v;
                  state.changed();
                },
        ),
      ],
    );
  }

  Future<void> _editStripDialog(BuildContext context, LedStrip s) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          if (!state.strips.contains(s)) {
            SchedulerBinding.instance.addPostFrameCallback((_) {
              if (Navigator.canPop(dialogContext)) Navigator.pop(dialogContext);
            });
            return const SizedBox.shrink();
          }
          return AlertDialog(
            title: const Text('Stripe bearbeiten'),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: ValueKey('name-${s.id}'),
                    initialValue: s.name,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      s.name = v;
                      state.changed();
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: kLedDensities.contains(s.ledsPerMeter)
                        ? s.ledsPerMeter
                        : kLedDensities[1],
                    decoration: const InputDecoration(
                      labelText: 'LED-Dichte',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final d in kLedDensities)
                        DropdownMenuItem(
                          value: d,
                          child: Text('$d LEDs pro Meter'),
                        ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      s.ledsPerMeter = v;
                      state.changed();
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'LED-Abstand: ${(1000 / s.ledsPerMeter).toStringAsFixed(1).replaceAll('.', ',')} mm',
                    ),
                  ),
                  Text(
                    'Gesamt: ${s.ledCount}/$kMaxLedsPerStrip LEDs · '
                    '${fmtMeters(state.targetLengthMeters(s))}'
                    '${s.sections.length > 1 ? ' auf ${s.sections.length} Abschnitten' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                onPressed: () {
                  state.removeStrip(s);
                  Navigator.pop(dialogContext);
                },
                child: const Text('Löschen'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Fertig'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------- Einstellungen des ausgewählten Stripes ----------

  Widget _stripSettings(BuildContext context, LedStrip s) {
    final selIdx = state.selectedSectionIndex.clamp(0, s.sections.length - 1);
    final selSec = s.sections[selIdx];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionSelectorRow(context, s, selIdx),
        const Divider(),
        _sectionSettings(context, s, selIdx, selSec),
      ],
    );
  }

  // ---------- Abschnitt-Auswahl ----------

  Widget _sectionSelectorRow(BuildContext context, LedStrip s, int selIdx) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            key: ValueKey('section-selector-${s.id}-$selIdx'),
            initialValue: selIdx,
            isExpanded: true,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: [
              for (var i = 0; i < s.sections.length; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(
                    'Abschnitt ${i + 1} · ${s.sections[i].ledCount} LEDs',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (i) {
              if (i != null) state.selectSection(i);
            },
          ),
        ),
        IconButton(
          tooltip: 'Bearbeiten',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => _editSectionDialog(context, s, selIdx),
        ),
        IconButton(
          tooltip: s.ledCount >= kMaxLedsPerStrip
              ? 'Maximal $kMaxLedsPerStrip LEDs erreicht'
              : 'Abschnitt hinzufügen',
          icon: const Icon(Icons.add),
          onPressed: s.ledCount >= kMaxLedsPerStrip
              ? null
              : () => state.addSection(s),
        ),
      ],
    );
  }

  Future<void> _editSectionDialog(
    BuildContext context,
    LedStrip s,
    int idx,
  ) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          if (idx >= s.sections.length) {
            SchedulerBinding.instance.addPostFrameCallback((_) {
              if (Navigator.canPop(dialogContext)) {
                Navigator.pop(dialogContext);
              }
            });
            return const SizedBox.shrink();
          }
          final sec = s.sections[idx];
          return AlertDialog(
            title: Text('Abschnitt ${idx + 1} bearbeiten'),
            content: Text(
              '${sec.ledCount} LEDs · '
              '${fmtMeters(state.sectionTargetLengthMeters(s, sec))} · '
              '${sec.effect.label}',
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                onPressed: s.sections.length <= 1
                    ? null
                    : () {
                        state.removeSection(s, idx);
                        Navigator.pop(dialogContext);
                      },
                child: const Text('Löschen'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Fertig'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------- Einstellungen des ausgewählten Abschnitts ----------

  Widget _sectionSettings(
    BuildContext context,
    LedStrip s,
    int selIdx,
    StripSection selSec,
  ) {
    final maxForSection = (kMaxLedsPerStrip - (s.ledCount - selSec.ledCount))
        .clamp(1, kMaxLedsPerStrip);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabeledSlider(
          label: 'LEDs',
          value: selSec.ledCount.toDouble().clamp(1, maxForSection.toDouble()),
          min: 1,
          max: maxForSection.toDouble(),
          divisions: maxForSection > 1 ? maxForSection - 1 : null,
          display: '${selSec.ledCount}',
          numberEntry: true,
          onChanged: (v) => state.setSectionLedCount(s, selSec, v.round()),
        ),
        LabeledSlider(
          label: 'Winkel',
          value: _angleDegrees(selSec.angle),
          min: 0,
          max: 360,
          display: '${_angleDegrees(selSec.angle).round()}°',
          numberEntry: true,
          unitSuffix: '°',
          onChanged: (v) {
            selSec.angle = v * (math.pi / 180);
            state.changed();
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            'Länge: ${fmtMeters(state.sectionTargetLengthMeters(s, selSec))}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        DropdownButtonFormField<EffectType>(
          key: ValueKey('effect-${s.id}-$selIdx'),
          initialValue: selSec.effect,
          decoration: const InputDecoration(
            labelText: 'Effekt',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          items: [
            for (final e in EffectType.values)
              DropdownMenuItem(value: e, child: Text(e.label)),
          ],
          onChanged: (v) {
            if (v == null) return;
            selSec.effect = v;
            state.changed();
          },
        ),
        const SizedBox(height: 8),
        if (!const {
          EffectType.rainbow,
          EffectType.fire,
          EffectType.confetti,
        }.contains(selSec.effect)) ...[
          ColorRow(
            label: _usesTwoColors(selSec.effect) ? 'Farbe 1' : 'Farbe',
            color: selSec.color,
            onChanged: (c) {
              selSec.color = c;
              state.changed();
            },
          ),
          if (_usesTwoColors(selSec.effect))
            ColorRow(
              label: 'Farbe 2',
              color: selSec.color2,
              onChanged: (c) {
                selSec.color2 = c;
                state.changed();
              },
            ),
        ],
        LabeledSlider(
          label: 'Helligkeit',
          value: selSec.brightness,
          min: 0,
          max: 1,
          display: '${(selSec.brightness * 100).round()} %',
          onChanged: (v) {
            selSec.brightness = v;
            state.changed();
          },
        ),
        if (selSec.effect != EffectType.solid &&
            selSec.effect != EffectType.gradient)
          LabeledSlider(
            label: 'Tempo',
            value: selSec.speed,
            min: 0,
            max: 1,
            display: '${(selSec.speed * 100).round()} %',
            onChanged: (v) {
              selSec.speed = v;
              state.changed();
            },
          ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Richtung umkehren'),
          value: selSec.reversed,
          onChanged: (v) {
            selSec.reversed = v;
            state.changed();
          },
        ),
        const SizedBox(height: 4),
        Text(
          'Tipp: Startpunkt (blauer Griff) auf der Leinwand ziehen verschiebt '
          'den Abschnitt, der orangene Endgriff dreht ihn um den Startpunkt. '
          'Das Dreieck markiert den Datenanschluss (LED 1), die gestrichelte '
          'Linie zwischen Abschnitten die elektrische Verbindung. '
          'Mausrad oder Pinch zoomt, Ziehen auf freier Fläche verschiebt die Ansicht.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  static bool _usesTwoColors(EffectType e) => const {
    EffectType.gradient,
    EffectType.wave,
    EffectType.blink,
    EffectType.colorWipe,
  }.contains(e);

  /// Winkel in Grad, normalisiert auf [0, 360).
  static double _angleDegrees(double radians) {
    var deg = radians * (180 / math.pi) % 360;
    if (deg < 0) deg += 360;
    return deg;
  }
}
