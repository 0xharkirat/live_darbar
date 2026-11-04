import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/sikh_history_controller.dart';
import 'package:live_darbar/src/models/reminder_settings.dart';
import 'package:live_darbar/src/views/widgets/setting_switch_row.dart';

/// The "Today in Sikh history" notification, on the About screen: 1 switch,
/// off until the listener turns it on.
///
/// The events show on the home screen whatever this says. The switch only
/// decides whether the phone also tells the listener, at the time of the daily
/// reminder. It sits under the reminder, and the About screen shows it only
/// where the platform can notify (see `ReminderPlatform`).
///
/// Turning it on is the first time the app asks the phone for permission, if
/// the daily reminder has not asked already. When the phone says no, the
/// switch stays off and a message says what to do.
class HistorySetting extends ConsumerWidget {
  const HistorySetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(sikhHistoryProvider).value;
    final enabled = settings?.enabled ?? false;
    final problem = settings?.problem ?? ReminderProblem.none;

    final hint = switch (problem) {
      ReminderProblem.none => null,
      ReminderProblem.blocked => l10n.reminder_blocked_hint,
      ReminderProblem.failed => l10n.history_failed_hint,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingSwitchRow(
          icon: CupertinoIcons.calendar,
          label: l10n.history_title,
          detail: l10n.history_setting_detail,
          value: enabled,
          valueLabel: enabled ? l10n.reminder_on : l10n.reminder_off,
          // Until the saved choice has loaded, there is nothing to change.
          onTap: settings == null ? null : () => _toggle(ref, !enabled),
        ),
        if (hint != null)
          SettingHint(text: hint, isError: problem == ReminderProblem.failed),
      ],
    );
  }

  Future<void> _toggle(WidgetRef ref, bool on) {
    final controller = ref.read(sikhHistoryProvider.notifier);
    return on ? controller.turnOn() : controller.turnOff();
  }
}
