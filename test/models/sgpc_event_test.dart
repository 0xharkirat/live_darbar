import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/models/sgpc_day.dart';
import 'package:live_darbar/src/models/sgpc_event.dart';

/// What falls on a day, from SGPC's calendar: a day with events, a day with
/// none, an event that runs for days, and the edge between two years' files.
void main() {
  final shippedSource =
      File('assets/data/sgpc_events_558.json').readAsStringSync();
  final shipped = SgpcEventTable.fromJsonString(shippedSource);

  DateTime day(int y, int m, int d) => DateTime.utc(y, m, d);

  /// A file with the events given as (id, date, end).
  String file(List<(String, String, String?)> events) => jsonEncode({
        'version': 1,
        'events': [
          for (final (id, date, end) in events)
            {
              'id': id,
              'gregorian': date,
              if (end != null) 'gregorianEnd': end,
              'titlePa': 'ਸਿਰਲੇਖ $id',
              'titleEn': 'Title $id',
            },
        ],
      });

  group('the shipped file for year 558', () {
    test('has 120 events to show and leaves 8 that need review out', () {
      final all = SgpcEventTable.fromJsonString(
        shippedSource,
        includeUnreviewed: true,
      );

      expect(all.events, hasLength(128));
      expect(shipped.events, hasLength(120));
      expect(shipped.events.any((e) => e.needsReview), isFalse);
      expect(all.events.where((e) => e.needsReview), hasLength(8));
    });

    test('puts every event on its own day', () {
      for (final e in shipped.events) {
        expect(shipped.on(e.first), contains(e), reason: '$e');
        expect(shipped.on(e.last), contains(e), reason: '$e');
      }
    });

    test('keeps each sangrand on a month start in the sangrand table', () {
      final table = jsonDecode(
        File('assets/data/sgpc_sangrands.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final starts = {
        for (final m in table['months'] as List)
          parseSgpcDay((m as Map<String, dynamic>)['start'] as String),
      };

      final sangrands = shipped.events
          .where((e) => e.titleEn?.startsWith('Sangrand ') ?? false);
      expect(sangrands, hasLength(12));
      for (final e in sangrands) {
        expect(starts, contains(e.first), reason: '$e');
      }
    });

    test('has no day with more than 3 events', () {
      for (var i = 0; i < 366; i++) {
        final d = day(2026, 3, 14 + i);
        expect(shipped.on(d).length, lessThanOrEqualTo(3), reason: '$d');
      }
    });
  });

  group('today', () {
    test('lists the events of the day in the order of the calendar', () {
      final events = shipped.on(day(2026, 11, 3));

      expect(events.map((e) => e.id), ['ns558-082', 'ns558-083', 'ns558-084']);
      expect(events.map((e) => e.title(punjabi: false)), [
        'Gurgaddi Divas Sri Guru Harkrishan Sahib Ji',
        'Joti-Jot Divas Sri Guru Har Rai Sahib Ji',
        'Janam Dihada Mata Sahib Kaur Ji',
      ]);
      expect(events.first.title(punjabi: true),
          'ਗੁਰਿਆਈ ਦਿਵਸ ਸ੍ਰੀ ਗੁਰੂ ਹਰਿਕ੍ਰਿ\u0A36ਨ ਸਾਹਿਬ ਜੀ');
    });

    test('answers for the same day whatever time of day it is given', () {
      expect(shipped.on(DateTime.utc(2026, 11, 3, 23, 59)),
          shipped.on(day(2026, 11, 3)));
    });

    test('falls back to the Punjabi title when there is no English one', () {
      final all = SgpcEventTable.fromJsonString(
        shippedSource,
        includeUnreviewed: true,
      );
      final event = all.events.singleWhere((e) => e.id == 'ns558-023');

      expect(event.titleEn, isNull);
      expect(event.title(punjabi: false), event.titlePa);
    });
  });

  group('a day with none', () {
    test('is an empty list, not an error', () {
      expect(shipped.on(day(2026, 11, 2)), isEmpty);
      expect(SgpcEventTable.empty.on(day(2026, 11, 3)), isEmpty);
    });

    test('is also what a day with only an event that needs review gives', () {
      // 1 May 2026 holds 1 event, found only in the Jantri by OCR.
      final all = SgpcEventTable.fromJsonString(
        shippedSource,
        includeUnreviewed: true,
      );

      expect(all.on(day(2026, 5, 1)).map((e) => e.id), ['ns558-023']);
      expect(shipped.on(day(2026, 5, 1)), isEmpty);
    });
  });

  group('an event that runs for days', () {
    final table = SgpcEventTable.fromJsonString(
      file([('a', '2026-10-07', '2026-10-08'), ('b', '2026-10-08', null)]),
    );

    test('is on every day from the first to the last, both included', () {
      expect(table.on(day(2026, 10, 6)), isEmpty);
      expect(table.on(day(2026, 10, 7)).map((e) => e.id), ['a']);
      expect(table.on(day(2026, 10, 8)).map((e) => e.id), ['a', 'b']);
      expect(table.on(day(2026, 10, 9)), isEmpty);
    });

    test('is the same event on each of its days', () {
      expect(
          table.on(day(2026, 10, 7)).single, table.on(day(2026, 10, 8)).first);
    });

    test('is right for the joor mela in the shipped file', () {
      // ns558-070 runs 7 and 8 October.
      expect(shipped.on(day(2026, 10, 6)).map((e) => e.id),
          isNot(contains('ns558-070')));
      expect(
          shipped.on(day(2026, 10, 7)).map((e) => e.id), contains('ns558-070'));
      expect(
          shipped.on(day(2026, 10, 8)).map((e) => e.id), contains('ns558-070'));
      expect(shipped.on(day(2026, 10, 9)).map((e) => e.id),
          isNot(contains('ns558-070')));
    });

    test('cannot end before it starts, or run for a month', () {
      for (final end in ['2026-10-06', '2026-12-01']) {
        expect(
          () => SgpcEventTable.fromJsonString(
            file([('a', '2026-10-07', end)]),
          ),
          throwsFormatException,
          reason: end,
        );
      }
    });
  });

  group('the year edge', () {
    test('starts on the first day of the file and not before', () {
      expect(shipped.on(day(2026, 3, 14)).map((e) => e.id), [
        'ns558-001',
        'ns558-002',
        'ns558-003',
      ]);
      expect(shipped.on(day(2026, 3, 13)), isEmpty);
    });

    test('has nothing past the file, until the next year\'s file is added', () {
      expect(shipped.on(day(2027, 3, 14)), isEmpty);
      expect(shipped.on(day(2027, 3, 15)), isEmpty);
      expect(shipped.on(day(2027, 6, 1)), isEmpty);
    });

    test('joins 2 years\' files, and an event can run across the edge', () {
      final y558 = SgpcEventTable.fromJsonString(
        file([
          ('last', '2027-03-14', '2027-03-16'),
          ('end', '2027-03-14', null)
        ]),
      );
      final y559 = SgpcEventTable.fromJsonString(
        file([('first', '2027-03-15', null)]),
      );
      final both = SgpcEventTable.merge([y558, y559]);

      expect(both.on(day(2027, 3, 13)), isEmpty);
      expect(both.on(day(2027, 3, 14)).map((e) => e.id), ['last', 'end']);
      expect(both.on(day(2027, 3, 15)).map((e) => e.id), ['last', 'first']);
      expect(both.on(day(2027, 3, 16)).map((e) => e.id), ['last']);
      expect(both.on(day(2027, 3, 17)), isEmpty);
      expect(both.events.map((e) => e.id), ['last', 'end', 'first']);
    });
  });

  group('a file that is wrong', () {
    test('is refused with a FormatException', () {
      const bad = {
        'not JSON': 'this is not json',
        'no events list': '{"version": 1}',
        'event not an object': '{"events": [1]}',
        'a day that does not exist':
            '{"events": [{"id": "a", "gregorian": "2026-02-30", "titlePa": "ਉ"}]}',
        'a date in another shape':
            '{"events": [{"id": "a", "gregorian": "3 Nov 2026", "titlePa": "ਉ"}]}',
        'no date': '{"events": [{"id": "a", "titlePa": "ਉ"}]}',
        'no Punjabi title':
            '{"events": [{"id": "a", "gregorian": "2026-11-03"}]}',
        'a blank Punjabi title':
            '{"events": [{"id": "a", "gregorian": "2026-11-03", "titlePa": "  "}]}',
      };
      for (final entry in bad.entries) {
        expect(
          () => SgpcEventTable.fromJsonString(entry.value),
          throwsFormatException,
          reason: entry.key,
        );
      }
    });
  });

  group('the next day with an event', () {
    test('is the first day after the one given', () {
      final next = shipped.after(day(2026, 11, 4));

      expect(next.map((e) => e.titleEn), ['Bandi Chhor Divas (Diwali)']);
      expect(next.single.first, day(2026, 11, 8));
    });

    test('never includes the day given, even when it has events', () {
      expect(shipped.after(day(2026, 11, 3)).single.first, day(2026, 11, 8));
    });

    test('lists every event of that day, in the order of the calendar', () {
      final table = SgpcEventTable.fromJsonString(file([
        ('late', '2026-11-20', null),
        ('a', '2026-11-08', null),
        ('b', '2026-11-08', null),
      ]));

      expect(table.after(day(2026, 11, 4)).map((e) => e.id), ['a', 'b']);
    });

    test('is empty after the last event of the last file', () {
      final last = day(2027, 2, 21);
      expect(shipped.after(last.subtract(const Duration(days: 1))), isNotEmpty);
      expect(shipped.after(last), isEmpty);
      expect(shipped.after(day(2030, 1, 1)), isEmpty);
      expect(SgpcEventTable.empty.after(day(2026, 11, 4)), isEmpty);
    });

    test('looks into the next year’s file when there is one', () {
      final next = SgpcEventTable.fromJsonString(file([
        ('ns559-001', '2027-03-20', null),
      ]));
      final both = SgpcEventTable.merge([shipped, next]);

      expect(both.after(day(2027, 2, 21)).single.id, 'ns559-001');
      expect(shipped.after(day(2027, 2, 21)), isEmpty,
          reason: 'with that file alone, nothing is next');
    });

    test('counts an event of several days from its first day', () {
      final table = SgpcEventTable.fromJsonString(file([
        ('mela', '2026-10-07', '2026-10-09'),
      ]));

      expect(table.after(day(2026, 10, 6)).single.id, 'mela');
      expect(table.after(day(2026, 10, 7)), isNotEmpty,
          reason: 'the 8th is a day of the mela, but it is not a new event '
              'for a listener already inside it; the line shows today then');
      expect(table.after(day(2026, 10, 9)), isEmpty);
    });

    test('reads the SGPC day, so a time of day does not move it', () {
      expect(
        shipped.after(DateTime.utc(2026, 11, 4, 23, 59)).single.first,
        day(2026, 11, 8),
      );
    });
  });
}
