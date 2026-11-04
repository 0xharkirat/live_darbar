import 'package:flutter/foundation.dart';

/// Whose clock a [ReminderTime] is read on.
enum ReminderZone {
  /// The clock at Sri Harmandir Sahib: India Standard Time, `Asia/Kolkata`.
  ///
  /// The Hukamnama is posted there, so the default follows it. The phone
  /// keeps the schedule in that zone, so the listener's own daylight saving
  /// never moves it.
  amritsar,

  /// The listener's own clock, where they are now. A time the listener picks
  /// is this one.
  local,
}

/// The time of day the reminder fires, and the clock it is read on.
///
/// It is a wall-clock time, not an instant: "7:00" stays 7:00 when the clocks
/// change. The phone repeats it each day from that.
@immutable
class ReminderTime {
  const ReminderTime(
    this.hour,
    this.minute, {
    this.zone = ReminderZone.local,
  })  : assert(hour >= 0 && hour < 24),
        assert(minute >= 0 && minute < 60);

  /// What the reminder starts at: 7:00 in Amritsar, when SGPC's Hukamnama has
  /// reached the app's mirror. The 3 November 2026 text arrived at 06:16.
  static const standard = ReminderTime(7, 0, zone: ReminderZone.amritsar);

  final int hour;
  final int minute;
  final ReminderZone zone;

  /// Minutes since midnight. This is how the time is stored, with [zone]
  /// beside it.
  int get minutes => hour * 60 + minute;

  /// The time stored as [minutes] on [zone]'s clock, or null for a value that
  /// is not a time of day, so a damaged setting falls back to [standard]
  /// instead of throwing.
  static ReminderTime? tryFromMinutes(
    int? minutes, {
    ReminderZone zone = ReminderZone.local,
  }) {
    if (minutes == null || minutes < 0 || minutes >= 24 * 60) return null;
    return ReminderTime(minutes ~/ 60, minutes % 60, zone: zone);
  }

  @override
  bool operator ==(Object other) =>
      other is ReminderTime &&
      other.hour == hour &&
      other.minute == minute &&
      other.zone == zone;

  @override
  int get hashCode => Object.hash(hour, minute, zone);

  /// "07:00" on the listener's clock, "07:00 IST" on Amritsar's.
  @override
  String toString() {
    final clock = '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
    return zone == ReminderZone.amritsar ? '$clock IST' : clock;
  }
}
