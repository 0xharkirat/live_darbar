import 'package:live_darbar/src/models/reminder_time.dart';
import 'package:timezone/timezone.dart' as tz;

/// The first moment the reminder fires, counted from [now].
///
/// That is [time] today if it is still ahead, and tomorrow if it has passed or
/// is this very minute. The phone repeats it every day from there, matching on
/// the wall-clock time, so the reminder keeps its hour through a change of
/// clocks.
///
/// The first moment must read exactly as [time] on the wall. On the day the
/// clocks jump forward, 2:30 does not exist, and the clock would show 3:30.
/// Android keeps the first moment's wall-clock time and repeats that, so a
/// 3:30 start would make every later reminder 3:30. That day is skipped and
/// the reminder starts the day after.
tz.TZDateTime nextReminder(tz.TZDateTime now, ReminderTime time) {
  tz.TZDateTime on(int dayOffset) => tz.TZDateTime(
        now.location,
        now.year,
        now.month,
        now.day + dayOffset,
        time.hour,
        time.minute,
      );

  var dayOffset = 0;
  while (true) {
    final candidate = on(dayOffset);
    final exists =
        candidate.hour == time.hour && candidate.minute == time.minute;
    if (exists && candidate.isAfter(now)) return candidate;
    // A time that does not exist is only skipped for 1 day, so this ends.
    dayOffset++;
  }
}

/// [time] on the calendar day [day], in the zone of [now], or null when that
/// moment is not ahead of [now].
///
/// For a notification that fires once, as "Today in Sikh history" does. The
/// calendar day is the year, month and day of [day], which is an SGPC day at
/// UTC midnight.
///
/// A time that does not exist on the day the clocks go forward (2:30) reads as
/// the hour after it. A single notification has no wall-clock time to keep, so
/// it still fires, unlike the repeating reminder in [nextReminder].
tz.TZDateTime? timeOnDay(tz.TZDateTime now, DateTime day, ReminderTime time) {
  final moment = tz.TZDateTime(
    now.location,
    day.year,
    day.month,
    day.day,
    time.hour,
    time.minute,
  );
  return moment.isAfter(now) ? moment : null;
}
