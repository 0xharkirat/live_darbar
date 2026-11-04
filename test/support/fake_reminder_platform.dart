import 'package:flutter/foundation.dart';
import 'package:live_darbar/src/core/history_schedule.dart';
import 'package:live_darbar/src/models/reminder_time.dart';
import 'package:live_darbar/src/services/reminder_platform.dart';

/// Stands in for the phone behind the daily reminder and "Today in Sikh
/// history", and records what the app asks of it.
class FakeReminderPlatform implements ReminderPlatform {
  FakeReminderPlatform({
    this.supported = true,
    this.allowed = true,
    this.launchedByReminder = false,
  });

  bool supported;

  /// What the phone answers when asked, and when checked.
  bool allowed;

  /// What `openedByReminder` answers.
  bool launchedByReminder;

  /// Set to make [schedule] fail, as a phone can.
  Object? scheduleError;

  /// Set to make [scheduleHistory] fail, as a phone can.
  Object? historyError;

  /// Each call, in order: `start`, `request`, `has`, `schedule 07:00`,
  /// `cancel`, `launch`, `history 07:00 x3` and `cancelHistory`.
  final calls = <String>[];

  /// "Today in Sikh history" as it stands: null when none is set.
  List<HistoryNotice>? history;
  ReminderTime? historyTime;
  HistoryText? historyText;

  /// The reminder as it stands: null when none is set.
  ReminderTime? scheduled;
  ReminderText? text;
  VoidCallback? onTap;

  int get scheduleCount => calls.where((c) => c.startsWith('schedule')).length;

  @override
  bool get isSupported => supported;

  @override
  Future<void> start(VoidCallback onTap) async {
    calls.add('start');
    this.onTap = onTap;
  }

  @override
  Future<bool> requestPermission() async {
    calls.add('request');
    return allowed;
  }

  @override
  Future<bool> hasPermission() async {
    calls.add('has');
    return allowed;
  }

  @override
  Future<void> schedule(ReminderTime time, ReminderText text) async {
    calls.add('schedule $time');
    final error = scheduleError;
    if (error != null) throw error;
    scheduled = time;
    this.text = text;
  }

  @override
  Future<void> cancel() async {
    calls.add('cancel');
    scheduled = null;
  }

  @override
  Future<void> scheduleHistory(
    ReminderTime time,
    List<HistoryNotice> notices,
    HistoryText text,
  ) async {
    calls.add('history $time x${notices.length}');
    final error = historyError;
    if (error != null) throw error;
    history = notices;
    historyTime = time;
    historyText = text;
  }

  @override
  Future<void> cancelHistory() async {
    calls.add('cancelHistory');
    history = null;
  }

  @override
  Future<bool> openedByReminder() async {
    calls.add('launch');
    return launchedByReminder;
  }
}
