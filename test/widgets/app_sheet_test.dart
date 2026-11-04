import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/core/motion.dart';
import 'package:live_darbar/src/views/widgets/app_sheet.dart';

const _sheet = Key('sheet');
const _list = Key('list');

late BuildContext _context;

/// Opens a 200 point sheet, or [content], and returns its route.
Future<AppSheetRoute<Object?>> _open(
  WidgetTester tester, {
  WidgetBuilder? content,
  Completer<Object?>? result,
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (c) {
          _context = c;
          return const SizedBox.expand();
        },
      ),
    ),
  );

  final future = showAppSheet<Object?>(
    _context,
    content ??
        (_) => const SizedBox(key: _sheet, height: 200, width: double.infinity),
  );
  if (result != null) unawaited(future.then(result.complete));
  await tester.pump();
  return ModalRoute.of(tester.element(find.byKey(_sheet)))!
      as AppSheetRoute<Object?>;
}

/// Runs the sheet's move to its end.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
}

double _top(WidgetTester tester) => tester.getTopLeft(find.byKey(_sheet)).dy;

/// A sheet taller than its screen would be, with a list that scrolls.
Widget _listSheet(BuildContext context) {
  return SizedBox(
    key: _sheet,
    height: 400,
    child: SingleChildScrollView(
      key: _list,
      controller: appSheetScrollController(context),
      child: Column(
        children: [
          for (var i = 0; i < 30; i++) SizedBox(height: 50, child: Text('$i')),
        ],
      ),
    ),
  );
}

double _scrolled(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels;

void _reduceMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

double _opacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find.ancestor(of: find.byKey(_sheet), matching: find.byType(Opacity)).first,
    )
    .opacity;

/// How many 16 ms frames until [done] holds, up to 2 seconds.
Future<int> _frames(WidgetTester tester, bool Function() done) async {
  var n = 0;
  while (!done() && n < 125) {
    await tester.pump(const Duration(milliseconds: 16));
    n++;
  }
  return n;
}

void main() {
  group('with motion', () {
    testWidgets('slides up from below the screen', (tester) async {
      await _open(tester);
      await tester.pump(const Duration(milliseconds: 60));
      final partway = _top(tester);
      await _settle(tester);

      expect(partway, greaterThan(_top(tester)));
      expect(_top(tester), 800 - 200);
    });

    testWidgets('does not fade the sheet', (tester) async {
      await _open(tester);
      await tester.pump(const Duration(milliseconds: 60));

      expect(
        find.ancestor(of: find.byKey(_sheet), matching: find.byType(Opacity)),
        findsNothing,
      );
    });

    testWidgets('settles on a spring, with no overshoot when it was not thrown', (
      tester,
    ) async {
      await _open(tester);
      final rest = 800 - 200;
      var last = double.infinity;
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final top = _top(tester);
        expect(top, lessThanOrEqualTo(last + 1e-6));
        expect(top, greaterThanOrEqualTo(rest - 1e-6));
        last = top;
      }
      expect(last, rest);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('leaves faster than it came', (tester) async {
      await _open(tester);
      final opened = await _frames(tester, () => !tester.hasRunningAnimations);

      Navigator.of(_context).pop();
      await tester.pump();
      final closed = await _frames(tester, () => !tester.hasRunningAnimations);

      expect(closed, lessThan(opened));
    });

    testWidgets('returns what pop hands it', (tester) async {
      final result = Completer<Object?>();
      await _open(tester, result: result);
      await _settle(tester);

      Navigator.of(_context).pop('done');
      await _settle(tester);

      expect(await result.future, 'done');
      expect(find.byKey(_sheet), findsNothing);
    });

    group('a finger', () {
      testWidgets('moves the sheet 1:1, from anywhere on it', (tester) async {
        await _open(tester);
        await _settle(tester);
        final rest = _top(tester);

        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(_sheet)),
        );
        await gesture.moveBy(const Offset(0, 30));
        await tester.pump();
        await gesture.moveBy(const Offset(0, 40));
        await tester.pump();

        // The slop is not taken off: the sheet follows the finger from where
        // the drag was recognised.
        expect(_top(tester), greaterThan(rest + 40));
        expect(_top(tester), lessThanOrEqualTo(rest + 70));
        await gesture.up();
      });

      testWidgets('a flick down closes it', (tester) async {
        await _open(tester);
        await _settle(tester);

        await tester.fling(find.byKey(_sheet), const Offset(0, 80), 1500);
        await _settle(tester);

        expect(find.byKey(_sheet), findsNothing);
      });

      testWidgets('a flick down closes it from the top edge too', (
        tester,
      ) async {
        await _open(tester);
        await _settle(tester);

        final top = tester.getTopLeft(find.byKey(_sheet)) + const Offset(200, 6);
        await tester.flingFrom(top, const Offset(0, 80), 1500);
        await _settle(tester);

        expect(find.byKey(_sheet), findsNothing);
      });

      testWidgets('a flick up keeps it open', (tester) async {
        await _open(tester);
        await _settle(tester);
        final rest = _top(tester);

        await tester.fling(find.byKey(_sheet), const Offset(0, -80), 1500);
        await _settle(tester);

        expect(_top(tester), rest);
      });

      testWidgets('a slow drag past halfway closes it', (tester) async {
        await _open(tester);
        await _settle(tester);

        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(_sheet)),
        );
        for (var i = 0; i < 12; i++) {
          await gesture.moveBy(const Offset(0, 10));
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.pump(const Duration(milliseconds: 300));
        await gesture.up();
        await _settle(tester);

        expect(find.byKey(_sheet), findsNothing);
      });

      testWidgets('a short, slow drag springs back', (tester) async {
        await _open(tester);
        await _settle(tester);
        final rest = _top(tester);

        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(_sheet)),
        );
        for (var i = 0; i < 4; i++) {
          await gesture.moveBy(const Offset(0, 10));
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.pump(const Duration(milliseconds: 300));
        await gesture.up();
        await _settle(tester);

        expect(_top(tester), rest);
      });

      testWidgets('pulled up past its place, it resists and settles back', (
        tester,
      ) async {
        await _open(tester);
        await _settle(tester);
        final rest = _top(tester);

        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(_sheet)),
        );
        for (var i = 0; i < 10; i++) {
          await gesture.moveBy(const Offset(0, -10));
          await tester.pump(const Duration(milliseconds: 50));
        }
        // 100 points of finger, and under a third of that in the sheet.
        expect(rest - _top(tester), lessThan(30));
        expect(rest - _top(tester), greaterThan(0));

        await gesture.up();
        await _settle(tester);
        expect(_top(tester), rest);
      });

      testWidgets('can catch it again while it is still settling', (
        tester,
      ) async {
        await _open(tester);
        await tester.pump(const Duration(milliseconds: 150));
        final mid = _top(tester);
        expect(mid, inExclusiveRange(600, 800), reason: 'still on its way');

        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(_sheet)),
        );
        await gesture.moveBy(const Offset(0, 30));
        await tester.pump();
        await gesture.moveBy(const Offset(0, 40));
        await tester.pump();

        expect(_top(tester), greaterThan(mid + 20));
        await gesture.up();
      });
    });

    group('a list in the sheet', () {
      testWidgets('hands a swipe down at its top to the sheet', (tester) async {
        await _open(tester, content: _listSheet);
        await _settle(tester);
        final rest = _top(tester);

        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(_list)),
        );
        await gesture.moveBy(const Offset(0, 40));
        await tester.pump();
        await gesture.moveBy(const Offset(0, 60));
        await tester.pump();

        // The finger's whole move after the drag began, and the list stays.
        expect(_top(tester), greaterThanOrEqualTo(rest + 60));
        expect(_scrolled(tester), 0);
        await gesture.up();
      });

      testWidgets('scrolls first when it is not at the top', (tester) async {
        await _open(tester, content: _listSheet);
        await _settle(tester);
        final rest = _top(tester);

        await tester.drag(find.byKey(_list), const Offset(0, -200));
        await tester.pump();
        expect(_scrolled(tester), greaterThan(100));
        final scrolled = _scrolled(tester);

        // Down again, but less than the list has scrolled: the list takes it.
        await tester.drag(find.byKey(_list), const Offset(0, 60));
        await tester.pump();

        expect(_scrolled(tester), lessThan(scrolled));
        expect(_top(tester), rest);
      });

      testWidgets('takes a flick down at its top and closes', (tester) async {
        await _open(tester, content: _listSheet);
        await _settle(tester);

        await tester.fling(find.byKey(_list), const Offset(0, 100), 1500);
        await _settle(tester);

        expect(find.byKey(_sheet), findsNothing);
      });

      testWidgets('a wheel in the sheet keeps its own drag', (tester) async {
        // The reminder's time picker is a wheel. A finger on it turns it.
        await _open(
          tester,
          content: (_) => SizedBox(
            key: _sheet,
            height: 200,
            child: ListWheelScrollView(
              itemExtent: 40,
              children: [for (var i = 0; i < 24; i++) Text('$i')],
            ),
          ),
        );
        await _settle(tester);
        final rest = _top(tester);

        await tester.drag(find.byType(ListWheelScrollView), const Offset(0, -60));
        await tester.pump();
        await tester.drag(find.byType(ListWheelScrollView), const Offset(0, 60));
        await tester.pump();

        expect(_top(tester), rest);
      });

      testWidgets('lets the list coast when the sheet is at rest', (
        tester,
      ) async {
        await _open(tester, content: _listSheet);
        await _settle(tester);

        await tester.fling(find.byKey(_list), const Offset(0, -150), 1500);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(_scrolled(tester), greaterThan(150));
        expect(find.byKey(_sheet), findsOneWidget);
      });
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
      final partway = _top(tester);
      final partwayOpacity = _opacity(tester);
      await _settle(tester);

      expect(partway, _top(tester), reason: 'no movement');
      expect(partwayOpacity, inExclusiveRange(0, 1), reason: 'still fading');
      expect(_opacity(tester), 1);
    });

    testWidgets('fades out over 120 ms, then goes', (tester) async {
      _reduceMotion(tester);
      await _open(tester);
      await _settle(tester);
      final settled = _top(tester);

      Navigator.of(_context).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      expect(_top(tester), settled);
      expect(_opacity(tester), inExclusiveRange(0, 1));

      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(_sheet), findsNothing);
    });

    testWidgets('a finger still moves it 1:1', (tester) async {
      _reduceMotion(tester);
      await _open(tester);
      await _settle(tester);
      final rest = _top(tester);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_sheet)),
      );
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();

      expect(_top(tester), greaterThan(rest + 40));
      await gesture.up();
    });

    testWidgets('a flick down closes it', (tester) async {
      _reduceMotion(tester);
      await _open(tester);
      await _settle(tester);

      await tester.fling(find.byKey(_sheet), const Offset(0, 80), 1500);
      await _settle(tester);

      expect(find.byKey(_sheet), findsNothing);
    });

    testWidgets('after a short drag it fades out in place, not sliding', (
      tester,
    ) async {
      _reduceMotion(tester);
      await _open(tester);
      await _settle(tester);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_sheet)),
      );
      for (var i = 0; i < 4; i++) {
        await gesture.moveBy(const Offset(0, 10));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await _settle(tester);
      final rest = _top(tester);

      Navigator.of(_context).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      expect(_top(tester), rest);
    });
  });
}
