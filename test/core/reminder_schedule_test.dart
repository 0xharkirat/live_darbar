import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/core/reminder_schedule.dart';
import 'package:live_darbar/src/models/reminder_time.dart';
import 'package:timezone/data/latest_10y.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// When the daily reminder first fires, and how it keeps its hour when the
/// clocks change. The phone repeats the first moment each day on the wall
/// clock, so the first moment must read exactly as the chosen time.
void main() {
  setUpAll(tz_data.initializeTimeZones);

  tz.TZDateTime at(
    String zone,
    int year,
    int month,
    int day,
    int hour, [
    int minute = 0,
  ]) =>
      tz.TZDateTime(tz.getLocation(zone), year, month, day, hour, minute);

  group('the first moment', () {
    test('is today when the time is still ahead', () {
      final now = at('Asia/Kolkata', 2026, 11, 3, 5, 59);

      expect(
        nextReminder(now, ReminderTime.standard),
        at('Asia/Kolkata', 2026, 11, 3, 7),
      );
    });

    test('is tomorrow when the time has passed', () {
      final now = at('Asia/Kolkata', 2026, 11, 3, 7, 1);

      expect(
        nextReminder(now, ReminderTime.standard),
        at('Asia/Kolkata', 2026, 11, 4, 7),
      );
    });

    test('is tomorrow in the very minute, so it never fires late', () {
      final now = at('Asia/Kolkata', 2026, 11, 3, 7);

      expect(
        nextReminder(now, ReminderTime.standard),
        at('Asia/Kolkata', 2026, 11, 4, 7),
      );
    });

    test('is tomorrow when the time is the second after', () {
      final now = at('Asia/Kolkata', 2026, 11, 3, 7).add(
        const Duration(seconds: 30),
      );

      expect(
        nextReminder(now, ReminderTime.standard),
        at('Asia/Kolkata', 2026, 11, 4, 7),
      );
    });

    test('crosses the end of a month and of a year', () {
      expect(
        nextReminder(
          at('Asia/Kolkata', 2026, 12, 31, 8),
          ReminderTime.standard,
        ),
        at('Asia/Kolkata', 2027, 1, 1, 7),
      );
      expect(
        nextReminder(at('Asia/Kolkata', 2028, 2, 28, 8), ReminderTime.standard),
        at('Asia/Kolkata', 2028, 2, 29, 7),
        reason: '2028 is a leap year',
      );
    });

    test('handles a time just after midnight and one just before', () {
      final now = at('Asia/Kolkata', 2026, 11, 3, 0, 10);

      expect(
        nextReminder(now, const ReminderTime(0, 5)),
        at('Asia/Kolkata', 2026, 11, 4, 0, 5),
      );
      expect(
        nextReminder(now, const ReminderTime(23, 59)),
        at('Asia/Kolkata', 2026, 11, 3, 23, 59),
      );
    });

    test('is always ahead of now and within a day, at any minute', () {
      final zone = tz.getLocation('America/New_York');
      for (var m = 0; m < 24 * 60; m += 7) {
        final now = tz.TZDateTime(zone, 2026, 3, 7, m ~/ 60, m % 60);
        for (final time in const [
          ReminderTime(0, 0),
          ReminderTime(2, 30),
          ReminderTime(7, 0),
          ReminderTime(23, 59),
        ]) {
          final next = nextReminder(now, time);
          expect(next.isAfter(now), isTrue, reason: '$now, $time');
          expect(
            next.difference(now),
            lessThanOrEqualTo(const Duration(hours: 49)),
            reason: '$now, $time',
          );
          expect([next.hour, next.minute], [time.hour, time.minute]);
        }
      }
    });
  });

  group('when the clocks change', () {
    test('keeps 7:00 when they go forward, so 8:00 to 7:00 is 22 hours', () {
      // New York, 8 March 2026: 2:00 became 3:00.
      final now = at('America/New_York', 2026, 3, 7, 8);

      final next = nextReminder(now, ReminderTime.standard);

      expect([next.year, next.month, next.day], [2026, 3, 8]);
      expect([next.hour, next.minute], [7, 0]);
      expect(next.difference(now), const Duration(hours: 22));
    });

    test('keeps 7:00 when they go back, so 8:00 to 7:00 is 24 hours', () {
      // New York, 1 November 2026: 2:00 became 1:00.
      final now = at('America/New_York', 2026, 10, 31, 8);

      final next = nextReminder(now, ReminderTime.standard);

      expect([next.year, next.month, next.day], [2026, 11, 1]);
      expect([next.hour, next.minute], [7, 0]);
      expect(next.difference(now), const Duration(hours: 24));
    });

    test('keeps 7:00 in the southern spring and autumn', () {
      // Sydney, 4 October 2026 (forward) and 5 April 2026 (back).
      final spring = nextReminder(
        at('Australia/Sydney', 2026, 10, 3, 8),
        ReminderTime.standard,
      );
      final autumn = nextReminder(
        at('Australia/Sydney', 2026, 4, 4, 8),
        ReminderTime.standard,
      );

      expect([spring.day, spring.hour], [4, 7]);
      expect([autumn.day, autumn.hour], [5, 7]);
    });

    test('skips the day that has no 2:30, so the phone never repeats 3:30', () {
      // 8 March 2026 in New York has no 2:30. A first moment of 3:30 would
      // become every later reminder on Android.
      final now = at('America/New_York', 2026, 3, 7, 12);

      final next = nextReminder(now, const ReminderTime(2, 30));

      expect([next.month, next.day], [3, 9]);
      expect([next.hour, next.minute], [2, 30]);
    });

    test('skips it for a time inside the gap, but not for the hour after', () {
      final now = at('America/New_York', 2026, 3, 7, 12);

      expect(nextReminder(now, const ReminderTime(2, 0)).day, 9);
      expect(nextReminder(now, const ReminderTime(1, 59)).day, 8);
      expect(nextReminder(now, const ReminderTime(3, 0)).day, 8);
    });

    test('takes the day that has 1:30 twice', () {
      final now = at('America/New_York', 2026, 10, 31, 12);

      final next = nextReminder(now, const ReminderTime(1, 30));

      expect([next.month, next.day], [11, 1]);
      expect([next.hour, next.minute], [1, 30]);
    });
  });

  group('ReminderTime', () {
    test('starts at 7:00 in Amritsar', () {
      expect(
        ReminderTime.standard,
        const ReminderTime(7, 0, zone: ReminderZone.amritsar),
      );
      expect(ReminderTime.standard.minutes, 420);
      expect(ReminderTime.standard, isNot(const ReminderTime(7, 0)),
          reason: '7:00 on the listener’s own clock is another time');
    });

    test('round-trips through minutes', () {
      for (final minutes in [0, 1, 59, 60, 420, 719, 720, 1439]) {
        expect(ReminderTime.tryFromMinutes(minutes)!.minutes, minutes);
      }
    });

    test('refuses a value that is not a time of day', () {
      expect(ReminderTime.tryFromMinutes(null), isNull);
      expect(ReminderTime.tryFromMinutes(-1), isNull);
      expect(ReminderTime.tryFromMinutes(1440), isNull);
    });

    test('compares by value and prints as 24-hour', () {
      expect(const ReminderTime(7, 5), const ReminderTime(7, 5));
      expect(
          const ReminderTime(7, 5).hashCode, const ReminderTime(7, 5).hashCode);
      expect(const ReminderTime(7, 5), isNot(const ReminderTime(7, 6)));
      expect(const ReminderTime(7, 5).toString(), '07:05');
    });
  });
}
