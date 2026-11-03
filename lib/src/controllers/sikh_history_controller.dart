import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/locale_controller.dart';
import 'package:live_darbar/src/controllers/reminder_controller.dart';
import 'package:live_darbar/src/controllers/sgpc_events_controller.dart';
import 'package:live_darbar/src/core/clock.dart';
import 'package:live_darbar/src/core/history_schedule.dart';
import 'package:live_darbar/src/models/history_settings.dart';
import 'package:live_darbar/src/models/reminder_settings.dart';
import 'package:live_darbar/src/models/sgpc_day.dart';
import 'package:live_darbar/src/services/reminder_platform.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The "Today in Sikh history" notification: whether it is on, and the
/// schedule that goes with it.
///
/// The events always show on the home screen. This is only the notification,
/// and it is the listener's choice: off until they turn it on in About, and
/// never asked for by a sheet.
///
/// There is no server and no push. When it is on, the phone holds 1 quiet
/// notification for each of the next [kHistoryDays] days that has an event
/// (see [planHistory]), at the time of the daily reminder. The notifications
/// run out, so the app sets them again each time it opens, and when the
/// language or the reminder time changes.
///
/// It shares the phone's side with the daily reminder (`ReminderPlatform`),
/// and it never changes the reminder.
class SikhHistoryController extends AsyncNotifier<HistorySettings> {
  static const enabledKey = 'history_enabled';

  ReminderPlatform get _platform => ref.read(reminderPlatformProvider);

  @override
  Future<HistorySettings> build() async {
    // A notification keeps the words it was set with.
    ref.listen<String>(localeController, (previous, next) {
      if (previous != next) unawaited(resync());
    });
    // The notices follow the reminder's time. The first time arrives with the
    // saved choice, and the app syncs at launch anyway.
    ref.listen(reminderProvider.select((s) => s.value?.time), (previous, next) {
      if (previous != null && previous != next) unawaited(resync());
    });

    final prefs = await SharedPreferences.getInstance();
    return HistorySettings(enabled: prefs.getBool(enabledKey) ?? false);
  }

  /// The listener said yes. Asks the phone for permission, which is the first
  /// time it hears of the notification if the daily reminder is off, then sets
  /// the schedule.
  ///
  /// Returns [ReminderProblem.none] when the notification is on.
  Future<ReminderProblem> turnOn() => _serial(() async {
        await future;
        var problem = ReminderProblem.none;
        try {
          if (!await _platform.requestPermission()) {
            problem = ReminderProblem.blocked;
          } else {
            await _schedule();
          }
        } catch (e) {
          debugPrint('[sikh history] could not turn on: $e');
          problem = ReminderProblem.failed;
        }
        await _save(
          HistorySettings(
            enabled: problem == ReminderProblem.none,
            problem: problem,
          ),
        );
        return problem;
      });

  Future<void> turnOff() => _serial(() async {
        await future;
        try {
          await _platform.cancelHistory();
        } catch (e) {
          // The switch still goes off. There is nothing for the listener to
          // retry, and the next sync removes what is left.
          debugPrint('[sikh history] could not cancel: $e');
        }
        await _save(const HistorySettings());
      });

  /// Sets the schedule again from the saved choice, and checks that the phone
  /// still lets the app show notifications.
  ///
  /// Run at launch, on return to the app, and when the language or the
  /// reminder time changes. It does nothing while the notification is off.
  Future<void> resync() => _serial(() async {
        final current = await future;
        if (!_platform.isSupported || !current.enabled) return;
        try {
          final allowed = await _platform.hasPermission();
          await _schedule();
          state = AsyncData(
            HistorySettings(
              enabled: true,
              problem: allowed ? ReminderProblem.none : ReminderProblem.blocked,
            ),
          );
        } catch (e) {
          debugPrint('[sikh history] could not sync: $e');
          state = const AsyncData(
            HistorySettings(enabled: true, problem: ReminderProblem.failed),
          );
        }
      });

  /// The end of the last job. See `ReminderController` for why the jobs run
  /// one at a time, in the order they were asked for.
  Future<void> _tail = Future<void>.value();

  Future<T> _serial<T>(Future<T> Function() job) {
    final result = _tail.then((_) => job());
    _tail = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<void> _schedule() async {
    final time = (await ref.read(reminderProvider.future)).time;
    final table = await ref.read(sgpcEventsProvider.future);
    final locale = ref.read(localeController);
    final notices = planHistory(
      table: table,
      today: sgpcDayOf(ref.read(clockProvider)()),
      punjabi: locale == 'pa',
    );
    await _platform.scheduleHistory(time, notices, _text(locale));
  }

  HistoryText _text(String locale) {
    final l10n = lookupAppLocalizations(Locale(locale));
    return HistoryText(
      title: l10n.history_title,
      channelName: l10n.history_title,
      channelDescription: l10n.history_channel_description,
    );
  }

  Future<void> _save(HistorySettings next) async {
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(enabledKey, next.enabled);
  }
}

final sikhHistoryProvider =
    AsyncNotifierProvider<SikhHistoryController, HistorySettings>(
  SikhHistoryController.new,
);
