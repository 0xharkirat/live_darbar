import 'package:flutter/foundation.dart';

/// The time of day the reminder fires, on the listener's own clock.
///
/// It is a wall-clock time, not an instant: "7:00" stays 7:00 when the clocks
/// change. The phone repeats it each day from that.
@immutable
class ReminderTime {
  const ReminderTime(this.hour, this.minute)
      : assert(hour >= 0 && hour < 24),
        assert(minute >= 0 && minute < 60);

  /// What the reminder starts at: the hour of Amritvela, for a listener who
  /// wants the Hukamnama with the first light of the day.
  static const standard = ReminderTime(7, 0);

  final int hour;
  final int minute;

  /// Minutes since midnight. This is how the time is stored.
  int get minutes => hour * 60 + minute;

  /// The time stored as [minutes], or null for a value that is not a time of
  /// day, so a damaged setting falls back to [standard] instead of throwing.
  static ReminderTime? tryFromMinutes(int? minutes) {
    if (minutes == null || minutes < 0 || minutes >= 24 * 60) return null;
    return ReminderTime(minutes ~/ 60, minutes % 60);
  }

  @override
  bool operator ==(Object other) =>
      other is ReminderTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
