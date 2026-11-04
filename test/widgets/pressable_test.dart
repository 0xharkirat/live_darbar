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
    /// The scale on screen this frame, not the one it is heading for.
    double scaleOf(WidgetTester tester) => tester
        .widget<ScaleTransition>(
          find
              .descendant(
                of: find.byType(Pressable),
                matching: find.byType(ScaleTransition),
              )
              .first,
        )
        .scale
        .value;

    const frame = Duration(milliseconds: 16);

    testWidgets('sinks to the scale it was given, and no further', (
      tester,
    ) async {
      await _pump(tester, scale: 0.95);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_target)),
      );
      await tester.pumpAndSettle();

      expect(scaleOf(tester), 0.95);
      await gesture.up();
    });

    testWidgets('sinks to the 97% token by default', (tester) async {
      await _pump(tester);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_target)),
      );
      await tester.pumpAndSettle();

      expect(scaleOf(tester), Motion.pressScale);
      expect(Motion.pressScale, 0.97);
      await gesture.up();
    });

    testWidgets('starts to sink in the first frame, on touch-down', (
      tester,
    ) async {
      await _pump(tester);
      expect(scaleOf(tester), 1);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_target)),
      );
      await tester.pump();
      await tester.pump(frame);

      expect(scaleOf(tester), lessThan(1));
      await gesture.up();
    });

    testWidgets('is 95% of the way down within 120 ms', (tester) async {
      await _pump(tester);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_target)),
      );
      await tester.pump();
      await tester.pump(Motion.press);

      // 95% of the way from 1 to 0.97 is 0.9715.
      expect(scaleOf(tester), lessThan(0.9715));
      await gesture.up();
    });

    testWidgets('speeds up and slows down like a spring, not like a ramp', (
      tester,
    ) async {
      await _pump(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_target)),
      );
      await tester.pump();

      final steps = <double>[];
      var last = scaleOf(tester);
      for (var i = 0; i < 6; i++) {
        await tester.pump(frame);
        final now = scaleOf(tester);
        steps.add(last - now);
        last = now;
      }

      // Each frame moves, and the last moves less than the one before the
      // peak speed: it eases into the target.
      expect(steps.every((d) => d > 0), isTrue);
      expect(steps.last, lessThan(steps.reduce((a, b) => a > b ? a : b)));
      await gesture.up();
    });

    testWidgets('springs back past 100% a little, and ends at exactly 100%', (
      tester,
    ) async {
      await _pump(tester, scale: 0.9);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_target)),
      );
      await tester.pumpAndSettle();
      await gesture.up();
      await tester.pump();

      var peak = 0.0;
      for (var i = 0; i < 40; i++) {
        await tester.pump(frame);
        peak = scaleOf(tester) > peak ? scaleOf(tester) : peak;
      }

      expect(peak, greaterThan(1), reason: 'it overshoots, as a spring does');
      expect(peak, lessThan(1.03), reason: 'by a hair');
      await tester.pumpAndSettle();
      expect(scaleOf(tester), 1, reason: 'sharp at rest, not 0.9995');
    });

    testWidgets('a quick tap does not stutter', (tester) async {
      await _pump(tester);

      // Down, up 40 ms later (mid-sink), and on until it rests.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_target)),
      );
      final seen = <double>[scaleOf(tester)];
      for (var i = 0; i < 3; i++) {
        await tester.pump(frame);
        seen.add(scaleOf(tester));
      }
      await gesture.up();
      for (var i = 0; i < 40; i++) {
        await tester.pump(frame);
        seen.add(scaleOf(tester));
      }

      for (var i = 1; i < seen.length; i++) {
        expect(
          (seen[i] - seen[i - 1]).abs(),
          lessThan(0.01),
          reason: 'frame $i jumped from ${seen[i - 1]} to ${seen[i]}',
        );
      }
      expect(seen.reduce((a, b) => a < b ? a : b), greaterThan(0.96));
      expect(seen.reduce((a, b) => a > b ? a : b), lessThan(1.01));
    });

    testWidgets('keeps its speed when the finger lifts mid-sink', (
      tester,
    ) async {
      await _pump(tester, scale: 0.9);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_target)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 48));
      final before = scaleOf(tester);
      await tester.pump(frame);
      final sinking = before - scaleOf(tester);
      expect(sinking, greaterThan(0), reason: 'still going down');

      await gesture.up();
      await tester.pump();
      final lifted = scaleOf(tester);
      await tester.pump(frame);
      final after = scaleOf(tester);

      // A fixed curve restarts from rest and reverses on the spot. A spring
      // carries the speed, so it keeps sinking for a moment as it turns.
      expect(after, lessThan(lifted), reason: 'did not reverse in 1 frame');
      await tester.pumpAndSettle();
    });

    testWidgets('pressed again while springing back, it follows from where '
        'it is', (tester) async {
      await _pump(tester, scale: 0.9);
      final center = tester.getCenter(find.byKey(_target));
      final first = await tester.startGesture(center);
      await tester.pumpAndSettle();
      await first.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final mid = scaleOf(tester);
      expect(mid, inExclusiveRange(0.9, 1.0));

      final second = await tester.startGesture(center);
      await tester.pump();

      expect(
        (scaleOf(tester) - mid).abs(),
        lessThan(0.02),
        reason: 'no jump back to 100% or to 90%',
      );
      await second.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a row with scale 1 never moves', (tester) async {
      await _pump(tester, scale: 1);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_target)),
      );
      await tester.pump();
      await tester.pump(frame);

      expect(scaleOf(tester), 1);
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

      expect(
        find.descendant(
          of: find.byType(Pressable),
          matching: find.byType(ScaleTransition),
        ),
        findsNothing,
      );
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
