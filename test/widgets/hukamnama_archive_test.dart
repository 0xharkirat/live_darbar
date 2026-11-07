import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/core/hukamnama_archive.dart';
import 'package:live_darbar/src/core/store_links.dart';
import 'package:live_darbar/src/models/hukamnama.dart';
import 'package:live_darbar/src/models/sikh_date.dart';
import 'package:live_darbar/src/services/hukamnama_service.dart';
import 'package:live_darbar/src/views/app_router.dart';
import 'package:live_darbar/src/views/browser_title.dart';
import 'package:live_darbar/src/views/screens/hukamnama_screen.dart';

import '../support/app_harness.dart';

/// Hark, 7 November 2026: "archive of earlier hukamnama as well", "if someone
/// needs to read previous, like Chet app". A listener opens the Hukamnama of
/// an earlier day in the same reader as today's.
void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  /// 10:00 IST on 7 November 2026: SGPC's day is the 7th.
  final now = DateTime.utc(2026, 11, 7, 4, 30);

  final table = SangrandTable.fromJsonString(
    File('assets/data/sgpc_sangrands.json').readAsStringSync(),
  );

  const dateLine = ValueKey('reader-date');

  /// The days the reader asked the archive for.
  late List<DateTime> asked;

  /// The fixture as the text of any earlier day, noting the day asked for.
  Future<Hukamnama> recording(DateTime day) async {
    asked.add(day);
    return fixtureHukamnamaOn(day);
  }

  setUp(() => asked = []);

  /// The reader on top, and the name its route was pushed with.
  String? topRoute(WidgetTester tester) =>
      ModalRoute.of(tester.element(find.byType(HukamnamaScreen)))
          ?.settings
          .name;

  NavigatorState navigator(WidgetTester tester) =>
      Navigator.of(tester.element(find.byType(HukamnamaScreen)));

  /// The texts the share sheet is asked to send. The sheet is the phone's, so
  /// its channel is answered here.
  List<String> recordShares(WidgetTester tester) {
    const channel = MethodChannel('dev.fluttercommunity.plus/share');
    final shared = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        shared.add((call.arguments as Map)['text'] as String);
        return 'dev.fluttercommunity.plus/share/unavailable';
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    return shared;
  }

  Future<void> openReader(
    WidgetTester tester,
    String route, {
    bool web = false,
    String locale = 'en',
    Future<Hukamnama> Function(DateTime day)? earlierDay,
    bool tall = false,
  }) async {
    await pumpApp(
      tester,
      initialRoute: route,
      clock: now,
      web: web,
      locale: locale,
      // A tall page builds the whole list, down to the PDF link at its end.
      size: tall
          ? const Size(1206, 6000)
          : web
              ? desktop
              : phone,
      sangrandTable: table,
      earlierDay: earlierDay ?? recording,
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byKey(dateLine));
    await tester.pumpAndSettle();
  }

  /// Turns the wheel to [day], as a finger on it would.
  void pick(WidgetTester tester, DateTime day) {
    tester
        .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
        .onDateTimeChanged(DateTime(day.year, day.month, day.day));
  }

  group('the address', () {
    test('names a day: /hukamnama/YYYY-MM-DD', () {
      expect(
        AppRoutes.hukamnamaOn(DateTime.utc(2026, 11, 1)),
        '/hukamnama/2026-11-01',
      );
    });

    test('reads a good day back', () {
      expect(
        AppRoutes.hukamnamaDayOf('/hukamnama/2026-11-01'),
        DateTime.utc(2026, 11, 1),
      );
      expect(
        AppRoutes.hukamnamaDayOf(
            AppRoutes.hukamnamaOn(DateTime.utc(2019, 4, 14))),
        DateTime.utc(2019, 4, 14),
      );
    });

    test('reads no day from the plain address', () {
      expect(AppRoutes.hukamnamaDayOf('/hukamnama'), isNull);
      expect(AppRoutes.hukamnamaDayOf('/hukamnama/'), isNull);
      expect(AppRoutes.hukamnamaDayOf(null), isNull);
      expect(AppRoutes.hukamnamaDayOf('/about'), isNull);
    });

    test('reads no day from a bad one', () {
      for (final bad in [
        '/hukamnama/garbage',
        '/hukamnama/2026-13-45',
        '/hukamnama/2026-02-30',
        '/hukamnama/2026-1-1',
        '/hukamnama/20261101',
        '/hukamnama/2026-11-01/more',
        '/hukamnama/2026-11-01x',
      ]) {
        expect(AppRoutes.hukamnamaDayOf(bad), isNull, reason: bad);
      }
    });

    test('is a page of the reader: the tab is named for it', () {
      final route = AppRoutes.hukamnamaOn(DateTime.utc(2026, 11, 1));
      expect(
        browserTitleFor(route, en),
        browserTitleFor(AppRoutes.hukamnama, en),
      );
    });

    test('the shared link names the day', () {
      expect(
        hukamnamaWebUrlOn(DateTime.utc(2026, 11, 1)),
        'https://darbar.live/app/hukamnama/2026-11-01',
      );
      expect(kHukamnamaWebUrl, 'https://darbar.live/app/hukamnama');
    });
  });

  group('how far back it goes', () {
    final today = DateTime.utc(2026, 11, 7);

    test('on the web: 30 days, as far as the mirror keeps', () {
      expect(
        hukamnamaArchiveFloor(today, web: true),
        DateTime.utc(2026, 10, 8),
      );
    });

    test('on a phone: the 1st of January 2012', () {
      expect(
        hukamnamaArchiveFloor(today, web: false),
        DateTime.utc(2012, 1, 1),
      );
    });
  });

  group('the reader for an earlier day', () {
    testWidgets('names the day in its date line', (tester) async {
      await openReader(tester, '/hukamnama/2026-11-01');

      expect(topRoute(tester), '/hukamnama/2026-11-01');
      expect(asked, [DateTime.utc(2026, 11, 1)]);
      // The Ang is the one of that day, and the Sikh date is that day's.
      expect(find.text('Ang 601 · 16 Katak 558 · 1 November'), findsOneWidget);
    });

    testWidgets('names the year of a day from another year', (tester) async {
      await openReader(tester, '/hukamnama/2019-04-14');

      // 2019 is before the sangrand table, so there is no Sikh date to show.
      expect(find.text('Ang 614 · 14 April 2019'), findsOneWidget);
    });

    testWidgets('in Punjabi, the date and the year are in Gurmukhi digits', (
      tester,
    ) async {
      await openReader(tester, '/hukamnama/2019-04-14', locale: 'pa');

      expect(find.text('ਅੰਗ ੬੧੪ · ੧੪ ਅਪ੍ਰੈਲ ੨੦੧੯'), findsOneWidget);
    });

    testWidgets('does not call it "not out yet": it is a day of its own', (
      tester,
    ) async {
      await openReader(tester, '/hukamnama/2026-11-01');

      expect(find.textContaining('not out yet'), findsNothing);
    });

    testWidgets('has Share, and no Listen or SGPC PDF, which are for today', (
      tester,
    ) async {
      await openReader(tester, '/hukamnama/2026-11-01', tall: true);

      expect(find.text(en.share), findsOneWidget);
      expect(find.text(en.listen), findsNothing);
      expect(find.text(en.sgpc_pdf), findsNothing);
      // The page is built to its end: the source link is there.
      expect(find.textContaining('SGPC'), findsWidgets);
    });

    testWidgets('keeps the reading options', (tester) async {
      await openReader(tester, '/hukamnama/2026-11-01');

      expect(find.byKey(const ValueKey('reader-options')), findsOneWidget);
    });

    testWidgets('Share sends a link to that day', (tester) async {
      final shared = recordShares(tester);
      await openReader(tester, '/hukamnama/2026-11-01');

      await tester.tap(find.text(en.share));
      await tester.pumpAndSettle();

      expect(shared, hasLength(1));
      expect(shared.single, contains('$kHukamnamaWebUrl/2026-11-01'));
      expect(shared.single, contains(en.share_hukamnama_footer_day));
      expect(shared.single, isNot(contains('listen')));
    });

    testWidgets(
        'a day with no text gets a calm note, and a way to choose '
        'another', (tester) async {
      await openReader(
        tester,
        '/hukamnama/2026-11-01',
        earlierDay: (day) async {
          throw HukamnamaNotPublishedException(day);
        },
      );

      expect(find.text(en.archive_none), findsOneWidget);
      expect(find.text(en.archive_other_day), findsOneWidget);
      // Not today's message, and no retry: asking again will not change it.
      expect(find.text(en.hukamnama_unavailable), findsNothing);
      expect(find.text(en.retry), findsNothing);
      expect(find.text(en.sgpc_pdf), findsNothing);

      await tester.tap(find.text(en.archive_other_day));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoDatePicker), findsOneWidget);
    });

    testWidgets('a failure to load says so and offers a retry', (tester) async {
      var calls = 0;
      await openReader(
        tester,
        '/hukamnama/2026-11-01',
        earlierDay: (day) async {
          calls++;
          if (calls == 1) throw const HukamnamaException('offline');
          return fixtureHukamnamaOn(day);
        },
      );

      expect(find.text(en.archive_failed), findsOneWidget);

      await tester.tap(find.text(en.retry));
      await tester.pumpAndSettle();

      expect(find.text(en.archive_failed), findsNothing);
      expect(find.text('Ang 601 · 16 Katak 558 · 1 November'), findsOneWidget);
      expect(calls, 2);
    });

    group('on a Sangrand', () {
      // 16 November 2026 is 1 Maghar 558.
      testWidgets('the pauri of that month follows the Hukamnama', (
        tester,
      ) async {
        await pumpApp(
          tester,
          size: const Size(1206, 6000),
          initialRoute: '/hukamnama/2026-11-16',
          clock: DateTime.utc(2026, 11, 20, 4, 30),
          sangrandTable: table,
          earlierDay: recording,
        );
        await tester.pumpAndSettle();

        expect(
            find.text('Ang 616 · 1 Maghar 558 · 16 November'), findsOneWidget);
        expect(find.text(en.sangrand_title), findsOneWidget);
        expect(
          find.textContaining('ਮੰਘਿਰਿ ਮਾਹਿ ਸੋਹੰਦੀਆ', findRichText: true),
          findsOneWidget,
        );
      });

      testWidgets('on any other day there is no pauri', (tester) async {
        await pumpApp(
          tester,
          size: const Size(1206, 6000),
          initialRoute: '/hukamnama/2026-11-15',
          clock: DateTime.utc(2026, 11, 20, 4, 30),
          sangrandTable: table,
          earlierDay: recording,
        );
        await tester.pumpAndSettle();

        expect(
            find.text('Ang 615 · 30 Katak 558 · 15 November'), findsOneWidget);
        expect(find.text(en.sangrand_title), findsNothing);
      });
    });
  });

  group('today\'s reader, with no day', () {
    testWidgets('is as it was: Listen and the PDF, no year', (tester) async {
      await openReader(tester, AppRoutes.hukamnama, tall: true);

      expect(asked, isEmpty);
      expect(find.text(en.listen), findsOneWidget);
      expect(find.text(en.share), findsOneWidget);
      expect(find.text(en.sgpc_pdf), findsOneWidget);
      // The harness text is the one of 2 November, and 7 November is today.
      expect(find.textContaining('not out yet'), findsOneWidget);
      expect(find.text('Ang 668 · 17 Katak 558 · 2 November'), findsOneWidget);
    });

    testWidgets('Share sends the plain link, and says "listen"', (
      tester,
    ) async {
      final shared = recordShares(tester);
      await openReader(tester, AppRoutes.hukamnama);

      await tester.tap(find.text(en.share));
      await tester.pumpAndSettle();

      expect(
        shared.single,
        endsWith('${en.share_hukamnama_footer} $kHukamnamaWebUrl'),
      );
    });
  });

  group('a bad or future day', () {
    for (final route in [
      '/hukamnama/garbage',
      '/hukamnama/2026-02-30',
      '/hukamnama/2026-11-08', // tomorrow at Amritsar
      '/hukamnama/2030-01-01',
      '/hukamnama/2026-11-07', // today
    ]) {
      testWidgets('$route opens today\'s reader', (tester) async {
        await openReader(tester, route);

        expect(find.byType(HukamnamaScreen), findsOneWidget);
        expect(asked, isEmpty, reason: 'nothing is fetched for it');
        expect(find.text(en.listen), findsOneWidget);
        expect(
            find.text('Ang 668 · 17 Katak 558 · 2 November'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('the date line', () {
    testWidgets('is a button, with a calendar, on today\'s reader', (
      tester,
    ) async {
      await openReader(tester, AppRoutes.hukamnama);

      expect(find.byKey(dateLine), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(dateLine),
          matching: find.byIcon(CupertinoIcons.calendar),
        ),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(find.byKey(dateLine)).label,
        'Ang 668 · 17 Katak 558 · 2 November, ${en.hukamnama_pick_day}',
      );
    });

    testWidgets('is as large as a finger needs', (tester) async {
      await openReader(tester, AppRoutes.hukamnama);

      expect(tester.getSize(find.byKey(dateLine)).height,
          greaterThanOrEqualTo(44));
    });
  });

  group('the sheet', () {
    testWidgets(
        'opens from the date line, with a wheel from the floor to '
        'today', (tester) async {
      await openReader(tester, AppRoutes.hukamnama);
      await openSheet(tester);

      expect(find.text(en.archive_title), findsOneWidget);
      expect(find.text(en.archive_body), findsOneWidget);
      final picker = tester.widget<CupertinoDatePicker>(
        find.byType(CupertinoDatePicker),
      );
      expect(picker.mode, CupertinoDatePickerMode.date);
      expect(picker.minimumDate, DateTime(2012));
      expect(picker.maximumDate, DateTime(2026, 11, 7));
      // It starts on yesterday: the first day there is to read.
      expect(picker.initialDateTime, DateTime(2026, 11, 6));
    });

    testWidgets('on the web, reaches back 30 days', (tester) async {
      await openReader(tester, AppRoutes.hukamnama, web: true);
      await openSheet(tester);

      final picker = tester.widget<CupertinoDatePicker>(
        find.byType(CupertinoDatePicker),
      );
      expect(picker.minimumDate, DateTime(2026, 10, 8));
      expect(picker.maximumDate, DateTime(2026, 11, 7));
      expect(find.text(en.archive_body_web('30')), findsOneWidget);
    });

    testWidgets('Open reads the day on the wheel', (tester) async {
      await openReader(tester, AppRoutes.hukamnama);
      await openSheet(tester);

      pick(tester, DateTime(2026, 11, 3));
      await tester.tap(find.text(en.archive_open));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoDatePicker), findsNothing);
      expect(topRoute(tester), '/hukamnama/2026-11-03');
      expect(asked, [DateTime.utc(2026, 11, 3)]);
      expect(find.text('Ang 603 · 18 Katak 558 · 3 November'), findsOneWidget);
    });

    testWidgets('Open with no turn of the wheel reads yesterday', (
      tester,
    ) async {
      await openReader(tester, AppRoutes.hukamnama);
      await openSheet(tester);

      await tester.tap(find.text(en.archive_open));
      await tester.pumpAndSettle();

      expect(topRoute(tester), '/hukamnama/2026-11-06');
    });

    testWidgets('a turn of the real wheel changes what Open reads', (
      tester,
    ) async {
      await openReader(tester, AppRoutes.hukamnama);
      await openSheet(tester);

      // The month wheel is the widest, so it is in the middle of the picker.
      // One step down is the month before, on the same day: 6 October.
      await tester.drag(find.byType(CupertinoDatePicker), const Offset(0, 32));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.archive_open));
      await tester.pumpAndSettle();

      expect(topRoute(tester), '/hukamnama/2026-10-06');
    });

    testWidgets('Yesterday is one tap', (tester) async {
      await openReader(tester, AppRoutes.hukamnama);
      await openSheet(tester);

      await tester.tap(find.text(en.archive_yesterday));
      await tester.pumpAndSettle();

      expect(topRoute(tester), '/hukamnama/2026-11-06');
      expect(asked, [DateTime.utc(2026, 11, 6)]);
    });

    testWidgets('from an earlier day, it starts on that day', (tester) async {
      await openReader(tester, '/hukamnama/2026-11-03');
      await openSheet(tester);

      expect(
        tester
            .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
            .initialDateTime,
        DateTime(2026, 11, 3),
      );
    });

    testWidgets('from an earlier day, another day takes its place', (
      tester,
    ) async {
      await openReader(tester, '/hukamnama/2026-11-03');
      await openSheet(tester);

      pick(tester, DateTime(2026, 11, 2));
      await tester.tap(find.text(en.archive_open));
      await tester.pumpAndSettle();
      expect(topRoute(tester), '/hukamnama/2026-11-02');

      // Back goes to today's reader, not to the day before it.
      navigator(tester).pop();
      await tester.pumpAndSettle();
      expect(topRoute(tester), AppRoutes.hukamnama);
    });

    testWidgets('from an earlier day, today goes back to today\'s reader', (
      tester,
    ) async {
      await openReader(tester, '/hukamnama/2026-11-03');
      await openSheet(tester);

      pick(tester, DateTime(2026, 11, 7));
      await tester.tap(find.text(en.archive_open));
      await tester.pumpAndSettle();

      expect(topRoute(tester), AppRoutes.hukamnama);
      expect(find.text(en.listen), findsOneWidget);
    });

    testWidgets('on today\'s reader, today only closes the sheet', (
      tester,
    ) async {
      await openReader(tester, AppRoutes.hukamnama);
      await openSheet(tester);

      pick(tester, DateTime(2026, 11, 7));
      await tester.tap(find.text(en.archive_open));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoDatePicker), findsNothing);
      expect(topRoute(tester), AppRoutes.hukamnama);
      navigator(tester).pop();
      await tester.pumpAndSettle();
      expect(find.byType(HukamnamaScreen), findsNothing,
          reason: 'one pop leaves the reader: no second reader was pushed');
    });

    testWidgets('in Punjabi, the sheet speaks Punjabi', (tester) async {
      final pa = lookupAppLocalizations(const Locale('pa'));
      await openReader(tester, AppRoutes.hukamnama, locale: 'pa');
      await openSheet(tester);

      expect(find.text(pa.archive_title), findsOneWidget);
      expect(find.text(pa.archive_open), findsOneWidget);
      expect(find.text(pa.archive_yesterday), findsOneWidget);
    });
  });
}
