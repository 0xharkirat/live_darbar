import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/core/motion.dart';
import 'package:live_darbar/src/views/widgets/app_sheet.dart';

const _sheet = Key('sheet');

/// Opens a 200 point sheet and returns the route it made.
Future<ModalRoute<void>> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  late BuildContext context;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (c) {
          context = c;
          return const SizedBox.expand();
        },
      ),
    ),
  );

  showAppSheet<void>(
    context,
    (_) => const SizedBox(key: _sheet, height: 200, width: double.infinity),
  );
  await tester.pump();
  return ModalRoute.of(tester.element(find.byKey(_sheet)))!;
}

double _opacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find
          .ancestor(
            of: find.byKey(_sheet),
            matching: find.byType(FadeTransition),
          )
          .first,
    )
    .opacity
    .value;

void _reduceMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

void main() {
  group('with motion', () {
    testWidgets('enters in 240 ms and leaves in 180 ms', (tester) async {
      final route = await _open(tester);

      expect(route.transitionDuration, Motion.standard);
      expect(route.reverseTransitionDuration, Motion.quick);
    });

    testWidgets('slides up from below the screen', (tester) async {
      await _open(tester);
      await tester.pump(const Duration(milliseconds: 60));
      final partway = tester.getTopLeft(find.byKey(_sheet)).dy;

      await tester.pumpAndSettle();
      final settled = tester.getTopLeft(find.byKey(_sheet)).dy;

      expect(partway, greaterThan(settled));
    });

    testWidgets('does not fade the sheet', (tester) async {
      await _open(tester);

      expect(
        find.ancestor(
          of: find.byKey(_sheet),
          matching: find.byType(FadeTransition),
        ),
        findsNothing,
      );
    });
  });

  group('with Reduce Motion', () {
    testWidgets('enters in 180 ms and leaves in 120 ms', (tester) async {
      _reduceMotion(tester);
      final route = await _open(tester);

      expect(route.transitionDuration, Motion.quick);
      expect(route.reverseTransitionDuration, Motion.press);
    });

    testWidgets('fades in over a real 180 ms and does not slide', (
      tester,
    ) async {
      _reduceMotion(tester);
      await _open(tester);

      await tester.pump(const Duration(milliseconds: 60));
      final partway = tester.getTopLeft(find.byKey(_sheet)).dy;
      final partwayOpacity = _opacity(tester);

      await tester.pumpAndSettle();
      final settled = tester.getTopLeft(find.byKey(_sheet)).dy;

      expect(partway, settled, reason: 'no movement');
      expect(partwayOpacity, inExclusiveRange(0, 1), reason: 'still fading');
      expect(_opacity(tester), 1);
    });

    testWidgets('fades out over 120 ms, then goes', (tester) async {
      _reduceMotion(tester);
      await _open(tester);
      await tester.pumpAndSettle();
      final settled = tester.getTopLeft(find.byKey(_sheet)).dy;

      Navigator.of(tester.element(find.byKey(_sheet))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));

      expect(tester.getTopLeft(find.byKey(_sheet)).dy, settled);
      expect(_opacity(tester), inExclusiveRange(0, 1));

      await tester.pump(const Duration(milliseconds: 120));
      await tester.pump();
      expect(find.byKey(_sheet), findsNothing);
    });
  });
}
