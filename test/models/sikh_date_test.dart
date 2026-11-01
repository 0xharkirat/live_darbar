import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/models/sikh_date.dart';

/// The table the app ships, read straight from the asset file.
SangrandTable shippedTable() => SangrandTable.fromJsonString(
      File('assets/data/sgpc_sangrands.json').readAsStringSync(),
    );

DateTime day(int y, int m, int d) => DateTime.utc(y, m, d);

int fromGurmukhiNumerals(String s) {
  const digits = '੦੧੨੩੪੫੬੭੮੯';
  return int.parse(s.split('').map((c) => digits.indexOf(c)).join());
}

void main() {
  final table = shippedTable();

  group('SGPC dates the table must reproduce', () {
    // test/fixtures/sgpc_nanakshahi_dates.json holds what SGPC's own archive
    // (hs.sgpc.net) printed in its date footer for each day, recorded on
    // 2026-11-02. The expectations below are parsed from SGPC's Gurmukhi
    // footer, so they are SGPC's answer and not ours.
    final fixture = (jsonDecode(
      File('test/fixtures/sgpc_nanakshahi_dates.json').readAsStringSync(),
    ) as List<dynamic>)
        .cast<Map<String, dynamic>>();

    test('the fixture holds enough dates to mean something', () {
      expect(fixture.length, greaterThanOrEqualTo(6));
    });

    for (final row in fixture) {
      final iso = row['date'] as String;
      final footer = row['gurmukhi'] as String;

      test('$iso: $footer', () {
        final m =
            RegExp(r', ([੦-੯]+) (\S+) \(ਸੰਮਤ ([੦-੯]+)').firstMatch(footer);
        expect(m, isNotNull, reason: 'footer not understood: $footer');
        final wantDay = fromGurmukhiNumerals(m!.group(1)!);
        final wantMonth = kSikhMonthsGurmukhi.indexOf(m.group(2)!);
        final wantYear = fromGurmukhiNumerals(m.group(3)!);
        expect(wantMonth, isNot(-1), reason: 'month ${m.group(2)} unknown');

        final parts = iso.split('-').map(int.parse).toList();
        final when = day(parts[0], parts[1], parts[2]);
        final date = table.sikhDateFor(when);

        if (when.isBefore(table.firstDay)) {
          // SGPC knows this day and the table does not start early enough.
          // Saying nothing is the contract; guessing would be the bug.
          expect(date, isNull);
          return;
        }
        expect(date, isNotNull);
        expect(date!.day, wantDay);
        expect(date.monthIndex, wantMonth);
        expect(date.year, wantYear);
      });
    }
  });

  group('known dates', () {
    test('2 November 2026 is 17 Katak 558', () {
      final d = table.sikhDateFor(day(2026, 11, 2))!;
      expect(d.day, 17);
      expect(d.monthEnglish, 'Katak');
      expect(d.monthGurmukhi, 'ਕੱਤਕ');
      expect(d.monthIndex, 7);
      expect(d.year, 558);
      expect(d.gregorian, day(2026, 11, 2));
    });

    test(
        '15 November 2025 is 30 Katak 557, where the fixed 2003 rule says '
        '2 Maghar', () {
      final d = table.sikhDateFor(day(2025, 11, 15))!;
      expect([d.day, d.monthEnglish, d.year], [30, 'Katak', 557]);
    });

    test('the month ends and the next begins on SGPC\'s sangrand', () {
      expect(table.sikhDateFor(day(2025, 11, 15))!.monthEnglish, 'Katak');
      final maghar = table.sikhDateFor(day(2025, 11, 16))!;
      expect([maghar.day, maghar.monthEnglish], [1, 'Maghar']);
    });

    test('Savan 558 runs 32 days, because SGPC says so', () {
      expect(table.sikhDateFor(day(2026, 7, 16))!.day, 1);
      final last = table.sikhDateFor(day(2026, 8, 16))!;
      expect([last.day, last.monthEnglish], [32, 'Savan']);
      final next = table.sikhDateFor(day(2026, 8, 17))!;
      expect([next.day, next.monthEnglish], [1, 'Bhadon']);
    });

    test('the year changes on 1 Chet, not on 1 January', () {
      final lastOfPhagun = table.sikhDateFor(day(2026, 3, 13))!;
      expect([lastOfPhagun.day, lastOfPhagun.monthEnglish, lastOfPhagun.year],
          [30, 'Phagun', 557]);
      final newYear = table.sikhDateFor(day(2026, 3, 14))!;
      expect(
          [newYear.day, newYear.monthEnglish, newYear.year], [1, 'Chet', 558]);

      final dec = table.sikhDateFor(day(2026, 12, 31))!;
      final jan = table.sikhDateFor(day(2027, 1, 1))!;
      expect(dec.year, 558);
      expect(jan.year, 558);
    });

    test('a leap day needs no special case', () {
      // 29 February 2028 falls inside Phagun 559, a month of 30 or 31 days.
      final d = table.sikhDateFor(day(2028, 2, 29))!;
      expect(d.monthEnglish, 'Phagun');
      expect(d.year, 559);
    });

    test('time of day and zone on the input are ignored', () {
      final late = DateTime.utc(2026, 11, 2, 23, 59, 59);
      expect(table.sikhDateFor(late), table.sikhDateFor(day(2026, 11, 2)));
      final local = DateTime(2026, 11, 2, 13, 30);
      expect(table.sikhDateFor(local)!.day, 17);
    });
  });

  group('failing soft', () {
    test('a day before the table is null', () {
      expect(table.sikhDateFor(day(2025, 3, 13)), isNull);
      expect(table.sikhDateFor(day(2003, 3, 14)), isNull);
    });

    test('a day on or after the end of the table is null', () {
      final end = table.endExclusive;
      expect(table.sikhDateFor(end), isNull);
      expect(table.sikhDateFor(end.add(const Duration(days: 400))), isNull);
      expect(
        table.sikhDateFor(end.subtract(const Duration(days: 1))),
        isNotNull,
      );
    });

    test('a month flagged uncertain answers null for every day in it', () {
      final uncertain = table.months.where((m) => m.uncertain).toList();
      expect(uncertain, isNotEmpty,
          reason: 'the shipped table flags Savan 559');
      for (final m in uncertain) {
        final i = table.months.indexOf(m);
        final next = table.months[i + 1].start;
        for (var d = m.start;
            d.isBefore(next);
            d = d.add(const Duration(days: 1))) {
          expect(table.sikhDateFor(d), isNull, reason: '$d');
        }
        // The day either side is still answered.
        expect(
          table.sikhDateFor(m.start.subtract(const Duration(days: 1))),
          isNotNull,
        );
      }
    });

    test('a broken file is refused whole', () {
      expect(() => SangrandTable.fromJsonString('not json'),
          throwsFormatException);
      expect(() => SangrandTable.fromJsonString('[]'), throwsFormatException);
      expect(() => SangrandTable.fromJsonString('{"months": 3}'),
          throwsFormatException);
      expect(
        () => SangrandTable.fromJsonString(
            '{"months": [{"start": "2026-03-14", "month": "x", "year": 558}, '
            '{"start": "2026-04-14", "month": 1, "year": 558}]}'),
        throwsFormatException,
      );
    });

    test('rows that skip a month or run the wrong length are refused', () {
      SangrandMonth row(DateTime start, int month, int year) => SangrandMonth(
          start: start, monthIndex: month, year: year, source: 'test');

      expect(
        () => SangrandTable([
          row(day(2026, 3, 14), 0, 558),
          row(day(2026, 5, 15), 2, 558), // Vaisakh missing
        ]),
        throwsFormatException,
      );
      expect(
        () => SangrandTable([
          row(day(2026, 3, 14), 0, 558),
          row(day(2026, 3, 20), 1, 558), // 6 days long
        ]),
        throwsFormatException,
      );
      expect(
        () => SangrandTable([
          row(day(2026, 2, 12), 11, 557),
          row(day(2026, 3, 14), 0, 557), // year did not change on Chet
        ]),
        throwsFormatException,
      );
    });
  });

  group('the shipped table', () {
    test('every month is 29 to 32 days and follows the one before', () {
      final months = table.months;
      for (var i = 1; i < months.length; i++) {
        final length = months[i].start.difference(months[i - 1].start).inDays;
        expect(length, inInclusiveRange(29, 32), reason: '${months[i].start}');
        expect(months[i].monthIndex, (months[i - 1].monthIndex + 1) % 12);
      }
    });

    test('covers every day of 2026, 2027 and 2028 except flagged months', () {
      final flagged = <DateTime>{};
      for (var i = 0; i < table.months.length - 1; i++) {
        if (!table.months[i].uncertain) continue;
        for (var d = table.months[i].start;
            d.isBefore(table.months[i + 1].start);
            d = d.add(const Duration(days: 1))) {
          flagged.add(d);
        }
      }
      var answered = 0;
      for (var d = day(2026, 1, 1);
          !d.isAfter(day(2028, 12, 31));
          d = d.add(const Duration(days: 1))) {
        if (flagged.contains(d)) continue;
        expect(table.sikhDateFor(d), isNotNull, reason: '$d has no Sikh date');
        answered++;
      }
      expect(answered, greaterThan(1000));
    });

    test('day numbers count up by one, and drop to 1 only on a month start',
        () {
      SikhDate? previous;
      for (var d = day(2025, 3, 14);
          d.isBefore(day(2028, 3, 1));
          d = d.add(const Duration(days: 1))) {
        final today = table.sikhDateFor(d);
        if (today == null) {
          previous = null;
          continue;
        }
        if (previous != null) {
          if (today.day == 1) {
            expect(today.monthIndex, (previous.monthIndex + 1) % 12);
          } else {
            expect(today.day, previous.day + 1, reason: '$d');
            expect(today.monthIndex, previous.monthIndex);
          }
        }
        previous = today;
      }
    });

    test('names are the 12 months in order', () {
      expect(kSikhMonthsEnglish.length, 12);
      expect(kSikhMonthsGurmukhi.length, 12);
      expect(kSikhMonthsEnglish.first, 'Chet');
      expect(kSikhMonthsEnglish.last, 'Phagun');
      expect(kSikhMonthsGurmukhi.toSet().length, 12);
    });
  });

  group('SikhDate', () {
    test('writes Gurmukhi digits', () {
      expect(toGurmukhiNumerals(0), '੦');
      expect(toGurmukhiNumerals(17), '੧੭');
      expect(toGurmukhiNumerals(558), '੫੫੮');
      expect(toGurmukhiNumerals(2026), '੨੦੨੬');
    });

    test('labels match the end of SGPC\'s own footer', () {
      final d = table.sikhDateFor(day(2026, 11, 2))!;
      expect(d.gurmukhiLabel, '੧੭ ਕੱਤਕ (ਸੰਮਤ ੫੫੮ ਨਾਨਕਸ਼ਾਹੀ)');
      expect(d.englishLabel, '17 Katak (Samvat 558 Nanakshahi)');
      // SGPC printed: ਸੋਮਵਾਰ, ੧੭ ਕੱਤਕ (ਸੰਮਤ ੫੫੮ ਨਾਨਕਸ਼ਾਹੀ)
      expect(d.dayGurmukhi, '੧੭');
      expect(d.yearGurmukhi, '੫੫੮');
    });

    test('equal dates are equal', () {
      final a = SikhDate(
          day: 17, monthIndex: 7, year: 558, gregorian: day(2026, 11, 2));
      final b = SikhDate(
          day: 17, monthIndex: 7, year: 558, gregorian: day(2026, 11, 2));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
