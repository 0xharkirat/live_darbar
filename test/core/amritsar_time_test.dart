import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/core/amritsar_time.dart';
import 'package:live_darbar/src/models/reminder_time.dart';
import 'package:timezone/data/latest_10y.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// 7:00 in Amritsar, on the listener's own clock.
///
/// Amritsar keeps India Standard Time all year. A listener's clock moves with
/// their daylight saving, so the same 7:00 reads differently from season to
/// season. The default must show the right local time for the day it is read.
void main() {
  setUpAll(tz_data.initializeTimeZones);

  /// The offset of a named zone, as the phone reports it for an instant.
  LocalOffset offsetOf(String zone) {
    final location = tz.getLocation(zone);
    return (instant) => tz.TZDateTime.from(instant, location).timeZoneOffset;
  }

  ReminderTime seven(DateTime day, String zone) =>
      onListenersClock(ReminderTime.standard, day, offset: offsetOf(zone));

  String clock(ReminderTime t) =>
      '${t.hour}:${t.minute.toString().padLeft(2, '0')}';

  group('7:00 in Amritsar', () {
    test('is 7:00 in India', () {
      expect(clock(seven(DateTime.utc(2026, 11, 3), 'Asia/Kolkata')), '7:00');
    });

    test('is 12:30 in Sydney in summer and 11:30 in winter', () {
      // Sydney's clocks go forward on Sunday 4 October 2026 at 2:00.
      expect(
        clock(seven(DateTime.utc(2026, 10, 3), 'Australia/Sydney')),
        '11:30',
        reason: 'the day before: AEST, UTC+10',
      );
      expect(
        clock(seven(DateTime.utc(2026, 10, 5), 'Australia/Sydney')),
        '12:30',
        reason: 'the day after: AEDT, UTC+11',
      );
      // And back on Sunday 4 April 2027 at 3:00, which is 16:00 UTC on the
      // 3rd. 7:00 in Amritsar on the 3rd is still before that.
      expect(
        clock(seven(DateTime.utc(2027, 4, 3), 'Australia/Sydney')),
        '12:30',
        reason: 'the day before: AEDT, UTC+11',
      );
      expect(
        clock(seven(DateTime.utc(2027, 4, 4), 'Australia/Sydney')),
        '11:30',
        reason: 'the day after: AEST, UTC+10',
      );
    });

    test('is 12:30 on the morning the clocks go forward', () {
      // 7:00 in Amritsar is 01:30 UTC. Sydney changes at 2:00 local, which is
      // 16:00 UTC the day before, so 01:30 UTC is already after the change.
      expect(
        clock(seven(DateTime.utc(2026, 10, 4), 'Australia/Sydney')),
        '12:30',
      );
    });

    test('is the evening before in California', () {
      final t = seven(DateTime.utc(2026, 7, 1), 'America/Los_Angeles');
      expect(clock(t), '18:30', reason: 'PDT is UTC-7: 01:30 UTC is 18:30');
      final winter = seven(DateTime.utc(2026, 12, 1), 'America/Los_Angeles');
      expect(clock(winter), '17:30', reason: 'PST is UTC-8');
    });

    test('is 1:30 in London in winter and 2:30 in summer', () {
      expect(clock(seven(DateTime.utc(2026, 12, 1), 'Europe/London')), '1:30');
      expect(clock(seven(DateTime.utc(2026, 7, 1), 'Europe/London')), '2:30');
    });

    test('is 5:30 in Dubai and 7:15 in Nepal', () {
      expect(clock(seven(DateTime.utc(2026, 11, 3), 'Asia/Dubai')), '5:30');
      expect(
        clock(seven(DateTime.utc(2026, 11, 3), 'Asia/Kathmandu')),
        '7:15',
      );
    });
  });

  group('a time on the listener’s own clock', () {
    test('is returned as it is, on any day', () {
      const picked = ReminderTime(21, 5);
      for (final day in [DateTime.utc(2026, 10, 3), DateTime.utc(2026, 10, 5)]) {
        expect(
          onListenersClock(picked, day, offset: offsetOf('Australia/Sydney')),
          picked,
        );
      }
    });
  });

  test('the device offset follows the phone’s zone', () {
    final instant = DateTime.utc(2026, 11, 3, 1, 30);
    expect(deviceOffset(instant), instant.toLocal().timeZoneOffset);
  });
}
