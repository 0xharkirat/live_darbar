import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/locale_controller.dart';
import 'package:live_darbar/src/controllers/update_controller.dart';
import 'package:live_darbar/src/controllers/whats_new_controller.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/models/whats_new.dart';
import 'package:live_darbar/src/views/widgets/app_sheet.dart';
import 'package:live_darbar/src/views/widgets/reminder_sheet.dart';
import 'package:live_darbar/src/views/widgets/sheet_parts.dart';

/// Shows what is new, once, the first time the app opens after an update.
/// Returns whether the sheet was shown.
///
/// [context] is Home's. It follows the rules of the update offer and the
/// reminder question, which the listener meets at launch too:
///
/// - It never opens over another sheet or page. Home must be the top route and
///   at rest, and calm for [whatsNewSettleProvider]. A sheet that is open is
///   waited out, not skipped.
/// - The app is on screen. A tap on the home screen widget, the car or Siri
///   can start the app with no screen, and nothing opens then. The notes wait
///   for the first time the listener sees the app.
/// - The update offer comes first. It is a network check, so this waits for
///   it. A release that is on offer opens its own sheet, and this follows.
///
/// The release is marked seen when the sheet appears, so it shows once. It
/// gives up after [giveUpAfter], and the next launch tries again. A fresh
/// install and a release with no notes show nothing.
Future<bool> showWhatsNewOnFirstOpen(
  BuildContext context, {
  Duration poll = const Duration(milliseconds: 250),
  Duration giveUpAfter = const Duration(minutes: 2),
  Duration updateCheckLimit = const Duration(seconds: 8),
  bool Function()? isForeground,
  CancelAsk? cancel,
}) async {
  cancel ??= CancelAsk();
  final container = ProviderScope.containerOf(context, listen: false);
  final WhatsNew? notes;
  try {
    notes = await container.read(whatsNewController.future);
  } catch (_) {
    return false;
  }
  if (notes == null || !context.mounted || cancel.cancelled) return false;

  // The update offer opens its sheet when the check ends. Let it.
  try {
    await container
        .read(updateController.future)
        .timeout(updateCheckLimit);
  } catch (_) {}
  if (!context.mounted || cancel.cancelled) return false;

  final route = ModalRoute.of(context);
  final settle = container.read(whatsNewSettleProvider);

  bool ready() {
    if (!context.mounted || cancel!.cancelled) return false;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final foreground = isForeground?.call() ??
        (lifecycle == null || lifecycle == AppLifecycleState.resumed);
    return foreground &&
        (route?.isCurrent ?? true) &&
        (route?.animation?.isCompleted ?? true);
  }

  var calm = Duration.zero;
  for (var waited = Duration.zero;; waited += poll) {
    if (!context.mounted || cancel.cancelled || waited >= giveUpAfter) {
      return false;
    }
    if (!ready()) {
      calm = Duration.zero;
    } else if (calm >= settle) {
      break;
    } else {
      calm += poll;
    }
    await cancel.sleep(poll);
  }

  if (!context.mounted || cancel.cancelled) return false;
  await container.read(whatsNewController.notifier).markSeen();
  if (!context.mounted) return true;
  await showAppSheet<void>(context, (_) => WhatsNewSheet(notes: notes!));
  return true;
}

/// The sheet: the release, its new things, and one gold button.
class WhatsNewSheet extends ConsumerWidget {
  const WhatsNewSheet({super.key, required this.notes});

  final WhatsNew notes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeController);

    return SheetFrame(
      children: [
        Text(l10n.whats_new_title(notes.release), style: AppType.title2),
        const SizedBox(height: 20),
        for (final item in notes.items) ...[
          _Item(
            title: item.titleFor(locale),
            body: item.bodyFor(locale),
          ),
          const SizedBox(height: 16),
        ],
        const SizedBox(height: 4),
        GoldSheetButton(
          label: l10n.whats_new_done,
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.title, this.body});

  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 3, right: 12),
          child: Icon(CupertinoIcons.sparkles, size: 18, color: Palette.gold),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppType.headline),
              if (body != null) ...[
                const SizedBox(height: 2),
                Text(body!, style: AppType.callout),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
