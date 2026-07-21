import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledato_stripes/app_state.dart';
import 'package:ledato_stripes/model.dart';
import 'package:ledato_stripes/yaml_config.dart';

void main() {
  test('YAML-Konfiguration: Export und Import ergeben denselben Zustand', () {
    final st = AppState();
    st.sceneWidthMeters = 4.5;
    st.strips.add(
      LedStrip(
        id: 'abc',
        name: 'Test: Fenster, "Wohnzimmer"',
        sections: [
          StripSection(
            start: const Offset(0.1, 0.2),
            angle: 0.7854, // ~45°
            effect: EffectType.fire,
            color: const Color(0xFFAA00FF),
          ),
        ],
      ),
    );

    final yaml = encodeConfigYaml(st);

    final st2 = AppState();
    final bgPath = applyConfigYaml(st2, yaml);
    final s1 = st.strips.first;
    final s2 = st2.strips.first;

    expect(bgPath, isNull);
    expect(st2.sceneWidthMeters, closeTo(st.sceneWidthMeters, 1e-6));
    expect(s2.name, s1.name);
    expect(
      s2.sections.first.color.toARGB32(),
      s1.sections.first.color.toARGB32(),
    );
    expect(s2.ledCount, s1.ledCount);
    expect(s2.ledsPerMeter, s1.ledsPerMeter);
    expect(s2.sections.length, s1.sections.length);
    expect(s2.sections.first.effect, s1.sections.first.effect);
    expect(
      (s2.sections.first.start - s1.sections.first.start).distance,
      lessThan(1e-3),
    );
    expect(s2.sections.first.angle, closeTo(s1.sections.first.angle, 1e-3));
  });

  test('Ein Abschnitt hat exakt die Länge (LEDs−1) ÷ Dichte', () {
    final st = AppState()
      ..contentAspect = 0.8
      ..sceneWidthMeters = 5.0;
    final strip = LedStrip(
      id: 'multi',
      name: 'Mehrteilig',
      ledsPerMeter: 60,
      sections: [
        StripSection(start: const Offset(0.1, 0.2), angle: 0.0, ledCount: 80),
        StripSection(
          start: const Offset(0.6, 0.7),
          angle: math.pi / 2,
          ledCount: 40,
        ),
      ],
    );
    st.strips.add(strip);

    for (final sec in strip.sections) {
      final target = st.sectionTargetLengthMeters(strip, sec);
      final end = st.sectionEnd(strip, sec);
      // Reale (metergetreue) Entfernung zwischen Start und berechnetem
      // Endpunkt muss exakt der Ziel-Länge entsprechen.
      final startM = Offset(
        sec.start.dx * st.sceneWidthMeters,
        sec.start.dy * st.sceneWidthMeters * st.contentAspect,
      );
      final endM = Offset(
        end.dx * st.sceneWidthMeters,
        end.dy * st.sceneWidthMeters * st.contentAspect,
      );
      expect((endM - startM).distance, closeTo(target, 1e-6));
    }

    final yaml = encodeConfigYaml(st);
    final st2 = AppState()
      ..sceneWidthMeters = st.sceneWidthMeters
      ..contentAspect = st.contentAspect;
    applyConfigYaml(st2, yaml);
    final restored = st2.strips.first;
    expect(restored.sections.length, 2);
    expect(
      st2.sectionTargetLengthMeters(restored, restored.sections[0]),
      closeTo(st.sectionTargetLengthMeters(strip, strip.sections[0]), 1e-6),
    );
    expect(
      st2.sectionTargetLengthMeters(restored, restored.sections[1]),
      closeTo(st.sectionTargetLengthMeters(strip, strip.sections[1]), 1e-6),
    );
  });

  test('Jeder Abschnitt behält seine eigene Optik (Effekt, Farbe, Tempo, '
      'Richtung) auch nach YAML-Roundtrip', () {
    final st = AppState();
    final strip = LedStrip(
      id: 'fx',
      name: 'Effekt-Test',
      sections: [
        StripSection(
          start: const Offset(0.1, 0.2),
          effect: EffectType.fire,
          color: const Color(0xFFFF0000),
          speed: 0.9,
          reversed: true,
        ),
        StripSection(
          start: const Offset(0.6, 0.7),
          effect: EffectType.rainbow,
          color: const Color(0xFF00FF00),
          speed: 0.2,
          reversed: false,
        ),
      ],
    );
    st.strips.add(strip);

    expect(strip.sections[0].effect, EffectType.fire);
    expect(strip.sections[1].effect, EffectType.rainbow);

    final yaml = encodeConfigYaml(st);
    final st2 = AppState();
    applyConfigYaml(st2, yaml);
    final restored = st2.strips.first;
    expect(restored.sections[0].effect, EffectType.fire);
    expect(restored.sections[1].effect, EffectType.rainbow);
    expect(
      restored.sections[0].color.toARGB32(),
      const Color(0xFFFF0000).toARGB32(),
    );
    expect(
      restored.sections[1].color.toARGB32(),
      const Color(0xFF00FF00).toARGB32(),
    );
    expect(restored.sections[0].speed, closeTo(0.9, 1e-6));
    expect(restored.sections[1].speed, closeTo(0.2, 1e-6));
    expect(restored.sections[0].reversed, isTrue);
    expect(restored.sections[1].reversed, isFalse);
  });
}
