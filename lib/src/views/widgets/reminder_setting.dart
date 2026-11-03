import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/reminder_controller.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/motion.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/models/reminder_settings.dart';
import 'package:live_darbar/src/models/reminder_time.dart';
import 'package:live_darbar/src/views/widgets/pressable.dart';
import 'package:live_darbar/src/views/widgets/reminder_sheet.dart';

/// The daily reminder, on the About screen: a switch, and under it, only while
/// it is on, the time.
///
/// It is made to sit inside the About screen's grouped list, where a row has
/// an icon, a label and a hairline indented to the text. The About screen
/// shows it only where the platform can remind (see `ReminderPlatform`).
///
/// The whole switch row is one target. Under it, a message says what to do
/// when the phone does not let the app show notifications, because a switch
/// that turns on and then does nothing would be worse than none.
class ReminderSetting extends ConsumerWidget {
  const ReminderSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(reminderProvider).value;
    final enabled = settings?.enabled ?? false;
    final time = settings?.time ?? ReminderTime.standard;
    final problem = settings?.problem ?? ReminderProblem.none;

    final hint = switch (problem) {
      ReminderProblem.none => null,
      ReminderProblem.blocked => l10n.reminder_blocked_hint,
      ReminderProblem.failed => l10n.reminder_failed_hint,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Pressable(
          scale: 1,
          semanticLabel: l10n.reminder_setting,
          semanticValue: enabled ? l10n.reminder_on : l10n.reminder_off,
          // Until the saved choice has loaded, there is nothing to change.
          onTap: settings == null ? null : () => _toggle(ref, !enabled),
          child: PressFill(
            pressedColor: Palette.surfaceHigh,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: ExcludeSemantics(
                  child: Row(
                    children: [
                      const Icon(
                        CupertinoIcons.bell,
                        size: 20,
                        color: Palette.gold,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(l10n.reminder_setting, style: AppType.body),
                      ),
                      // The row takes the tap, so the switch only shows it.
                      IgnorePointer(
                        child: CupertinoSwitch(
                          value: enabled,
                          onChanged: (_) {},
                          activeTrackColor: Palette.gold,
                          inactiveTrackColor: Palette.border,
                          thumbColor: Palette.foreground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          // Reduce Motion: Flutter runs this at 5% of its length.
          duration: Motion.quick,
          curve: Motion.easeOut,
          alignment: Alignment.topCenter,
          child: enabled
              ? _TimeRow(time: time)
              : const SizedBox(width: double.infinity),
        ),
        if (hint != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(52, 2, 16, 14),
            child: Text(
              hint,
              style: AppType.footnote.copyWith(
                color: problem == ReminderProblem.failed
                    ? Palette.danger
                    : Palette.muted,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _toggle(WidgetRef ref, bool on) {
    final controller = ref.read(reminderProvider.notifier);
    return on ? controller.turnOn() : controller.turnOff();
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({required this.time});

  final ReminderTime time;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = reminderTimeLabel(context, time);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 52),
          child: Divider(height: 1, thickness: 1, color: Palette.border),
        ),
        Pressable(
          scale: 1,
          semanticLabel: l10n.reminder_time,
          semanticValue: label,
          onTap: () => showReminderTimeSheet(context),
          child: PressFill(
            pressedColor: Palette.surfaceHigh,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: ExcludeSemantics(
                  child: Row(
                    children: [
                      const Icon(
                        CupertinoIcons.clock,
                        size: 20,
                        color: Palette.gold,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(l10n.reminder_time, style: AppType.body),
                      ),
                      Text(
                        label,
                        style: AppType.body.copyWith(color: Palette.muted),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        CupertinoIcons.chevron_forward,
                        size: 15,
                        color: Palette.faint,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
