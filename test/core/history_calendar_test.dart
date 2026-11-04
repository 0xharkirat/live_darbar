import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/core/history_calendar.dart';
import 'package:live_darbar/src/models/sgpc_event.dart';

/// The year of Sikh history behind the screen that Home opens.
void main() {
  final shipped = SgpcEventTable.fromJsonString(
    File('assets/data/sgpc_events_558.json').readAsStringSync(),
  );

  SgpcEvent event(String id, DateTime first, {DateTime? last}) => SgpcEvent(
        id: id,
        first: first,
        last: last ?? first,
        titlePa: 'ਸਿਰਲੇਖ $id',
        titleEn: 'Title $id',
      );

  DateTime d(int y, int m, int day) => DateTime.utc(y, m, day);

  group('the Nanakshahi year', () {
    test('starts on 14 March', () {
      expect(nanakshahiYearOf(d(2026, 3, 13)), 557);
      expect(nanakshahiYearOf(d(2026, 3, 14)), 558);
      expect(nanakshahiYearOf(d(2026, 11, 3)), 558);
      expect(nanakshahiYearOf(d(2027, 1, 1)), 558);
      expect(nanakshahiYearOf(d(2027, 3, 13)), 558);
      expect(nanakshahiYearOf(d(2027, 3, 14)), 559);
    });
  });

  group('grouping', () {
    test('puts each event on its first day, in months from March', () {
      final table = SgpcEventTable([
        event('c', d(2027, 1, 5)),
        event('a', d(2026, 3, 20)),
        event('b', d(2026, 11, 3)),
        event('b2', d(2026, 11, 3)),
      ]);

      final year = buildHistoryYear(table, d(2026, 11, 3))!;

      expect(year.number, 558);
      expect(
        [for (final m in year.months) (m.year, m.month)],
        [(2026, 3), (2026, 11), (2027, 1)],
      );
      final nov = year.months[1];
      expect(nov.days, hasLength(1));
      expect(nov.days.single.events.map((e) => e.id), ['b', 'b2'],
          reason: 'one row, in the order of the calendar');
    });

    test('leaves out events of other years', () {
      final table = SgpcEventTable([
        event('old', d(2026, 3, 13)),
        event('in', d(2026, 3, 14)),
        event('last', d(2027, 3, 13)),
        event('next', d(2027, 3, 14)),
      ]);

      final year = buildHistoryYear(table, d(2026, 6, 1))!;

      expect(year.days.expand((day) => day.events).map((e) => e.id),
          ['in', 'last']);
    });

    test('is the year of today, so the next year is its own', () {
      final table = SgpcEventTable([
        event('a', d(2026, 5, 1)),
        event('b', d(2027, 5, 1)),
      ]);

      expect(buildHistoryYear(table, d(2027, 4, 1))!.number, 559);
      expect(
        buildHistoryYear(table, d(2027, 4, 1))!
            .days
            .expand((day) => day.events)
            .map((e) => e.id),
        ['b'],
      );
    });

    test('is null when no event falls in the year', () {
      expect(buildHistoryYear(SgpcEventTable.empty, d(2026, 11, 3)), isNull);
      expect(
        buildHistoryYear(
          SgpcEventTable([event('a', d(2024, 5, 1))]),
          d(2026, 11, 3),
        ),
        isNull,
      );
    });

    test('lists an event of several days once, on its first day', () {
      final table = SgpcEventTable([
        event('mela', d(2026, 10, 7), last: d(2026, 10, 9)),
        event('other', d(2026, 10, 7)),
      ]);

      final year = buildHistoryYear(table, d(2026, 10, 1))!;

      final row = year.months.single.days.single;
      expect(row.first, d(2026, 10, 7));
      expect(row.last, d(2026, 10, 9));
      expect(row.isRange, isTrue);
      expect(row.events.map((e) => e.id), ['mela', 'other']);
    });
  });

  group('today', () {
    final table = SgpcEventTable([
      event('past', d(2026, 11, 1)),
      event('today', d(2026, 11, 3)),
      event('mela', d(2026, 11, 5), last: d(2026, 11, 7)),
      event('later', d(2026, 11, 20)),
    ]);

    HistoryTense tenseOf(HistoryYear year, String id) => year.days
        .firstWhere((day) => day.events.any((e) => e.id == id))
        .tense(year.today);

    test('marks past days, today and the days to come', () {
      final year = buildHistoryYear(table, d(2026, 11, 3))!;

      expect(tenseOf(year, 'past'), HistoryTense.past);
      expect(tenseOf(year, 'today'), HistoryTense.today);
      expect(tenseOf(year, 'mela'), HistoryTense.upcoming);
      expect(tenseOf(year, 'later'), HistoryTense.upcoming);
    });

    test('counts an event of several days as today on each of its days', () {
      for (final day in [5, 6, 7]) {
        final year = buildHistoryYear(table, d(2026, 11, day))!;
        expect(tenseOf(year, 'mela'), HistoryTense.today, reason: 'day $day');
      }
      expect(
        tenseOf(buildHistoryYear(table, d(2026, 11, 8))!, 'mela'),
        HistoryTense.past,
      );
    });

    test('opens on today’s row', () {
      final year = buildHistoryYear(table, d(2026, 11, 3))!;

      expect(year.focus!.events.single.id, 'today');
    });

    test('opens on the next row when today has no event', () {
      final year = buildHistoryYear(table, d(2026, 11, 4))!;

      expect(year.focus!.events.single.id, 'mela');
    });

    test('opens on the last row when the year has run out', () {
      final year = buildHistoryYear(table, d(2027, 3, 1))!;

      expect(year.focus!.events.single.id, 'later');
      expect(year.days.every((day) => day.tense(year.today) == HistoryTense.past),
          isTrue);
    });

    test('opens on the first row before the year’s first event', () {
      final year = buildHistoryYear(table, d(2026, 3, 14))!;

      expect(year.focus!.events.single.id, 'past');
    });

    test('is the same on a time of day, as the SGPC day is only a date', () {
      final year = buildHistoryYear(table, DateTime.utc(2026, 11, 3, 18, 30))!;

      expect(year.today, d(2026, 11, 3));
    });
  });

  group('the shipped calendar', () {
    test('shows every reviewed event of the year, once', () {
      final year = buildHistoryYear(shipped, d(2026, 11, 3))!;

      final listed = year.days.expand((day) => day.events).toList();
      expect(listed.map((e) => e.id).toSet(), hasLength(listed.length));
      expect(listed, hasLength(shipped.events.length),
          reason: 'none left out and none repeated');
      expect(year.number, 558);
      expect(year.months.first.month, 3);
      expect(year.months.length, greaterThanOrEqualTo(12));
    });

    test('opens on 3 November, which has 3 events', () {
      final year = buildHistoryYear(shipped, d(2026, 11, 3))!;

      expect(year.focus!.first, d(2026, 11, 3));
      expect(year.focus!.events, hasLength(3));
    });
  });
}
