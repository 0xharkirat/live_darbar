import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/core/motion.dart';
import 'package:live_darbar/src/views/widgets/spring_scale.dart';

Future<void> _pump(WidgetTester tester, double scale) {
  return tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SpringScale(
          scale: scale,
          spring: Motion.artwork,
          child: const SizedBox(width: 100, height: 100),
        ),
      ),
    ),
  );
}

double _scale(WidgetTester tester) =>
    tester.widget<ScaleTransition>(find.byType(ScaleTransition)).scale.value;

void main() {
  testWidgets('starts at its scale, with no movement', (tester) async {
    await _pump(tester, 0.86);

    expect(_scale(tester), 0.86);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('settles on the new scale, exactly', (tester) async {
    await _pump(tester, 0.86);
    await _pump(tester, 1);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(_scale(tester), 1);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('overshoots a hair, because the spring has a bounce', (
    tester,
  ) async {
    await _pump(tester, 0.86);
    await _pump(tester, 1);
    await tester.pump();

    var peak = 0.0;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      peak = _scale(tester) > peak ? _scale(tester) : peak;
    }
    expect(peak, greaterThan(1));
    expect(peak, lessThan(1.03));
  });

  testWidgets('keeps its speed when the target flips mid-move', (
    tester,
  ) async {
    await _pump(tester, 0.86);
    await _pump(tester, 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final moving = _scale(tester);
    expect(moving, inExclusiveRange(0.87, 0.99));

    // Back down while it is still rising. A spring carries the speed: it
    // keeps rising for a moment, then turns. A curve restarted from here
    // would turn at once.
    await _pump(tester, 0.86);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(_scale(tester), greaterThan(moving));
  });

  testWidgets('Reduce Motion: it jumps and nothing moves', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await _pump(tester, 0.86);
    await _pump(tester, 1);
    await tester.pump();

    expect(_scale(tester), 1);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
