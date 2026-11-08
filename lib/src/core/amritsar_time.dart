import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/src/models/reminder_time.dart';
import 'package:live_darbar/src/models/sgpc_day.dart';

/// How far the listener's clock is from UTC at [instant]. Daylight saving is
/// in it, so the same function gives 10 hours in Sydney on 3 October 2026 and
/// 11 hours on 5 October.
typedef LocalOffset = Duration Function(DateTime instant);

/// The phone's own offset.
Duration deviceOffset(DateTime instant) => instant.toLocal().timeZoneOffset;

/// The phone's offset, behind a provider so a test can stand in for another
/// time zone.
final localOffsetProvider = Provider<LocalOffset>((ref) => deviceOffset);

/// [time] on the listener's clock, for the SGPC day [day].
///
/// A time on the listener's own clock is returned as it is. A time in Amritsar
/// is turned into the hour and minute that the listener's wall clock shows at
/// that moment, on that day. The day matters because the listener's offset
/// moves with their daylight saving, and Amritsar's never does: 7:00 in
/// Amritsar is 12:30 in Sydney in summer and 11:30 in winter.
ReminderTime onListenersClock(
  ReminderTime time,
  DateTime day, {
  LocalOffset offset = deviceOffset,
}) {
  if (time.zone == ReminderZone.local) return time;
  final instant = DateTime.utc(
    day.year,
    day.month,
    day.day,
    time.hour,
    time.minute,
  ).subtract(kIndiaOffset);
  final local = instant.add(offset(instant));
  return ReminderTime(local.hour, local.minute);
}

/// [time], a time on the listener's own clock, as the clock in Amritsar reads
/// at that moment on the SGPC day [day].
///
/// The reverse of [onListenersClock]: 1:30 PM in Sydney in summer is 8:00 AM
/// in Amritsar. The reminder sheet shows it under the wheel as the wheel turns.
ReminderTime inAmritsar(
  ReminderTime time,
  DateTime day, {
  LocalOffset offset = deviceOffset,
}) {
  final wall =
      DateTime.utc(day.year, day.month, day.day, time.hour, time.minute);
  // The offset is the one in force at that moment, so it is read at the wall
  // time moved back by a first guess of itself. Only the hour around a
  // daylight saving change can tell the two reads apart.
  final instant = wall.subtract(offset(wall.subtract(offset(wall))));
  final there = instant.add(kIndiaOffset);
  return ReminderTime(there.hour, there.minute, zone: ReminderZone.amritsar);
}
