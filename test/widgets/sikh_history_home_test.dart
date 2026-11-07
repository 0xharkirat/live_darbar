import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/views/screens/history_screen.dart';
import 'package:live_darbar/src/models/sgpc_day.dart';
import 'package:live_darbar/src/models/sgpc_event.dart';
import 'package:live_darbar/src/models/sikh_date.dart';
import 'package:live_darbar/src/views/widgets/sangrand_row.dart';

import '../support/app_harness.dart';

/// "Today in Sikh history" on the home screen: 1 quiet line under the two
/// dates, always 1 row of the same height. On a day with events it is led by
/// "Today", then the first event in the app's language, with "+N" for the
/// rest. On a quiet day it is led by "Next" and the date of the next event.
/// With no event left in any file there is no line. The whole line opens the
/// year's screen.
void main() {
  final shipped = SgpcEventTable.fromJsonString(
    File('assets/data/sgpc_events_558.json').readAsStringSync(),
  );

  // 3 November 2026, 06:00 UTC: the morning at Amritsar. Three events fall on
  // it, the most of any day in the calendar.
  final nov3 = DateTime.utc(2026, 11, 3, 6);
  // A quiet day: the next event is on 8 November.
  final nov4 = DateTime.utc(2026, 11, 4, 6);

  Future<void> pumpHome(
    WidgetTester tester, {
    String locale = 'en',
    DateTime? now,
    SgpcEventTable? table,
  }) async {
    final at = now ?? nov3;
    // A new app, so a test can open home on more than 1 day.
    await tester.pumpWidget(const SizedBox.shrink());
    return pumpApp(
      tester,
      locale: locale,
      clock: at,
      events: table ?? shipped,
      sikh: SikhDate(
        day: 18,
        monthIndex: 7,
        year: 558,
        gregorian: sgpcDayOf(at),
      ),
    );
  }

  const english = [
    'Gurgaddi Divas Sri Guru Harkrishan Sahib Ji',
    'Joti-Jot Divas Sri Guru Har Rai Sahib Ji',
    'Janam Dihada Mata Sahib Kaur Ji',
  ];
  const punjabi = [
    'ਗੁਰਿਆਈ ਦਿਵਸ ਸ੍ਰੀ ਗੁਰੂ ਹਰਿਕ੍ਰਿ\u0A36ਨ ਸਾਹਿਬ ਜੀ',
    'ਜੋਤੀ-ਜੋਤਿ ਦਿਵਸ ਸ੍ਰੀ ਗੁਰੂ ਹਰਿਰਾਇ ਸਾਹਿਬ ਜੀ',
    'ਜਨਮ ਦਿਹਾੜਾ ਮਾਤਾ ਸਾਹਿਬ ਕੌਰ ਜੀ',
  ];

  /// The line's text. It is the only rich text on Home: the label, then the
  /// title. ("TODAY" is also the heading of the tiles, so a plain text search
  /// would find 2.)
  /// The history line's text. Home has another line of the same shape, the
  /// Sangrand row, which is not this one.
  Finder line(String text) => find.byElementPredicate(
        (e) =>
            e.widget is Text &&
            ((e.widget as Text).textSpan?.toPlainText().contains(text) ??
                false) &&
            e.findAncestorWidgetOfExactType<SangrandRow>() == null,
      );

  /// No line at all.
  Finder noLine() => line('');

  SgpcEvent event(String id, DateTime first,
          {DateTime? last, String? en, String? pa}) =>
      SgpcEvent(
        id: id,
        first: first,
        last: last ?? first,
        titlePa: pa ?? 'ਪੰਜਾਬੀ $id',
        titleEn: en ?? 'Event $id',
      );

  double liveDarbarTop(WidgetTester tester) =>
      tester.getTopLeft(find.text('Live Darbar')).dy;

  group('on a day with events', () {
    testWidgets('English: "Today", the first title only, and +2 for the rest', (
      tester,
    ) async {
      await pumpHome(tester);

      expect(line('TODAY'), findsOneWidget);
      expect(line(english.first), findsOneWidget);
      for (final title in [...english.skip(1), ...punjabi]) {
        expect(line(title), findsNothing);
      }
      expect(find.text('+2'), findsOneWidget);
      expect(line('NEXT'), findsNothing);
    });

    testWidgets('Punjabi: "ਅੱਜ", the first title, +2 in Gurmukhi digits, no '
        'letter spacing', (tester) async {
      await pumpHome(tester, locale: 'pa');

      expect(line('ਅੱਜ'), findsOneWidget);
      expect(line(punjabi.first), findsOneWidget);
      for (final title in [...punjabi.skip(1), ...english]) {
        expect(line(title), findsNothing);
      }
      expect(find.text('+੨'), findsOneWidget);
      final span = tester
          .widget<Text>(find.byWidgetPredicate(
            (w) => w is Text && w.textSpan != null && w.textSpan!.toPlainText().contains('ਅੱਜ'),
          ))
          .textSpan! as TextSpan;
      for (final child in span.children!) {
        expect(
          (child as TextSpan).style?.letterSpacing ?? 0,
          0,
          reason: 'Gurmukhi never gets letter spacing',
        );
      }
    });

    testWidgets('a day with 1 event has no +N', (tester) async {
      final table = SgpcEventTable([
        event('one', DateTime.utc(2026, 11, 3), en: 'The only event'),
      ]);

      await pumpHome(tester, table: table);

      expect(line('The only event'), findsOneWidget);
      expect(find.textContaining('+'), findsNothing);
    });

    testWidgets('shows an event that runs for days on each of its days', (
      tester,
    ) async {
      final table = SgpcEventTable([
        event('mela', DateTime.utc(2026, 10, 7),
            last: DateTime.utc(2026, 10, 8), en: 'Jor Mela'),
      ]);

      for (final (day, today) in [(7, true), (8, true)]) {
        await pumpHome(tester, now: DateTime.utc(2026, 10, day, 6), table: table);
        expect(line('TODAY'), today ? findsOneWidget : findsNothing,
            reason: 'day $day');
        expect(line('Jor Mela'), findsOneWidget);
      }
      await pumpHome(tester, now: DateTime.utc(2026, 10, 6, 6), table: table);
      expect(line('NEXT · 7 OCT'), findsOneWidget,
          reason: 'the day before is quiet, and the mela is next');
      await pumpHome(tester, now: DateTime.utc(2026, 10, 9, 6), table: table);
      expect(noLine(), findsNothing, reason: 'it is over, and nothing is left');
    });
  });

  group('on a quiet day', () {
    testWidgets('English: "Next", its date and the next event', (tester) async {
      await pumpHome(tester, now: nov4);

      expect(line('NEXT · 8 NOV'), findsOneWidget);
      expect(line('Bandi Chhor Divas (Diwali)'), findsOneWidget);
      expect(line('TODAY'), findsNothing);
      expect(find.textContaining('+'), findsNothing,
          reason: '8 November has 1 event');
    });

    testWidgets('Punjabi: "ਅਗਲਾ", the date in Gurmukhi digits, the Punjabi title',
        (tester) async {
      await pumpHome(tester, locale: 'pa', now: nov4);

      expect(line('ਅਗਲਾ · ੮ ਨਵੰ'), findsOneWidget);
      expect(line('ਬੰਦੀ ਛੋੜ ਦਿਵਸ (ਦਿਵਾਲੀ)'), findsOneWidget);
      expect(line('ਅੱਜ'), findsNothing);
    });

    testWidgets('writes the date as the widget does', (tester) async {
      // The same helper, so the Home line and the widget never disagree.
      await pumpHome(tester, now: DateTime.utc(2026, 11, 9, 6));

      expect(line('NEXT · 11 NOV'), findsOneWidget);
    });

    testWidgets('shows +N when the next day has more than 1 event', (
      tester,
    ) async {
      final table = SgpcEventTable([
        event('a', DateTime.utc(2026, 11, 8), en: 'First'),
        event('b', DateTime.utc(2026, 11, 8), en: 'Second'),
        event('c', DateTime.utc(2026, 11, 8), en: 'Third'),
        event('far', DateTime.utc(2026, 11, 20), en: 'Far'),
      ]);

      await pumpHome(tester, now: nov4, table: table);

      expect(line('First'), findsOneWidget);
      expect(line('Second'), findsNothing);
      expect(find.text('+2'), findsOneWidget);
    });

    testWidgets('English falls back to the Punjabi title', (tester) async {
      final table = SgpcEventTable([
        SgpcEvent(
          id: 'only-pa',
          first: DateTime.utc(2026, 11, 8),
          last: DateTime.utc(2026, 11, 8),
          titlePa: 'ਸਿਰਫ਼ ਪੰਜਾਬੀ ਸਿਰਲੇਖ',
        ),
      ]);

      await pumpHome(tester, now: nov4, table: table);

      expect(line('ਸਿਰਫ਼ ਪੰਜਾਬੀ ਸਿਰਲੇਖ'), findsOneWidget);
    });
  });

  group('the end of the year', () {
    // The shipped calendar ends on 21 February 2027, with 2 events.
    final lastDay = DateTime.utc(2027, 2, 21, 6);
    final after = DateTime.utc(2027, 2, 22, 6);

    testWidgets('the last day with events is an event day', (tester) async {
      await pumpHome(tester, now: lastDay);

      expect(line('TODAY'), findsOneWidget);
      expect(line('Saka Nankana Sahib'), findsOneWidget);
      expect(find.text('+1'), findsOneWidget,
          reason: 'and Jaito da Morcha, the last event of the year');
    });

    testWidgets('a quiet day before it points to the next event', (
      tester,
    ) async {
      await pumpHome(tester, now: DateTime.utc(2027, 2, 14, 6));

      expect(line('NEXT · 19 FEB'), findsOneWidget);
      expect(line('Parkash Gurpurab Sri Guru Har Rai Sahib Ji'), findsOneWidget);
    });

    testWidgets('with no next year’s file, the line is gone', (tester) async {
      await pumpHome(tester, now: after);

      expect(noLine(), findsNothing);
    });

    testWidgets('and the page is the same as with no calendar at all', (
      tester,
    ) async {
      await pumpHome(tester, now: after);
      final without = liveDarbarTop(tester);

      await pumpHome(tester, now: after, table: SgpcEventTable.empty);

      expect(liveDarbarTop(tester), without);
    });

    testWidgets('with next year’s file, the first event of it is next', (
      tester,
    ) async {
      final next = SgpcEventTable([
        ...shipped.events,
        event('ns559-001', DateTime.utc(2027, 3, 20),
            en: 'Hola Mohalla begins'),
      ]);

      await pumpHome(tester, now: after, table: next);

      expect(line('NEXT · 20 MAR'), findsOneWidget);
      expect(line('Hola Mohalla begins'), findsOneWidget);
    });

    testWidgets('with next year’s file, the new year’s events are listed too', (
      tester,
    ) async {
      final next = SgpcEventTable([
        ...shipped.events,
        event('ns559-001', DateTime.utc(2027, 3, 20), en: 'Early'),
      ]);

      await pumpHome(tester, now: DateTime.utc(2027, 3, 20, 6), table: next);

      expect(line('TODAY'), findsOneWidget);
      expect(line('Early'), findsOneWidget);
    });
  });

  group('the row', () {
    testWidgets('is the same height, so live kirtan stays where it is', (
      tester,
    ) async {
      await pumpHome(tester);
      final eventDay = liveDarbarTop(tester);

      await pumpHome(tester, now: nov4);
      final quietDay = liveDarbarTop(tester);

      expect(quietDay, eventDay);
    });

    testWidgets('is the same height on every day of the year that shows it', (
      tester,
    ) async {
      final tops = <double>{};
      for (final day in [
        DateTime.utc(2026, 3, 14, 6),
        DateTime.utc(2026, 11, 3, 6),
        DateTime.utc(2026, 11, 4, 6),
        DateTime.utc(2026, 12, 1, 6),
        DateTime.utc(2027, 2, 21, 6),
      ]) {
        await pumpHome(tester, now: day);
        tops.add(liveDarbarTop(tester));
      }
      expect(tops, hasLength(1), reason: '$tops');
    });

    testWidgets('is the same height with a very long title', (tester) async {
      final table = SgpcEventTable([
        event(
          'long',
          DateTime.utc(2026, 11, 3),
          en: 'Shaheedi Dihada Sant Jarnail Singh Ji Khalsa Bhindranwale & '
              'Bhai Amrik Singh Ji',
        ),
        event('short', DateTime.utc(2026, 11, 8), en: 'Short'),
      ]);

      await pumpHome(tester, table: table);
      final long = liveDarbarTop(tester);
      await pumpHome(tester, now: nov4, table: table);

      expect(liveDarbarTop(tester), long);
    });

    testWidgets('grows with the listener’s text size, not with the day', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpHome(tester);
      final eventDay = liveDarbarTop(tester);
      await pumpHome(tester, now: nov4);

      expect(liveDarbarTop(tester), eventDay);
    });

    testWidgets('sits under the Nanakshahi and Gregorian dates, above the '
        'title', (tester) async {
      await pumpHome(tester);

      final sikh = tester.getBottomLeft(find.text('18 KATAK 558')).dy;
      final gregorian =
          tester.getBottomLeft(find.text('TUESDAY, 3 NOVEMBER')).dy;
      final row = tester.getTopLeft(line('TODAY')).dy;

      expect(sikh, lessThan(gregorian));
      expect(gregorian, lessThan(row));
      expect(row, lessThan(liveDarbarTop(tester)));
    });

    testWidgets('keeps live kirtan high: at most 2 lines, and 1 row', (
      tester,
    ) async {
      await pumpHome(tester, now: DateTime.utc(2027, 2, 22, 6));
      final without = liveDarbarTop(tester);

      await pumpHome(tester);

      expect(liveDarbarTop(tester) - without, lessThan(95));
    });

    testWidgets('is a target of at least 44 points, the whole width', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      for (final now in [nov3, nov4]) {
        await pumpHome(tester, now: now);

        final row = find.bySemanticsLabel(RegExp('Sikh history'));
        expect(tester.getSize(row).height, greaterThanOrEqualTo(44));
        expect(tester.getSize(row).width, greaterThan(300),
            reason: 'the whole width of the line, not only the words');
      }
      handle.dispose();
    });
  });

  group('the tap', () {
    testWidgets('opens the year on an event day, on the title or on +2', (
      tester,
    ) async {
      for (final target in [line(english.first), find.text('+2')]) {
        await pumpHome(tester);
        expect(find.byType(HistoryScreen), findsNothing);

        await tester.tap(target);
        await tester.pumpAndSettle();

        expect(find.byType(HistoryScreen), findsOneWidget);
      }
    });

    testWidgets('opens the year on a quiet day', (tester) async {
      await pumpHome(tester, now: nov4);
      expect(find.byType(HistoryScreen), findsNothing);

      await tester.tap(line('Bandi Chhor Divas (Diwali)'));
      await tester.pumpAndSettle();

      expect(find.byType(HistoryScreen), findsOneWidget);
    });

    testWidgets('opens the year with 8 November in view on a quiet day', (
      tester,
    ) async {
      await pumpHome(tester, now: nov4);

      await tester.tap(line('NEXT · 8 NOV'));
      await tester.pumpAndSettle();

      expect(find.text('Bandi Chhor Divas (Diwali)'), findsOneWidget,
          reason: 'the screen opens on the next day to come');
    });
  });

  group('for a screen reader', () {
    testWidgets('an event day reads the first title and how many more', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpHome(tester);
      final l10n = lookupAppLocalizations(const Locale('en'));

      expect(
        find.bySemanticsLabel(
          'Today in Sikh history: ${english.first}, ${l10n.history_and_more(2)}',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('a quiet day reads "Next", the date and the title', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpHome(tester, now: nov4);

      expect(
        find.bySemanticsLabel(
          'Next in Sikh history, 8 November: Bandi Chhor Divas (Diwali)',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('the words inside are not read a second time', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHome(tester, now: nov4);

      expect(find.bySemanticsLabel(RegExp('NEXT')), findsNothing);
      handle.dispose();
    });
  });

  testWidgets('is the day in Amritsar, not the phone\'s', (tester) async {
    // 19:00 UTC on 2 November is already 3 November at Amritsar.
    await pumpHome(tester, now: DateTime.utc(2026, 11, 2, 19));

    expect(line(english.first), findsOneWidget);
    expect(line('TODAY'), findsOneWidget);
  });

  testWidgets('moves from today to next when the day has gone', (tester) async {
    await pumpHome(tester);
    expect(line('TODAY'), findsOneWidget);

    // 19:00 UTC on 3 November is already 4 November at Amritsar.
    await pumpHome(tester, now: DateTime.utc(2026, 11, 3, 19));

    expect(line('TODAY'), findsNothing);
    expect(line('NEXT · 8 NOV'), findsOneWidget);
  });
}
