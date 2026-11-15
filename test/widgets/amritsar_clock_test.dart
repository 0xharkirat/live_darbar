import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/views/app_router.dart';
import 'package:live_darbar/src/views/widgets/amritsar_clock.dart';
import 'package:live_darbar/src/views/widgets/live_badge.dart';

import '../support/app_harness.dart';

/// The time in Amritsar on the Live Kirtan card. A listener abroad reads it to
/// know which part of the day's programme plays now.
void main() {
  // 15 November 2026, 14:13 UTC: 7:43 PM in Amritsar, 1:13 AM in Sydney the
  // next day, and 2:13 PM in London.
  final evening = DateTime.utc(2026, 11, 15, 14, 13);

  /// A clock that moves only when the test steps it, together with the fake
  /// time of the test.
  ({DateTime Function() read, Future<void> Function(Duration) step}) clockAt(
    WidgetTester tester,
    DateTime start,
  ) {
    var now = start;
    return (
      read: () => now,
      step: (by) async {
        now = now.add(by);
        await tester.pump(by);
      },
    );
  }

  Finder liveCard() => find
      .ancestor(of: find.byType(LiveBadge), matching: find.byType(AspectRatio))
      .first;

  /// The LIVE badge with its dark backing.
  Finder badgeChip() => find
      .descendant(of: find.byType(LiveBadge), matching: find.byType(OnImageChip))
      .first;

  testWidgets('English: the Live Kirtan card shows the time in Amritsar', (
    tester,
  ) async {
    await pumpApp(tester, clock: evening);

    expect(find.text('7:43 PM in Amritsar'), findsOneWidget);
    expect(
      find.descendant(of: liveCard(), matching: find.byType(AmritsarClock)),
      findsOneWidget,
    );
  });

  testWidgets('Punjabi: the card shows the Punjabi words', (tester) async {
    await pumpApp(tester, locale: 'pa', clock: evening);

    expect(find.text('ਅੰਮ੍ਰਿਤਸਰ ਵਿੱਚ 19:43'), findsOneWidget);
  });

  testWidgets('a phone set to 24-hour time shows 19:43', (tester) async {
    tester.platformDispatcher.alwaysUse24HourFormatTestValue = true;
    addTearDown(tester.platformDispatcher.clearAlwaysUse24HourTestValue);
    await pumpApp(tester, clock: evening);

    expect(find.text('19:43 in Amritsar'), findsOneWidget);
  });

  testWidgets('a phone in Sydney or London still shows the time in India', (
    tester,
  ) async {
    // The listener's zone and a clock read on the listener's wall clock.
    // Neither moves the time in Amritsar. `TZ=Australia/Sydney flutter test`
    // checks the phone's own zone the same way.
    for (final zone in const [Duration(hours: 11), Duration.zero]) {
      await pumpApp(tester, clock: evening.toLocal(), localOffset: (_) => zone);

      expect(find.text('7:43 PM in Amritsar'), findsOneWidget);
    }
  });

  testWidgets('the time sits on the LIVE badge row, at the right of the card', (
    tester,
  ) async {
    await pumpApp(tester, clock: evening);

    final card = tester.getRect(liveCard());
    final badge = tester.getRect(badgeChip());
    final time = tester.getRect(find.byType(AmritsarClock));
    expect(time.center.dy, moreOrLessEquals(badge.center.dy, epsilon: 1));
    expect(time.left, greaterThan(badge.right));
    // The same 16 points from the card's right edge as the badge has from
    // its left edge.
    expect(card.right - time.right, moreOrLessEquals(16, epsilon: 0.5));
  });

  testWidgets('the card keeps its height', (tester) async {
    await pumpApp(tester, clock: evening);

    final card = tester.getRect(liveCard());
    // The phone is 402 points wide; the card keeps its 1.4 shape.
    expect(card.height, moreOrLessEquals(card.width / 1.4, epsilon: 0.5));
    // The time takes no more height than the LIVE badge beside it.
    final badge = tester.getRect(badgeChip());
    final clock = tester.getRect(find.byType(AmritsarClock));
    expect(clock.height, lessThanOrEqualTo(badge.height + 0.5));
  });

  testWidgets(
    'large text on a small phone: the time and the badge do not overlap',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final locale in const ['en', 'pa']) {
        await pumpApp(
          tester,
          locale: locale,
          clock: DateTime.utc(2026, 11, 15, 7, 13), // 12:43 PM, the widest.
          size: const Size(960, 1704), // 320 points wide, at 3x.
        );

        final card = tester.getRect(liveCard());
        final badge = tester.getRect(badgeChip());
        final clock = tester.getRect(find.byType(AmritsarClock));
        expect(clock.overlaps(badge), isFalse, reason: locale);
        expect(clock.right, lessThanOrEqualTo(card.right), reason: locale);
        expect(tester.takeException(), isNull, reason: locale);
      }
    },
  );

  testWidgets('the screen reader says "Time in Amritsar, 7:43 PM"', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(tester, clock: evening);

    expect(find.bySemanticsLabel('Time in Amritsar, 7:43 PM'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('the minute changes on the minute', (tester) async {
    final clock = clockAt(tester, DateTime.utc(2026, 11, 15, 14, 13, 59, 400));
    await pumpApp(tester, readClock: clock.read);
    expect(find.text('7:43 PM in Amritsar'), findsOneWidget);

    await clock.step(const Duration(milliseconds: 599));
    expect(find.text('7:43 PM in Amritsar'), findsOneWidget);

    // 14:14:00.000 UTC: the real minute changes, and so does the card.
    await clock.step(const Duration(milliseconds: 1));
    expect(find.text('7:44 PM in Amritsar'), findsOneWidget);

    await clock.step(const Duration(minutes: 1));
    expect(find.text('7:45 PM in Amritsar'), findsOneWidget);
  });

  testWidgets('a page over Home stops the clock; back on Home it is right', (
    tester,
  ) async {
    final clock = clockAt(tester, DateTime.utc(2026, 11, 15, 14, 13, 30));
    await pumpApp(tester, readClock: clock.read);

    tester.state<NavigatorState>(find.byType(Navigator).first)
        .pushNamed(AppRoutes.about);
    await tester.pumpAndSettle();
    await clock.step(const Duration(minutes: 2));

    // Home is still built under About, but its clock did not tick.
    expect(
      find.text('7:43 PM in Amritsar', skipOffstage: false),
      findsOneWidget,
    );

    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    expect(find.text('7:45 PM in Amritsar'), findsOneWidget);

    await clock.step(const Duration(seconds: 30));
    expect(find.text('7:46 PM in Amritsar'), findsOneWidget);
  });

  testWidgets('in the background the clock stops; back in front it is right', (
    tester,
  ) async {
    final clock = clockAt(tester, DateTime.utc(2026, 11, 15, 14, 13, 30));
    await pumpApp(tester, readClock: clock.read);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await clock.step(const Duration(minutes: 2));
    expect(find.text('7:43 PM in Amritsar'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('7:45 PM in Amritsar'), findsOneWidget);

    await clock.step(const Duration(seconds: 30));
    expect(find.text('7:46 PM in Amritsar'), findsOneWidget);
  });
}
