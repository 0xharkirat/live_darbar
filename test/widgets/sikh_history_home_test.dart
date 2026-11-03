import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/models/sgpc_day.dart';
import 'package:live_darbar/src/models/sgpc_event.dart';
import 'package:live_darbar/src/models/sikh_date.dart';

import '../support/app_harness.dart';

/// "Today in Sikh history" on the home screen: today's events under the two
/// dates, in the app's language, and nothing at all on a day with none.
void main() {
  final shipped = SgpcEventTable.fromJsonString(
    File('assets/data/sgpc_events_558.json').readAsStringSync(),
  );

  // 3 November 2026, 06:00 UTC: the morning at Amritsar. Three events fall on
  // it, the most of any day in the calendar.
  final nov3 = DateTime.utc(2026, 11, 3, 6);
  final nov2 = DateTime.utc(2026, 11, 2, 6);

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

  testWidgets('English: lists the titles in English, in calendar order', (
    tester,
  ) async {
    await pumpHome(tester);

    for (final title in english) {
      expect(find.text(title), findsOneWidget);
    }
    final tops = [for (final t in english) tester.getTopLeft(find.text(t)).dy];
    expect(tops, [...tops]..sort());
    for (final title in punjabi) {
      expect(find.text(title), findsNothing);
    }
  });

  testWidgets('Punjabi: lists the titles in Punjabi with no letter spacing', (
    tester,
  ) async {
    await pumpHome(tester, locale: 'pa');

    for (final title in punjabi) {
      expect(find.text(title), findsOneWidget);
      final style = tester.widget<Text>(find.text(title)).style!;
      expect(
        style.letterSpacing ?? 0,
        0,
        reason: 'Gurmukhi never gets letter spacing',
      );
    }
    for (final title in english) {
      expect(find.text(title), findsNothing);
    }
  });

  testWidgets('sits under the Nanakshahi and Gregorian dates, above the title', (
    tester,
  ) async {
    await pumpHome(tester);

    final sikh = tester.getBottomLeft(find.text('18 KATAK 558')).dy;
    final gregorian = tester.getBottomLeft(find.text('TUESDAY, 3 NOVEMBER')).dy;
    final first = tester.getTopLeft(find.text(english.first)).dy;
    final last = tester.getBottomLeft(find.text(english.last)).dy;
    final appTitle = tester.getTopLeft(find.text('Live Darbar')).dy;

    expect(sikh, lessThan(gregorian));
    expect(gregorian, lessThan(first));
    expect(last, lessThan(appTitle));
  });

  testWidgets('English falls back to the Punjabi title when there is no '
      'English one', (tester) async {
    final table = SgpcEventTable([
      SgpcEvent(
        id: 'only-pa',
        first: DateTime.utc(2026, 11, 3),
        last: DateTime.utc(2026, 11, 3),
        titlePa: 'ਸਿਰਫ਼ ਪੰਜਾਬੀ ਸਿਰਲੇਖ',
      ),
    ]);

    await pumpHome(tester, table: table);

    expect(find.text('ਸਿਰਫ਼ ਪੰਜਾਬੀ ਸਿਰਲੇਖ'), findsOneWidget);
  });

  testWidgets('shows nothing on a day with no event, and leaves the page as '
      'it was', (tester) async {
    await pumpHome(tester, now: nov2);
    final titleWithNoEvents = tester.getTopLeft(find.text('Live Darbar')).dy;

    for (final title in [...english, ...punjabi]) {
      expect(find.text(title), findsNothing);
    }
    expect(find.bySemanticsLabel(RegExp('Today in Sikh history')), findsNothing);

    // The same page, on a day that has events, is taller by the events alone.
    await pumpHome(tester);
    final titleWithEvents = tester.getTopLeft(find.text('Live Darbar')).dy;
    expect(titleWithEvents, greaterThan(titleWithNoEvents));

    // And with the calendar gone, the page is the same as on a quiet day.
    await pumpHome(tester, table: SgpcEventTable.empty);
    expect(tester.getTopLeft(find.text('Live Darbar')).dy, titleWithNoEvents);
  });

  testWidgets('shows an event that runs for days on each of its days', (
    tester,
  ) async {
    final table = SgpcEventTable([
      SgpcEvent(
        id: 'mela',
        first: DateTime.utc(2026, 10, 7),
        last: DateTime.utc(2026, 10, 8),
        titlePa: 'ਜੋੜ-ਮੇਲਾ',
        titleEn: 'Jor Mela',
      ),
    ]);

    for (final (day, shown) in [(6, false), (7, true), (8, true), (9, false)]) {
      await pumpHome(tester, now: DateTime.utc(2026, 10, day, 6), table: table);
      expect(find.text('Jor Mela'), shown ? findsOneWidget : findsNothing);
    }
  });

  testWidgets('names the section for a screen reader, once', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpHome(tester);

    expect(
      find.bySemanticsLabel(
        'Today in Sikh history: ${english.join('. ')}',
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('is the day in Amritsar, not the phone\'s', (tester) async {
    // 19:00 UTC on 2 November is already 3 November at Amritsar.
    await pumpHome(tester, now: DateTime.utc(2026, 11, 2, 19));

    expect(find.text(english.first), findsOneWidget);
  });
}
