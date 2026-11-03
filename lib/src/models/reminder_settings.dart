import 'package:flutter/foundation.dart';
import 'package:live_darbar/src/models/reminder_time.dart';

/// Why the reminder is not working, when the listener turned it on.
///
/// Held in memory only. It describes the phone right now, so the next launch
/// finds out again.
enum ReminderProblem {
  none,

  /// The phone does not let the app show notifications. Only the listener can
  /// change that, in the phone's settings.
  blocked,

  /// The phone refused to set the reminder for another reason.
  failed,
}

/// What the listener chose for the daily Hukamnama reminder.
@immutable
class ReminderSettings {
  const ReminderSettings({
    this.asked = false,
    this.enabled = false,
    this.time = ReminderTime.standard,
    this.problem = ReminderProblem.none,
  });

  /// Whether the app has shown the first question. It is set when the question
  /// appears, not when it is answered, so the app asks once whatever the
  /// answer, and a swipe away counts as "not now".
  final bool asked;

  /// Whether the listener wants the reminder.
  final bool enabled;

  final ReminderTime time;
  final ReminderProblem problem;

  ReminderSettings copyWith({
    bool? asked,
    bool? enabled,
    ReminderTime? time,
    ReminderProblem? problem,
  }) =>
      ReminderSettings(
        asked: asked ?? this.asked,
        enabled: enabled ?? this.enabled,
        time: time ?? this.time,
        problem: problem ?? this.problem,
      );

  @override
  bool operator ==(Object other) =>
      other is ReminderSettings &&
      other.asked == asked &&
      other.enabled == enabled &&
      other.time == time &&
      other.problem == problem;

  @override
  int get hashCode => Object.hash(asked, enabled, time, problem);
}
