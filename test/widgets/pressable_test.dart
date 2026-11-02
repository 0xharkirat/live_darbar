import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/core/motion.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/views/widgets/pressable.dart';

const _target = Key('target');

Future<void> _pump(
  WidgetTester tester, {
  double scale = Motion.pressScale,
  VoidCallback? onTap,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: Pressable(
          scale: scale,
          onTap: onTap ?? () {},
          child: const PressFill(
            key: _target,
            color: Palette.surface,
            pressedColor: Palette.surfaceHigh,
            child: SizedBox(width: 120, height: 48),
          ),
        ),
      ),
    ),
  );
}

/// The colour on screen this frame, not the one the fill is heading for.
Color? _fill(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find
        .descendant(
          of: find.byKey(_target),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  return (box.decoration as ShapeDecoration).color;
}

void main() {
  group('PressFill', () {
    testWidgets('is the idle colour until the finger lands', (tester) async {
      await _pump(tester);

      expect(_fill(tester), Palette.surface);
    });

    testWidgets('reaches the pressed colour within 120 ms of touch-down', (
      tester,
    ) async {
      await _pump(tester);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_target)),
      );
      await tester.pump();
      await tester.pump(Motion.press);

      expect(_fill(tester), Palette.surfaceHigh);
      await gesture.up();
    });

    testWidgets('starts on the first frame, not on release', (tester) async {
      await _pump(tester);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_target)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(_fill(tester), isNot(Palette.surface), reason: 'already moving');
      await gesture.up();
    });

    testWidgets('lets go over 180 ms', (tester) async {
      await _pump(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_target)),
      );
      await tester.pump();
      await tester.pump(Motion.press);
      await gesture.up();
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 90));
      expect(_fill(tester), isNot(Palette.surface), reason: 'still easing');

      await tester.pump(Motion.quick);
      expect(_fill(tester), Palette.surface);
    });

    testWidgets('lifts without firing when the finger drags off', (
      tester,
    ) async {
      var taps = 0;
      await _pump(tester, onTap: () => taps++);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_target)),
      );
      await tester.pump(Motion.press);
      await gesture.moveBy(const Offset(0, 200));
      await tester.pump();
      await tester.pump(Motion.quick);

      expect(_fill(tester), Palette.surface);
      await gesture.up();
      expect(taps, 0);
    });
  });

  group('scale', () {
    double scaleOf(WidgetTester tester) =>
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

    testWidgets('sinks to the scale it was given on touch-down', (
      tester,
    ) async {
      await _pump(tester, scale: 0.95);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_target)),
      );
      await tester.pump();

      expect(scaleOf(tester), 0.95);
      await gesture.up();
    });
  });

  group('with Reduce Motion', () {
    void reduce(WidgetTester tester) {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
    }

    testWidgets('a scaled target dims instead of sinking', (tester) async {
      reduce(tester);
      await _pump(tester);

      expect(find.byType(AnimatedScale), findsNothing);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_target)),
      );
      await tester.pump();

      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        0.7,
      );
      await gesture.up();
    });

    testWidgets('an unscaled row has the fill alone and does not dim', (
      tester,
    ) async {
      reduce(tester);
      await _pump(tester, scale: 1);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_target)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(find.byType(AnimatedOpacity), findsNothing);
      expect(_fill(tester), isNot(Palette.surface), reason: 'fill still shows');
      await gesture.up();
    });
  });
}
