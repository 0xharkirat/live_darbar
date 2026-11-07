import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:live_darbar/src/core/reader_numbers.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('pa');
  });

  group('readerNumber', () {
    test('writes Gurmukhi digits in Punjabi', () {
      expect(readerNumber(668, punjabi: true), '੬੬੮');
      expect(readerNumber(1430, punjabi: true), '੧੪੩੦');
      expect(readerNumber(2, punjabi: true), '੨');
    });

    test('writes Latin digits in English', () {
      expect(readerNumber(668, punjabi: false), '668');
      expect(readerNumber(2, punjabi: false), '2');
    });
  });

  group('readerDate', () {
    // 2 November 2026 is a Monday.
    final date = DateTime.utc(2026, 11, 2);

    test('Punjabi: Gurmukhi day, Punjabi month', () {
      expect(readerDate(date, punjabi: true), '੨ ਨਵੰਬਰ');
      expect(
        readerDate(DateTime.utc(2026, 11, 17), punjabi: true),
        '੧੭ ਨਵੰਬਰ',
      );
    });

    test('Punjabi with the weekday: only the day is a numeral', () {
      expect(
        readerDate(date, punjabi: true, weekday: true),
        'ਸੋਮਵਾਰ, ੨ ਨਵੰਬਰ',
      );
    });

    test('with the year, for a day that is not of this year', () {
      expect(readerDate(date, punjabi: false, year: true), '2 November 2026');
      expect(readerDate(date, punjabi: true, year: true), '੨ ਨਵੰਬਰ ੨੦੨੬');
      expect(
        readerDate(date, punjabi: false, weekday: true, year: true),
        'Monday, 2 November 2026',
      );
    });

    test('English: day before month, Latin digits', () {
      expect(readerDate(date, punjabi: false), '2 November');
      expect(
        readerDate(date, punjabi: false, weekday: true),
        'Monday, 2 November',
      );
    });
  });
}
