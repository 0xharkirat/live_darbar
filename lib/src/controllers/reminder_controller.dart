import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/locale_controller.dart';
import 'package:live_darbar/src/models/reminder_settings.dart';
import 'package:live_darbar/src/models/reminder_time.dart';
import 'package:live_darbar/src/services/reminder_platform.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The daily Hukamnama reminder: whether it is on, at what time, and whether
/// the app has asked yet.
///
/// There is no server and no push. The phone keeps one repeating local
/// notification, and this controller sets it, changes it and removes it.
///
/// The app asks once. [ReminderSettings.asked] is set when the question
/// appears (see `showReminderPromptIfNeeded`). "Not now", a swipe away and a
/// "Remind me" that the phone refused all leave it set, so the question never
/// comes back. After that the listener decides on the About screen.
class ReminderController extends AsyncNotifier<ReminderSettings> {
  static const askedKey = 'reminder_asked';
  static const enabledKey = 'reminder_enabled';
  static const minutesKey = 'reminder_minutes';

  ReminderPlatform get _platform => ref.read(reminderPlatformProvider);

  @override
  Future<ReminderSettings> build() async {
    // A repeating notification keeps the words it was set with, so a change
    // of language needs a new schedule. The saved language arrives a moment
    // after launch, and this covers that too.
    ref.listen<String>(localeController, (previous, next) {
      if (previous != next) unawaited(resync());
    });

    final prefs = await SharedPreferences.getInstance();
    return ReminderSettings(
      asked: prefs.getBool(askedKey) ?? false,
      enabled: prefs.getBool(enabledKey) ?? false,
      time: ReminderTime.tryFromMinutes(prefs.getInt(minutesKey)) ??
          ReminderTime.standard,
    );
  }

  /// Gets the phone ready, sends each tap on the reminder to [onOpen], and
  /// brings the schedule up to date. Run once when the app starts.
  ///
  /// [onOpen] also runs once when a tap on the reminder started the app from
  /// closed. That is not a callback from the phone: the app must ask.
  Future<void> start(VoidCallback onOpen) async {
    if (!_platform.isSupported) return;
    try {
      await _platform.start(onOpen);
      await resync();
      if (await _platform.openedByReminder()) onOpen();
    } catch (e) {
      debugPrint('[reminder] start failed: $e');
    }
  }

  /// Records that the question has been shown. See [ReminderSettings.asked].
  Future<void> markAsked() => _serial(() async {
        final current = await future;
        if (current.asked) return;
        await _save(current.copyWith(asked: true));
      });

  /// The listener said yes. Asks the phone for permission, which is the first
  /// time it hears of the reminder, then sets the schedule.
  ///
  /// Returns [ReminderProblem.none] when the reminder is on.
  Future<ReminderProblem> turnOn() => _serial(() async {
        final current = await future;
        var problem = ReminderProblem.none;
        try {
          if (!await _platform.requestPermission()) {
            problem = ReminderProblem.blocked;
          } else {
            await _platform.schedule(current.time, _text());
          }
        } catch (e) {
          debugPrint('[reminder] could not turn on: $e');
          problem = ReminderProblem.failed;
        }
        await _save(
          current.copyWith(
            asked: true,
            enabled: problem == ReminderProblem.none,
            problem: problem,
          ),
        );
        return problem;
      });

  Future<void> turnOff() => _serial(() async {
        final current = await future;
        try {
          await _platform.cancel();
        } catch (e) {
          // The switch still goes off. The plugin's cancel only removes an
          // alarm and its own record, so there is nothing for the listener
          // to retry.
          debugPrint('[reminder] could not cancel: $e');
        }
        await _save(
          current.copyWith(
            asked: true,
            enabled: false,
            problem: ReminderProblem.none,
          ),
        );
      });

  Future<void> setTime(ReminderTime time) => _serial(() async {
        final current = await future;
        if (time == current.time) return;
        var problem = current.problem;
        if (current.enabled) {
          try {
            await _platform.schedule(time, _text());
            problem = ReminderProblem.none;
          } catch (e) {
            debugPrint('[reminder] could not change the time: $e');
            problem = ReminderProblem.failed;
          }
        }
        await _save(current.copyWith(time: time, problem: problem));
      });

  /// Sets the schedule again from the saved choice, and checks that the phone
  /// still lets the app show notifications.
  ///
  /// Run at launch, on return to the app, and when the language changes. That
  /// also fixes the time after a trip: the phone keeps the schedule in the
  /// zone it was set in, and this sets it in the zone the phone is in now.
  Future<void> resync() => _serial(() async {
        final current = await future;
        if (!_platform.isSupported || !current.enabled) return;
        try {
          final allowed = await _platform.hasPermission();
          await _platform.schedule(current.time, _text());
          state = AsyncData(
            current.copyWith(
              problem: allowed ? ReminderProblem.none : ReminderProblem.blocked,
            ),
          );
        } catch (e) {
          debugPrint('[reminder] could not sync: $e');
          state = AsyncData(current.copyWith(problem: ReminderProblem.failed));
        }
      });

  /// The end of the last job. Each job waits for it, so the jobs run one at a
  /// time, in the order they were asked for.
  ///
  /// They all read the settings, wait on the phone, and write the settings
  /// back. The phone's answers can come in any order: the return of the app
  /// from the phone's permission question starts a sync at the same moment
  /// that "Remind me" finishes. Run together, a sync that had read "off"
  /// could remove the reminder that "Remind me" had just set.
  Future<void> _tail = Future<void>.value();

  Future<T> _serial<T>(Future<T> Function() job) {
    final result = _tail.then((_) => job());
    _tail = result.then((_) {}, onError: (_) {});
    return result;
  }

  ReminderText _text() {
    final l10n = lookupAppLocalizations(Locale(ref.read(localeController)));
    return ReminderText(
      title: l10n.reminder_notification_title,
      body: l10n.reminder_notification_body,
      channelName: l10n.reminder_channel_name,
      channelDescription: l10n.reminder_channel_description,
    );
  }

  Future<void> _save(ReminderSettings next) async {
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(askedKey, next.asked);
    await prefs.setBool(enabledKey, next.enabled);
    await prefs.setInt(minutesKey, next.time.minutes);
  }
}

final reminderProvider =
    AsyncNotifierProvider<ReminderController, ReminderSettings>(
  ReminderController.new,
);
