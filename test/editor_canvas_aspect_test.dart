import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledato_stripes/app_state.dart';
import 'package:ledato_stripes/editor_canvas.dart';

void main() {
  testWidgets(
    'Ohne Hintergrundbild ist contentAspect geräteunabhängig (sceneAspect) '
    'statt von der Fenster-/Bildschirmform abzuhängen',
    (tester) async {
      final state = AppState();
      state.sceneAspect = 0.8;
      final time = ValueNotifier<double>(0);
      addTearDown(time.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Future<void> pumpAtSize(Size size) async {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: size.width,
              height: size.height,
              child: EditorCanvas(state: state, time: time),
            ),
          ),
        );
        await tester.pump();
      }

      // Breites "Mac-Fenster" (Querformat).
      await pumpAtSize(const Size(1200, 700));
      final aspectWide = state.contentAspect;

      // Schmales "Handy-Display" (Hochformat) — dieselbe AppState-Instanz,
      // dieselbe Konfiguration.
      await pumpAtSize(const Size(390, 844));
      final aspectNarrow = state.contentAspect;

      expect(aspectWide, closeTo(state.sceneAspect, 1e-6));
      expect(aspectNarrow, closeTo(state.sceneAspect, 1e-6));
      expect(aspectWide, closeTo(aspectNarrow, 1e-6));
    },
  );
}
