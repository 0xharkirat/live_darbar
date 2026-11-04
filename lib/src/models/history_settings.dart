import 'package:flutter/foundation.dart';
import 'package:live_darbar/src/models/reminder_settings.dart';

/// What the listener chose for the "Today in Sikh history" notification.
///
/// It is off until the listener turns it on in About. It has no time of its
/// own: it follows the time of the daily reminder.
@immutable
class HistorySettings {
  const HistorySettings({
    this.enabled = false,
    this.problem = ReminderProblem.none,
  });

  /// Whether the listener wants the notification.
  final bool enabled;

  /// Why it is not working, when the listener turned it on. Held in memory
  /// only, like [ReminderSettings.problem].
  final ReminderProblem problem;

  @override
  bool operator ==(Object other) =>
      other is HistorySettings &&
      other.enabled == enabled &&
      other.problem == problem;

  @override
  int get hashCode => Object.hash(enabled, problem);
}
