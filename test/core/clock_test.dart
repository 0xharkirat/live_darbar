import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/core/clock.dart';

void main() {
  group('untilNextMinute', () {
    test('on the minute, a whole minute, never 0', () {
      expect(
        untilNextMinute(DateTime.utc(2026, 11, 15, 14, 13)),
        const Duration(minutes: 1),
      );
    });

    test('the rest of the minute, to the microsecond', () {
      expect(
        untilNextMinute(DateTime.utc(2026, 11, 15, 14, 13, 59, 400)),
        const Duration(milliseconds: 600),
      );
      expect(
        untilNextMinute(DateTime.utc(2026, 11, 15, 14, 13, 59, 999, 999)),
        const Duration(microseconds: 1),
      );
    });
  });

  group('amritsarWallClock', () {
    test('is UTC plus 5:30', () {
      final there = amritsarWallClock(DateTime.utc(2026, 11, 15, 14, 13));
      expect((there.hour, there.minute), (19, 43));
    });

    test('18:30 UTC is midnight in Amritsar, on the next day', () {
      final there = amritsarWallClock(DateTime.utc(2026, 11, 15, 18, 30));
      expect((there.day, there.hour, there.minute), (16, 0, 0));
    });

    test('a time read in the phone\'s own zone gives the same wall clock', () {
      final instant = DateTime.utc(2026, 11, 15, 14, 13);
      final onThePhone =
          DateTime.fromMillisecondsSinceEpoch(instant.millisecondsSinceEpoch);
      expect(onThePhone.isUtc, isFalse);

      final there = amritsarWallClock(onThePhone);
      expect((there.hour, there.minute), (19, 43));
    });
  });
}
