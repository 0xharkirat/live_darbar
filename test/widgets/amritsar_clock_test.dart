import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/views/app_router.dart';
import 'package:live_darbar/src/views/widgets/amritsar_clock.dart';
import 'package:live_darbar/src/views/widgets/live_badge.dart';
import 'package:live_darbar/src/views/widgets/on_image_chip.dart';

import '../support/app_harness.dart';
import '../support/load_fonts.dart';

/// The time in Amritsar on the Live Kirtan card. A listener abroad reads it to
/// know which part of the day's programme plays now.
void main() {
  // The real fonts, because 2 tests ask whether the row fits on a phone.
  setUpAll(loadAppFonts);

  // 15 November 2026, 14:13 UTC: 7:43 PM in Amritsar, 1:13 AM in Sydney the
  // next day, and 2:13 PM in London.
  final evening = DateTime.utc(2026, 11, 15, 14, 13);

  /// A clock that starts at [start] and moves with the test's fake time, as
  /// the real clock moves with the timers on a phone.
  DateTime Function() clockFrom(WidgetTester tester, DateTime start) {
    final zero = tester.binding.clock.now();
    return () => start.add(tester.binding.clock.now().difference(zero));
  }

  Finder liveCard() => find
      .ancestor(of: find.byType(LiveBadge), matching: find.byType(AspectRatio))
      .first;

  /// The LIVE badge with its dark backing.
  Finder badgeChip() => find
      .descendant(of: find.byType(LiveBadge), matching: find.byType(OnImageChip))
      .first;

  AmritsarClockState clockState(WidgetTester tester) => tester
      .state<AmritsarClockState>(find.byType(AmritsarClock, skipOffstage: false));

  void lifecycle(WidgetTester tester, List<AppLifecycleState> states) {
    for (final state in states) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
  }

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

  testWidgets('Punjabi: the card shows the Punjabi words, on 24-hour time', (
    tester,
  ) async {
    await pumpApp(tester, locale: 'pa', clock: evening);

    expect(find.text('ਅੰਮ੍ਰਿਤਸਰ ਵਿੱਚ 19:43'), findsOneWidget);
  });

  testWidgets('a phone set to 24-hour time shows 19:43', (tester) async {
    tester.platformDispatcher.alwaysUse24HourFormatTestValue = true;
    addTearDown(tester.platformDispatcher.clearAlwaysUse24HourTestValue);
    await pumpApp(tester, clock: evening);

    expect(find.text('19:43 in Amritsar'), findsOneWidget);
  });

  testWidgets('a clock read in the phone\'s own zone gives the same time', (
    tester,
  ) async {
    // The same instant as `evening`, on the zone of the machine that runs the
    // test. `test/core/clock_test.dart` checks the sum itself, and
    // `TZ=Australia/Sydney flutter test` runs this file in another zone.
    await pumpApp(tester, clock: evening.toLocal());

    expect(find.text('7:43 PM in Amritsar'), findsOneWidget);
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

  testWidgets('the time is no taller than the LIVE badge beside it', (
    tester,
  ) async {
    // The card is an AspectRatio, so only the badge row can grow into the
    // painting. The row keeps the badge's height.
    for (final locale in const ['en', 'pa']) {
      await pumpApp(tester, locale: locale, clock: evening);

      final badge = tester.getRect(badgeChip());
      final clock = tester.getRect(find.byType(AmritsarClock));
      expect(clock.height, lessThanOrEqualTo(badge.height + 0.5), reason: locale);
    }
  });

  testWidgets(
    'large text on a 320-point phone: the time and the badge do not overlap',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final locale in const ['en', 'pa']) {
        await pumpApp(
          tester,
          locale: locale,
          clock: DateTime.utc(2026, 11, 15, 7, 13), // 12:43 PM, the widest.
          size: const Size(960, 1704),
          pixelRatio: 3,
        );

        final card = tester.getRect(liveCard());
        expect(card.width, lessThan(320), reason: locale);
        final badge = tester.getRect(badgeChip());
        final clock = tester.getRect(find.byType(AmritsarClock));
        expect(clock.left, greaterThan(badge.right), reason: locale);
        expect(clock.right, lessThanOrEqualTo(card.right - 16 + 0.5),
            reason: locale);
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
    final clock = clockFrom(tester, DateTime.utc(2026, 11, 15, 14, 13, 59));
    await pumpApp(tester, readClock: clock);
    expect(find.text('7:43 PM in Amritsar'), findsOneWidget);

    // pumpApp took 400 ms. 1 ms before the minute, it has not changed yet.
    await tester.pump(const Duration(milliseconds: 599));
    expect(find.text('7:43 PM in Amritsar'), findsOneWidget);

    // 14:14:00.000 UTC: the real minute changes, and so does the card.
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('7:44 PM in Amritsar'), findsOneWidget);

    await tester.pump(const Duration(minutes: 1));
    expect(find.text('7:45 PM in Amritsar'), findsOneWidget);
  });

  testWidgets('a clock that stands still lets Home settle', (tester) async {
    // 50 ms before a minute ends, on a clock that never moves: the timer
    // fires, finds the same minute, and asks for no frame.
    await pumpApp(tester, clock: DateTime.utc(2026, 11, 15, 14, 13, 59, 950));

    await tester.pumpAndSettle();
    expect(find.text('7:43 PM in Amritsar'), findsOneWidget);
  });

  testWidgets('a page over Home stops the clock; back on Home it is right', (
    tester,
  ) async {
    final clock = clockFrom(tester, DateTime.utc(2026, 11, 15, 14, 13, 30));
    await pumpApp(tester, readClock: clock);
    expect(clockState(tester).isTicking, isTrue);

    tester.state<NavigatorState>(find.byType(Navigator).first)
        .pushNamed(AppRoutes.about);
    await tester.pumpAndSettle();
    expect(clockState(tester).isTicking, isFalse);

    await tester.pump(const Duration(minutes: 2));
    // Home is still built under About, but its clock did not tick.
    expect(
      find.text('7:43 PM in Amritsar', skipOffstage: false),
      findsOneWidget,
    );

    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    expect(clockState(tester).isTicking, isTrue);
    // 14:13:30, 2 minutes under About, and the page moves: 14:15:3x.
    expect(find.text('7:45 PM in Amritsar'), findsOneWidget);
  });

  testWidgets('in the background the clock stops; back in front it is right', (
    tester,
  ) async {
    addTearDown(() => lifecycle(tester, const [AppLifecycleState.resumed]));
    final clock = clockFrom(tester, DateTime.utc(2026, 11, 15, 14, 13, 30));
    await pumpApp(tester, readClock: clock);

    lifecycle(tester, const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]);
    expect(clockState(tester).isTicking, isFalse);
    await tester.pump(const Duration(minutes: 2));

    lifecycle(tester, const [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
    ]);
    await tester.pump();
    expect(clockState(tester).isTicking, isTrue);
    expect(find.text('7:45 PM in Amritsar'), findsOneWidget);
  });

  testWidgets('under the control centre (inactive) the clock keeps going', (
    tester,
  ) async {
    addTearDown(() => lifecycle(tester, const [AppLifecycleState.resumed]));
    final clock = clockFrom(tester, DateTime.utc(2026, 11, 15, 14, 13, 30));
    await pumpApp(tester, readClock: clock);

    lifecycle(tester, const [AppLifecycleState.inactive]);
    expect(clockState(tester).isTicking, isTrue);
    await tester.pump(const Duration(minutes: 1));
    expect(find.text('7:44 PM in Amritsar'), findsOneWidget);
  });
}
