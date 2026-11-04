import 'package:flutter/foundation.dart';
import 'package:live_darbar/src/models/reminder_time.dart';
import 'package:live_darbar/src/services/reminder_platform.dart';

/// Stands in for the phone behind the daily reminder, and records what the app
/// asks of it.
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

  /// Each call, in order: `start`, `request`, `has`, `schedule 07:00`,
  /// `cancel`, `launch`.
  final calls = <String>[];

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
  Future<bool> openedByReminder() async {
    calls.add('launch');
    return launchedByReminder;
  }
}
