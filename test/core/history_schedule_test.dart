import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/core/history_schedule.dart';
import 'package:live_darbar/src/core/reminder_schedule.dart';
import 'package:live_darbar/src/models/reminder_time.dart';
import 'package:live_darbar/src/models/sgpc_event.dart';
import 'package:timezone/data/latest_10y.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// The 30 days of "Today in Sikh history": which days get a notification, what
/// it says, and the moment each one fires.
void main() {
  setUpAll(tz_data.initializeTimeZones);

  DateTime day(int y, int m, int d) => DateTime.utc(y, m, d);

  SgpcEvent event(String id, DateTime first, {DateTime? last, String? en}) =>
      SgpcEvent(
        id: id,
        first: first,
        last: last ?? first,
        titlePa: 'ਪੰਜਾਬੀ $id',
        titleEn: en ?? 'English $id',
      );

  group('planHistory', () {
    test('is 1 notice for each day with an event, and none for the rest', () {
      final table = SgpcEventTable([
        event('a', day(2026, 11, 3)),
        event('b', day(2026, 11, 8)),
      ]);

      final notices = planHistory(
        table: table,
        today: day(2026, 11, 2),
        punjabi: false,
      );

      expect(notices.map((n) => n.day), [day(2026, 11, 3), day(2026, 11, 8)]);
    });

    test('puts the events of a day in 1 notice, 1 title to a line', () {
      final table = SgpcEventTable([
        event('a', day(2026, 11, 3)),
        event('b', day(2026, 11, 3)),
        event('c', day(2026, 11, 3)),
      ]);

      final notices = planHistory(
        table: table,
        today: day(2026, 11, 3),
        punjabi: false,
      );

      expect(notices, hasLength(1));
      expect(notices.single.body, 'English a\nEnglish b\nEnglish c');
    });

    test('writes Punjabi titles in Punjabi, and falls back in English', () {
      final table = SgpcEventTable([
        SgpcEvent(
          id: 'x',
          first: day(2026, 11, 3),
          last: day(2026, 11, 3),
          titlePa: 'ਸਿਰਫ਼ ਪੰਜਾਬੀ',
        ),
        event('b', day(2026, 11, 3)),
      ]);

      String body({required bool punjabi}) => planHistory(
            table: table,
            today: day(2026, 11, 3),
            punjabi: punjabi,
          ).single.body;

      expect(body(punjabi: true), 'ਸਿਰਫ਼ ਪੰਜਾਬੀ\nਪੰਜਾਬੀ b');
      expect(body(punjabi: false), 'ਸਿਰਫ਼ ਪੰਜਾਬੀ\nEnglish b');
    });

    test('counts today as the first of 30 days', () {
      final table = SgpcEventTable([
        event('today', day(2026, 11, 2)),
        event('last', day(2026, 12, 1)),
        event('too late', day(2026, 12, 2)),
        event('yesterday', day(2026, 11, 1)),
      ]);

      final notices = planHistory(
        table: table,
        today: day(2026, 11, 2),
        punjabi: false,
      );

      expect(notices.map((n) => n.body), ['English today', 'English last']);
    });

    test('sets an event that runs for days on each of its days', () {
      final table = SgpcEventTable([
        event('mela', day(2026, 10, 7), last: day(2026, 10, 9)),
      ]);

      final notices = planHistory(
        table: table,
        today: day(2026, 10, 8),
        punjabi: false,
      );

      expect(notices.map((n) => n.day), [day(2026, 10, 8), day(2026, 10, 9)]);
    });

    test('holds 30 at most, even when every day has an event', () {
      final table = SgpcEventTable([
        for (var i = 0; i < 90; i++) event('e$i', day(2026, 11, 1 + i)),
      ]);

      final notices = planHistory(
        table: table,
        today: day(2026, 11, 1),
        punjabi: false,
      );

      expect(notices, hasLength(30));
      expect(kHistoryDays, lessThan(64), reason: 'iOS keeps 64 pending');
      expect(notices.first.day, day(2026, 11, 1));
      expect(notices.last.day, day(2026, 11, 30));
    });

    test('is empty for an empty table, and past the end of the calendar', () {
      expect(
        planHistory(
          table: SgpcEventTable.empty,
          today: day(2026, 11, 2),
          punjabi: false,
        ),
        isEmpty,
      );
      final shipped = SgpcEventTable.fromJsonString(
        File('assets/data/sgpc_events_558.json').readAsStringSync(),
      );
      expect(
        planHistory(table: shipped, today: day(2027, 3, 1), punjabi: false),
        isEmpty,
        reason: 'the last reviewed event is on 21 February',
      );
    });

    test('plans the real 30 days from 2 November 2026', () {
      final shipped = SgpcEventTable.fromJsonString(
        File('assets/data/sgpc_events_558.json').readAsStringSync(),
      );

      final notices = planHistory(
        table: shipped,
        today: day(2026, 11, 2),
        punjabi: false,
      );

      expect(
        notices.map((n) => '${n.day.month}-${n.day.day}'),
        [
          '11-3',
          '11-8',
          '11-11',
          '11-14',
          '11-15',
          '11-16',
          '11-20',
          '11-24',
          '11-28',
          '11-30'
        ],
      );
      expect(notices.first.body.split('\n'), [
        'Gurgaddi Divas Sri Guru Harkrishan Sahib Ji',
        'Joti-Jot Divas Sri Guru Har Rai Sahib Ji',
        'Janam Dihada Mata Sahib Kaur Ji',
      ]);
    });

    test('crosses the year edge into the next year\'s file', () {
      final y558 = SgpcEventTable([event('a', day(2027, 3, 13))]);
      final y559 = SgpcEventTable([event('b', day(2027, 3, 15))]);

      final notices = planHistory(
        table: SgpcEventTable.merge([y558, y559]),
        today: day(2027, 3, 12),
        punjabi: false,
      );

      expect(notices.map((n) => n.body), ['English a', 'English b']);
    });
  });

  group('timeOnDay', () {
    tz.TZDateTime at(String zone, int y, int m, int d, int h, [int min = 0]) =>
        tz.TZDateTime(tz.getLocation(zone), y, m, d, h, min);

    test('is the time on that date, on the phone\'s own clock', () {
      final now = at('America/Vancouver', 2026, 11, 2, 20);

      expect(
        timeOnDay(now, day(2026, 11, 3), ReminderTime.standard),
        at('America/Vancouver', 2026, 11, 3, 7),
      );
    });

    test('is null when the time has passed, or is this very minute', () {
      final now = at('Asia/Kolkata', 2026, 11, 3, 7);

      expect(timeOnDay(now, day(2026, 11, 3), ReminderTime.standard), isNull);
      expect(timeOnDay(now, day(2026, 11, 2), ReminderTime.standard), isNull);
      expect(
        timeOnDay(
          at('Asia/Kolkata', 2026, 11, 3, 6, 59),
          day(2026, 11, 3),
          ReminderTime.standard,
        ),
        at('Asia/Kolkata', 2026, 11, 3, 7),
      );
    });

    test('still fires on the day the clocks go forward at 2:30', () {
      // 2:30 does not exist in New York on 14 March 2027. The clock reads
      // 3:30, which is a moment a single notification can have.
      final now = at('America/New_York', 2027, 3, 13, 20);

      final moment =
          timeOnDay(now, day(2027, 3, 14), const ReminderTime(2, 30));

      expect(moment, isNotNull);
      expect(moment!.hour, 3);
      expect(moment.minute, 30);
    });

    test('keeps the hour on the day the clocks go back', () {
      final now = at('America/New_York', 2026, 10, 31, 20);

      expect(
        timeOnDay(now, day(2026, 11, 1), ReminderTime.standard),
        at('America/New_York', 2026, 11, 1, 7),
      );
    });
  });
}
