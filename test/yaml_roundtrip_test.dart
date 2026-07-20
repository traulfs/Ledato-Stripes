import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledato_stripes/app_state.dart';
import 'package:ledato_stripes/model.dart';
import 'package:ledato_stripes/yaml_config.dart';

void main() {
  test('YAML-Konfiguration: Export und Import ergeben denselben Zustand', () {
    final st = AppState();
    st.sceneWidthMeters = 4.5;
    st.strips.add(LedStrip(
      id: 'abc',
      name: 'Test: Fenster, "Wohnzimmer"',
      points: const [Offset(0.1, 0.2), Offset(0.8, 0.3), Offset(0.5, 0.9)],
      curved: true,
      effect: EffectType.fire,
      color: const Color(0xFFAA00FF),
    ));
    st.normalizeStripLength(st.strips.first);

    final yaml = encodeConfigYaml(st);

    final st2 = AppState();
    final bgPath = applyConfigYaml(st2, yaml);
    final s1 = st.strips.first;
    final s2 = st2.strips.first;

    expect(bgPath, isNull);
    expect(st2.sceneWidthMeters, closeTo(st.sceneWidthMeters, 1e-6));
    expect(s2.name, s1.name);
    expect(s2.curved, s1.curved);
    expect(s2.effect, s1.effect);
    expect(s2.color.toARGB32(), s1.color.toARGB32());
    expect(s2.ledCount, s1.ledCount);
    expect(s2.ledsPerMeter, s1.ledsPerMeter);
    expect(s2.points.length, s1.points.length);
    for (var i = 0; i < s1.points.length; i++) {
      expect((s2.points[i] - s1.points[i]).distance, lessThan(1e-3));
    }
  });
}
