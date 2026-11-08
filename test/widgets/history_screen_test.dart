import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/locale_controller.dart';
import 'package:live_darbar/src/controllers/sgpc_events_controller.dart';
import 'package:live_darbar/src/controllers/sikh_date_controller.dart';
import 'package:live_darbar/src/core/app_theme.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/clock.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/models/sgpc_day.dart';
import 'package:live_darbar/src/models/sgpc_event.dart';
import 'package:live_darbar/src/models/sikh_date.dart';
import 'package:live_darbar/src/services/reminder_platform.dart';
import 'package:live_darbar/src/views/screens/history_screen.dart';
import 'package:flutter/material.dart' show MaterialApp;
import 'package:shared_preferences/shared_preferences.dart';

import '../support/app_harness.dart' show reduceMotion;
import '../support/fake_reminder_platform.dart';

class _Locale extends LocaleController {
  _Locale(this.locale);

  final String locale;

  @override
  String build() => locale;
}

/// The Sikh history screen: the whole Nanakshahi year of events by month, past
/// days muted, today highlighted, opened on today.
void main() {
  final shipped = SgpcEventTable.fromJsonString(
    File('assets/data/sgpc_events_558.json').readAsStringSync(),
  );
  final en = lookupAppLocalizations(const Locale('en'));
  final pa = lookupAppLocalizations(const Locale('pa'));
  late FakeReminderPlatform phone;

  // 3 November 2026, the morning at Amritsar: 3 events fall on it.
  final nov3 = DateTime.utc(2026, 11, 3, 6);

  Future<void> pump(
    WidgetTester tester, {
    String locale = 'en',
    DateTime? now,
    SgpcEventTable? table,
    Map<String, Object> prefs = const {},
    double textScale = 1,
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    AppType.tracking = locale != 'pa';
    addTearDown(() => AppType.tracking = true);
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final at = now ?? nov3;

    await tester.pumpWidget(
      ProviderScope(
        retry: (_, __) => null,
        overrides: [
          reminderPlatformProvider.overrideWithValue(phone),
          localeController.overrideWith(() => _Locale(locale)),
          clockProvider.overrideWithValue(() => at),
          sgpcEventsProvider.overrideWith((ref) async => table ?? shipped),
          sikhDateProvider.overrideWith(
            (ref) async => SikhDate(
              day: 18,
              monthIndex: 7,
              year: 558,
              gregorian: sgpcDayOf(at),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.material,
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const HistoryScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  setUp(() => phone = FakeReminderPlatform());

  SgpcEvent event(String id, DateTime first, {DateTime? last, String? en}) =>
      SgpcEvent(
        id: id,
        first: first,
        last: last ?? first,
        titlePa: 'ਪੰਜਾਬੀ $id',
        titleEn: en ?? 'Event $id',
      );

  Color? colorOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style?.color;

  /// Jumps back to the top, where the intro and the switch are. The page
  /// opens far below them, on today.
  Future<void> scrollToTop(WidgetTester tester) async {
    tester.state<ScrollableState>(find.byType(Scrollable).first).position
        .jumpTo(0);
    await tester.pumpAndSettle();
  }

  Size viewport(WidgetTester tester) =>
      tester.view.physicalSize / tester.view.devicePixelRatio;

  group('the year', () {
    testWidgets('groups the days by month, in the order of the year', (
      tester,
    ) async {
      await pump(tester);

      final march = find.text('MARCH 2026', skipOffstage: false);
      final nov = find.text('NOVEMBER 2026', skipOffstage: false);
      final feb2027 = find.text('FEBRUARY 2027', skipOffstage: false);
      expect(march, findsOneWidget);
      expect(nov, findsOneWidget);
      expect(feb2027, findsOneWidget);
      final y = [
        for (final f in [march, nov, feb2027]) tester.getTopLeft(f).dy,
      ];
      expect(y, [...y]..sort(), reason: 'March first, the next February last');
      for (final month in [
        'APRIL 2026',
        'JULY 2026',
        'DECEMBER 2026',
        'JANUARY 2027',
      ]) {
        expect(find.text(month, skipOffstage: false), findsOneWidget, reason: month);
      }
    });

    testWidgets('names the year and where the days come from', (tester) async {
      await pump(tester);
      await scrollToTop(tester);

      expect(find.text(en.history_screen_intro('558')), findsOneWidget);
    });

    testWidgets('lists every event, with an event of several days once', (
      tester,
    ) async {
      final table = SgpcEventTable([
        event('mela', DateTime.utc(2026, 10, 7),
            last: DateTime.utc(2026, 10, 9), en: 'Jor Mela'),
        event('b', DateTime.utc(2026, 11, 3), en: 'Second'),
      ]);
      await pump(tester, table: table);

      expect(find.text('Jor Mela', skipOffstage: false), findsOneWidget);
      expect(find.text('7–9', skipOffstage: false), findsOneWidget,
          reason: 'the days it runs, on its first day');
    });

    testWidgets('shows English titles, falling back to Punjabi', (tester) async {
      final table = SgpcEventTable([
        SgpcEvent(
          id: 'only-pa',
          first: DateTime.utc(2026, 11, 3),
          last: DateTime.utc(2026, 11, 3),
          titlePa: 'ਸਿਰਫ਼ ਪੰਜਾਬੀ',
        ),
      ]);
      await pump(tester, table: table);

      expect(find.text('ਸਿਰਫ਼ ਪੰਜਾਬੀ'), findsOneWidget);
    });

    testWidgets('says so when no calendar covers the year', (tester) async {
      await pump(tester, table: SgpcEventTable.empty);

      expect(find.text(en.history_empty), findsOneWidget);
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
    });
  });

  group('past, today and to come', () {
    testWidgets('mutes the past, highlights today, and leaves the rest bright', (
      tester,
    ) async {
      await pump(tester);

      expect(colorOf(tester, 'Punjabi Suba Divas'), Palette.muted,
          reason: '1 November is past');
      expect(colorOf(tester, 'Gurgaddi Divas Sri Guru Harkrishan Sahib Ji'),
          Palette.foreground);
      expect(colorOf(tester, 'Bandi Chhor Divas (Diwali)'), Palette.foreground,
          reason: '8 November is to come');
    });

    testWidgets('marks today with a gold date, a label and a wash', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('TODAY'), findsOneWidget);
      final date = tester.widget<Text>(find.text('3'));
      expect(date.style!.color, Palette.gold);
      final wash = find.ancestor(
        of: find.text('TODAY'),
        matching: find.byType(Container),
      );
      final decoration = tester
          .widgetList<Container>(wash)
          .map((c) => c.decoration)
          .whereType<ShapeDecoration>()
          .first;
      expect(decoration.color!.a, closeTo(0.12, 0.01));
    });

    testWidgets('marks no day as today when none has an event', (tester) async {
      await pump(tester, now: DateTime.utc(2026, 11, 4, 6));

      expect(find.text('TODAY'), findsNothing);
      expect(colorOf(tester, 'Gurgaddi Divas Sri Guru Harkrishan Sahib Ji'),
          Palette.muted, reason: '3 November is past on 4 November');
    });

    testWidgets('moves on with the day in Amritsar, not the phone’s', (
      tester,
    ) async {
      // 19:00 UTC on 2 November is already 3 November at Amritsar.
      await pump(tester, now: DateTime.utc(2026, 11, 2, 19));

      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('Gurgaddi Divas Sri Guru Harkrishan Sahib Ji'),
          findsOneWidget);
    });

    testWidgets('counts an event of several days as today on each day', (
      tester,
    ) async {
      final table = SgpcEventTable([
        event('mela', DateTime.utc(2026, 10, 7),
            last: DateTime.utc(2026, 10, 9), en: 'Jor Mela'),
      ]);
      for (final day in [7, 8, 9]) {
        await tester.pumpWidget(const SizedBox());
        await pump(tester, now: DateTime.utc(2026, 10, day, 6), table: table);
        expect(find.text('TODAY'), findsOneWidget, reason: 'day $day');
      }
      await tester.pumpWidget(const SizedBox());
      await pump(tester, now: DateTime.utc(2026, 10, 10, 6), table: table);
      expect(find.text('TODAY'), findsNothing);
    });
  });

  group('opening', () {
    testWidgets('opens scrolled to today, a little below the top', (
      tester,
    ) async {
      await pump(tester);

      final today = tester.getTopLeft(find.text('TODAY')).dy;
      final height = viewport(tester).height;
      expect(today, greaterThan(height * 0.1), reason: 'under the nav bar');
      expect(today, lessThan(height * 0.45), reason: 'near the top');
      // Past months are above the screen, and the days to come are below it.
      expect(
        tester.getTopLeft(find.text('MARCH 2026', skipOffstage: false)).dy,
        lessThan(0),
      );
      expect(find.text('Bandi Chhor Divas (Diwali)'), findsOneWidget);
    });

    testWidgets('shows a past day above today', (tester) async {
      await pump(tester);

      expect(find.text('Punjabi Suba Divas'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Punjabi Suba Divas')).dy,
        lessThan(tester.getTopLeft(find.text('TODAY')).dy),
      );
    });

    testWidgets('opens on the next day to come when today has no event', (
      tester,
    ) async {
      await pump(tester, now: DateTime.utc(2026, 11, 4, 6));

      expect(find.text('Bandi Chhor Divas (Diwali)'), findsOneWidget);
      final y = tester.getTopLeft(find.text('Bandi Chhor Divas (Diwali)')).dy;
      expect(y, lessThan(viewport(tester).height * 0.45));
    });

    testWidgets('opens on the first day before the year’s first event', (
      tester,
    ) async {
      await pump(tester, now: DateTime.utc(2026, 3, 15, 6));

      expect(find.text('MARCH 2026'), findsOneWidget);
    });

    testWidgets('is clear until the scroll is set, so it never shows the top', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1206, 2622);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, __) => null,
          overrides: [
            reminderPlatformProvider.overrideWithValue(phone),
            localeController.overrideWith(() => _Locale('en')),
            clockProvider.overrideWithValue(() => nov3),
            sgpcEventsProvider.overrideWith((ref) async => shipped),
            sikhDateProvider.overrideWith((ref) async => null),
          ],
          child: MaterialApp(
            theme: AppTheme.material,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const HistoryScreen(),
          ),
        ),
      );
      // The data has arrived, and the first frame with the list is up.
      await tester.pump();
      await tester.pump();

      final opacity = tester.widgetList<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      // Settled: opaque, and the page is on today.
      await tester.pump(const Duration(milliseconds: 500));
      expect(opacity, isNotEmpty);
      expect(find.text('TODAY'), findsOneWidget);
    });

    testWidgets('opens at once under Reduce Motion', (tester) async {
      reduceMotion(tester);
      await pump(tester);

      expect(find.text('TODAY'), findsOneWidget);
    });
  });

  group('the notification switch', () {
    testWidgets('is on the screen, above the months, where the phone can '
        'notify', (tester) async {
      await pump(tester);
      await scrollToTop(tester);

      expect(find.text(en.history_setting), findsOneWidget);
      expect(find.byType(CupertinoSwitch), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(en.history_setting)).dy,
        lessThan(tester.getTopLeft(find.text('MARCH 2026')).dy),
      );
    });

    testWidgets('turns the notification on, as the switch in About does', (
      tester,
    ) async {
      await pump(tester);
      await scrollToTop(tester);

      await tester.tap(find.text(en.history_setting));
      await tester.pumpAndSettle();

      expect(phone.calls, contains('request'));
      expect(phone.calls.last, startsWith('history 07:00 IST x'));
      expect(tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value,
          isTrue);
    });

    testWidgets('is not there on a platform that cannot notify', (
      tester,
    ) async {
      phone.supported = false;
      await pump(tester);
      await scrollToTop(tester);

      expect(find.text(en.history_setting), findsNothing);
      expect(find.byType(CupertinoSwitch), findsNothing);
      expect(find.text('TODAY', skipOffstage: false), findsOneWidget,
          reason: 'the year is still there');
    });
  });

  group('words', () {
    testWidgets('Punjabi: Gurmukhi digits, month names and no letter spacing', (
      tester,
    ) async {
      await pump(tester, locale: 'pa');

      expect(find.text(pa.history_today), findsOneWidget);
      expect(find.text('੩'), findsOneWidget, reason: '3 November');
      expect(find.text('ਨਵੰਬਰ ੨੦੨੬'), findsOneWidget);
      for (final text in [
        pa.history_today,
        'ਨਵੰਬਰ ੨੦੨੬',
        '੩',
        'ਗੁਰਿਆਈ ਦਿਵਸ ਸ੍ਰੀ ਗੁਰੂ ਹਰਿਕ੍ਰਿਸ਼ਨ ਸਾਹਿਬ ਜੀ',
      ]) {
        expect(
          tester.widget<Text>(find.text(text)).style!.letterSpacing ?? 0,
          0,
          reason: text,
        );
      }
    });

    testWidgets('Punjabi: the intro writes the year in Gurmukhi', (tester) async {
      await pump(tester, locale: 'pa');
      await scrollToTop(tester);

      expect(find.text(pa.history_screen_intro('੫੫੮')), findsOneWidget);
    });

    testWidgets('reads each row once: the date, Today, then the titles', (
      tester,
    ) async {
      await pump(tester);

      const label = 'Tuesday, 3 November. Today. '
          'Gurgaddi Divas Sri Guru Harkrishan Sahib Ji. '
          'Joti-Jot Divas Sri Guru Har Rai Sahib Ji. '
          'Janam Dihada Mata Sahib Kaur Ji';
      final row = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == label,
      );
      expect(row, findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.byType(ExcludeSemantics)),
        findsWidgets,
        reason: 'the words inside are not read a second time',
      );
    });

    testWidgets('reads a range with both of its dates', (tester) async {
      final table = SgpcEventTable([
        event('mela', DateTime.utc(2026, 11, 3),
            last: DateTime.utc(2026, 11, 5), en: 'Jor Mela'),
      ]);
      await pump(tester, table: table);

      final row = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label ==
                'Tuesday, 3 November – 5 November. Today. Jor Mela',
      );
      expect(row, findsOneWidget);
    });

    testWidgets('is titled "Sikh history", short enough for the large title', (
      tester,
    ) async {
      for (final locale in ['en', 'pa']) {
        await tester.pumpWidget(const SizedBox());
        await pump(tester, locale: locale);
        final text = lookupAppLocalizations(Locale(locale));

        expect(find.text(text.history_screen_title, skipOffstage: false),
            findsWidgets,
            reason: locale);
        expect(find.text(text.history_title, skipOffstage: false), findsNothing,
            reason: '"Today in" is for the line on Home and the notification');
      }
      // The test font is as wide as it is tall, so the width is checked by
      // length: Home's own title, "Live Darbar", is 11 letters.
      expect(en.history_screen_title.length, lessThanOrEqualTo(14));
    });

    testWidgets('titles wrap and are never cut, at the largest text size', (
      tester,
    ) async {
      await pump(tester, textScale: 2);

      expect(tester.takeException(), isNull, reason: 'no overflow');
      final title = tester.widget<Text>(
        find.text('Gurgaddi Divas Sri Guru Harkrishan Sahib Ji'),
      );
      expect(title.maxLines, isNull);
      expect(title.overflow, isNull);
    });
  });

  group('search', () {
    final field = find.byType(CupertinoTextField);
    final clear = find.byIcon(CupertinoIcons.xmark_circle_fill);

    /// Types [text] into the field, as a listener's keyboard does.
    Future<void> type(WidgetTester tester, String text) async {
      await tester.enterText(field, text);
      await tester.pump();
    }

    double top(WidgetTester tester, String title) =>
        tester.getTopLeft(find.text(title)).dy;

    testWidgets('has a field with a hint, in English and in Punjabi', (
      tester,
    ) async {
      await pump(tester);
      expect(field, findsOneWidget);
      expect(find.text(en.history_search_hint), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await pump(tester, locale: 'pa');
      expect(find.text(pa.history_search_hint), findsOneWidget);
      expect(find.text(en.history_search_hint), findsNothing);
    });

    testWidgets('names the field for a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester);

      final node = tester.getSemantics(field);
      expect(node.label, contains(en.history_search_hint));
      expect(node.flagsCollection.isTextField, isTrue);
      handle.dispose();
    });

    testWidgets('stays in reach while the page is scrolled to today', (
      tester,
    ) async {
      await pump(tester);

      // The page opens far down the year, and the field is still on screen,
      // under the nav bar.
      expect(field.hitTestable(), findsOneWidget);
      expect(tester.getTopLeft(find.text('TODAY')).dy,
          greaterThan(tester.getBottomLeft(field).dy));
      expect(tester.getTopLeft(field).dy,
          lessThan(viewport(tester).height * 0.25));
    });

    testWidgets('keeps the days above today in view as it did before', (
      tester,
    ) async {
      await pump(tester);

      // 1 November is above today on the screen, and under the field's
      // bottom edge it would be hidden.
      final field0 = tester.getBottomLeft(field).dy;
      expect(top(tester, 'Punjabi Suba Divas'), greaterThan(field0));
    });

    testWidgets('has no clear button until there is something to clear', (
      tester,
    ) async {
      await pump(tester);
      expect(clear, findsNothing);

      await type(tester, 'ban');
      expect(clear, findsOneWidget);
    });

    testWidgets('a query shows the events that fit, and the months go', (
      tester,
    ) async {
      await pump(tester);
      await type(tester, 'bandi chhor');

      expect(find.text('Bandi Chhor Divas (Diwali)'), findsOneWidget);
      expect(find.text('TODAY', skipOffstage: false), findsNothing);
      expect(find.text('NOVEMBER 2026', skipOffstage: false), findsNothing);
      expect(
          find.text('Punjabi Suba Divas', skipOffstage: false), findsNothing);
      expect(find.text(en.history_setting, skipOffstage: false), findsNothing,
          reason: 'the switch is for the months');
      expect(find.text(en.history_screen_intro('558'), skipOffstage: false),
          findsNothing);
    });

    testWidgets('a typo finds it as well: bandhi chor', (tester) async {
      await pump(tester);
      await type(tester, 'bandhi chor');

      expect(find.text('Bandi Chhor Divas (Diwali)'), findsOneWidget);
    });

    testWidgets('each result shows its date, weekday and month', (
      tester,
    ) async {
      await pump(tester);
      await type(tester, 'bandi chhor');

      expect(find.text('8'), findsOneWidget);
      expect(find.text('Sun, Nov'), findsOneWidget);
    });

    testWidgets('a result is as a row of the months is: muted when past', (
      tester,
    ) async {
      await pump(tester);
      await type(tester, 'punjabi suba');

      expect(colorOf(tester, 'Punjabi Suba Divas'), Palette.muted,
          reason: '1 November is past');

      await type(tester, 'bandi chhor');
      expect(colorOf(tester, 'Bandi Chhor Divas (Diwali)'), Palette.foreground,
          reason: '8 November is to come');

      await type(tester, 'Janam Dihada Mata Sahib');
      expect(find.text('TODAY'), findsOneWidget, reason: '3 November');
    });

    testWidgets('lists the best match first', (tester) async {
      await pump(tester);
      await type(tester, 'baisakhi');

      expect(find.text('Khalsa Sajna Divas (Vaisakhi)'), findsOneWidget);
      expect(find.text('Sangrand Vaisakh'), findsOneWidget);
      expect(
        top(tester, 'Khalsa Sajna Divas (Vaisakhi)'),
        lessThan(top(tester, 'Sangrand Vaisakh')),
        reason: 'the festival, then the month: both fall on 14 April, and the '
            'calendar lists the month first',
      );
    });

    testWidgets('finds by the Punjabi name in an English app', (tester) async {
      await pump(tester);
      await type(tester, 'ਬੰਦੀ ਛੋੜ');

      // The row is in the app's language.
      expect(find.text('Bandi Chhor Divas (Diwali)'), findsOneWidget);
    });

    testWidgets('finds by the English name in a Punjabi app', (tester) async {
      await pump(tester, locale: 'pa');
      await type(tester, 'bandi chhor');

      expect(find.text('ਬੰਦੀ ਛੋੜ ਦਿਵਸ (ਦਿਵਾਲੀ)'), findsOneWidget);
      expect(find.text('੮'), findsOneWidget, reason: 'the day, in Gurmukhi');
    });

    testWidgets('finds by the first letters of the Punjabi words', (
      tester,
    ) async {
      await pump(tester);
      await type(tester, 'ਬਛਦ');

      expect(find.text('Bandi Chhor Divas (Diwali)'), findsOneWidget);
    });

    testWidgets('a near miss in Gurmukhi finds it', (tester) async {
      await pump(tester, locale: 'pa');
      await type(tester, 'ਬਦੀ ਛੋਡ ਦੀਵਾਲੀ');

      expect(find.text('ਬੰਦੀ ਛੋੜ ਦਿਵਸ (ਦਿਵਾਲੀ)'), findsOneWidget);
    });

    testWidgets('says so when nothing fits, with the words that were typed', (
      tester,
    ) async {
      await pump(tester);
      await type(tester, 'xyzzy');

      expect(find.text(en.history_search_empty('xyzzy')), findsOneWidget);
      expect(find.text('TODAY', skipOffstage: false), findsNothing);
    });

    testWidgets('says so in Punjabi', (tester) async {
      await pump(tester, locale: 'pa');
      await type(tester, 'ਹੈਲੀਕਾਪਟਰ');

      expect(find.text(pa.history_search_empty('ਹੈਲੀਕਾਪਟਰ')), findsOneWidget);
    });

    testWidgets('an empty field, or only spaces, is the normal screen', (
      tester,
    ) async {
      await pump(tester);

      await type(tester, '   ');
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text(en.history_search_empty('')), findsNothing);
    });

    testWidgets('clearing with the button brings the months back, on today', (
      tester,
    ) async {
      await pump(tester);
      await type(tester, 'bandi chhor');
      expect(find.text('TODAY', skipOffstage: false), findsNothing);

      await tester.tap(clear);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.widget<CupertinoTextField>(field).controller!.text, '');
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('Punjabi Suba Divas'), findsOneWidget);
      expect(find.text('Bandi Chhor Divas (Diwali)'), findsOneWidget,
          reason: 'in the months again');
      expect(find.text('NOVEMBER 2026'), findsOneWidget);
      expect(clear, findsNothing);
    });

    testWidgets('clearing by deleting the words does the same', (
      tester,
    ) async {
      await pump(tester);
      await type(tester, 'ban');
      await type(tester, '');
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('NOVEMBER 2026'), findsOneWidget);
    });

    testWidgets('the switch and the intro are back after clearing', (
      tester,
    ) async {
      await pump(tester);
      await type(tester, 'ban');
      await type(tester, '');
      await tester.pump(const Duration(milliseconds: 500));
      await scrollToTop(tester);

      expect(find.text(en.history_setting), findsOneWidget);
      expect(find.text(en.history_screen_intro('558')), findsOneWidget);
    });

    testWidgets('the clear button keeps the keyboard up', (tester) async {
      await pump(tester);
      await type(tester, 'ban');
      expect(tester.testTextInput.isVisible, isTrue);

      await tester.tap(clear);
      await tester.pump();

      expect(tester.testTextInput.isVisible, isTrue);
    });

    testWidgets('a swipe on the results puts the keyboard away', (
      tester,
    ) async {
      await pump(tester);
      await type(tester, 'b');
      expect(tester.testTextInput.isVisible, isTrue);

      expect(
        tester
            .widget<CustomScrollView>(find.byType(CustomScrollView))
            .keyboardDismissBehavior,
        ScrollViewKeyboardDismissBehavior.onDrag,
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pump();

      expect(tester.testTextInput.isVisible, isFalse);
    });

    testWidgets('a new query starts at the top of the results', (
      tester,
    ) async {
      await pump(tester);
      await type(tester, 's');
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      scrollable.position.jumpTo(600);
      await tester.pump();
      expect(scrollable.position.pixels, greaterThan(0));

      await type(tester, 'sa');
      await tester.pump();

      expect(scrollable.position.pixels, 0);
    });

    testWidgets('searches only the year the page lists', (tester) async {
      final table = SgpcEventTable([
        event('in', DateTime.utc(2026, 11, 3), en: 'Inside the year'),
        event('out', DateTime.utc(2027, 3, 20), en: 'After the year'),
      ]);
      await pump(tester, table: table);
      await type(tester, 'year');

      expect(find.text('Inside the year'), findsOneWidget);
      expect(find.text('After the year'), findsNothing);
    });

    testWidgets('is not there when no calendar covers the year', (
      tester,
    ) async {
      await pump(tester, table: SgpcEventTable.empty);

      expect(field, findsNothing);
      expect(find.text(en.history_empty), findsOneWidget);
    });

    testWidgets('an event of several days shows its days', (tester) async {
      final table = SgpcEventTable([
        event('mela', DateTime.utc(2026, 10, 7),
            last: DateTime.utc(2026, 10, 9), en: 'Jor Mela'),
      ]);
      await pump(tester, table: table);
      await type(tester, 'jor mela');

      expect(find.text('7–9'), findsOneWidget);
      expect(find.text('Wed, Oct'), findsOneWidget);
    });

    testWidgets('a screen reader hears how many events fit, then the rows', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester);
      await type(tester, 'bandi chhor');

      expect(find.bySemanticsLabel(en.history_search_count(1)), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Bandi Chhor')), findsWidgets);

      await type(tester, 'tegh bahadur');
      expect(find.bySemanticsLabel(en.history_search_count(4)), findsOneWidget);
      handle.dispose();
    });

    testWidgets('Punjabi: no letter spacing in the field or the rows', (
      tester,
    ) async {
      await pump(tester, locale: 'pa');
      expect(
          tester
                  .widget<Text>(find.text(pa.history_search_hint))
                  .style!
                  .letterSpacing ??
              0,
          0,
          reason: 'the hint');

      await type(tester, 'ਬੰਦੀ ਛੋੜ');
      // The style the words are drawn in, after the Cupertino theme has had its
      // say: it gives a field a tracking of -0.41.
      expect(
          tester
                  .widget<EditableText>(find.byType(EditableText))
                  .style
                  .letterSpacing ??
              0,
          0,
          reason: 'the words typed');
      expect(
        tester
                .widget<Text>(find.text('ਬੰਦੀ ਛੋੜ ਦਿਵਸ (ਦਿਵਾਲੀ)'))
                .style!
                .letterSpacing ??
            0,
        0,
        reason: 'the row',
      );
    });

    testWidgets('Gurmukhi typed into an English app has room for its marks', (
      tester,
    ) async {
      await pump(tester);

      final style = tester.widget<CupertinoTextField>(field).style!;
      expect(style.height, greaterThanOrEqualTo(1.6));
      expect(style.letterSpacing ?? 0, 0);
    });

    testWidgets('grows with the text size and cuts nothing', (tester) async {
      await pump(tester, textScale: 2);
      final large = tester.getSize(field).height;
      await type(tester, 'shaheedi dihada baba deep singh ji');

      expect(tester.takeException(), isNull, reason: 'no overflow');
      expect(find.text('Shaheedi Dihada Baba Deep Singh Ji'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await pump(tester);
      expect(large, greaterThan(tester.getSize(field).height * 1.4));
    });

    testWidgets('is at least 44 points tall', (tester) async {
      await pump(tester);

      expect(tester.getSize(field).height, greaterThanOrEqualTo(44));
    });

    testWidgets('the clear button is a target of 44 points', (tester) async {
      await pump(tester);
      await type(tester, 'ban');

      final target = find.ancestor(
        of: clear,
        matching: find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == 44 && w.height == 44,
        ),
      );
      expect(target, findsOneWidget);
    });

    testWidgets('does not ask the phone to correct the words', (tester) async {
      await pump(tester);

      final input = tester.widget<CupertinoTextField>(field);
      expect(input.autocorrect, isFalse);
      expect(input.textInputAction, TextInputAction.search);
    });

    testWidgets('closes the keyboard on search', (tester) async {
      await pump(tester);
      await type(tester, 'ban');
      expect(tester.testTextInput.isVisible, isTrue);

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

      expect(tester.testTextInput.isVisible, isFalse);
      expect(find.text('Bandi Chhor Divas (Diwali)'), findsOneWidget,
          reason: 'the results stay');
    });
  });
}
