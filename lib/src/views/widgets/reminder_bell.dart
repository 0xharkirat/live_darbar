import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/reminder_controller.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/services/reminder_platform.dart';
import 'package:live_darbar/src/views/widgets/reminder_sheet.dart';

/// The bell in the top bar of the Hukamnama reader: the always-there way to
/// set up the daily reminder, or to change it.
///
/// It opens the reminder's sheet (`showReminderPrompt`). A filled bell means
/// the reminder is on. A phone that cannot remind, such as the web, has no
/// bell. It is a small icon, so it stays out of the way of the words, and it
/// is a 44 point target like the text size controls beside it.
class ReminderBell extends ConsumerWidget {
  const ReminderBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(reminderPlatformProvider).isSupported) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final on = ref.watch(
      reminderProvider.select((settings) => settings.value?.enabled ?? false),
    );

    return Semantics(
      button: true,
      label: l10n.reminder_setting,
      value: on ? l10n.reminder_on : l10n.reminder_off,
      excludeSemantics: true,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(44, 44),
        onPressed: () => showReminderPrompt(context),
        child: Icon(
          on ? CupertinoIcons.bell_fill : CupertinoIcons.bell,
          size: 22,
          color: Palette.gold,
        ),
      ),
    );
  }
}
