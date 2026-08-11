import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/locale_controller.dart';
import 'package:live_darbar/src/controllers/update_controller.dart';
import 'package:live_darbar/src/models/app_update.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// Offers a newer release, once, and takes no for an answer.
///
/// Sized and worded for the people who actually use this app, who are mostly
/// older and not especially technical. That drives most of the decisions here:
/// body text at 16 rather than the theme's small sizes, two full-width buttons
/// far enough apart to be hard to mis-tap, plain words instead of "changelog"
/// or "release notes", and no jargon about versions beyond the number itself.
///
/// It is a sheet rather than a dialog, and dismissible, because nothing here
/// is urgent. If a release ever genuinely must be forced, that is a different
/// component with a different contract, not a flag on this one.
Future<void> showUpdateSheet(BuildContext context, AppUpdate update) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // Tapping outside counts as "not now", same as the button, so the sheet
    // never traps anyone who does not understand what it is asking.
    builder: (_) => _UpdateSheet(update: update),
  );
}

class _UpdateSheet extends ConsumerWidget {
  const _UpdateSheet({required this.update});

  final AppUpdate update;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = ShadTheme.of(context);
    final notes = update.notesFor(ref.watch(localeController));

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.muted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Icon(
                LucideIcons.arrowBigUpDash,
                size: 40,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.update_available,
                textAlign: TextAlign.center,
                style: theme.textTheme.h3,
              ),
              const SizedBox(height: 4),
              Text(
                l10n.update_version(update.version),
                textAlign: TextAlign.center,
                style: theme.textTheme.muted,
              ),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 20),
                for (final note in notes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 6, right: 10),
                          child: Icon(
                            LucideIcons.check,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            note,
                            style: theme.textTheme.p.copyWith(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 24),
              ShadButton(
                size: ShadButtonSize.lg,
                onPressed: () async {
                  Navigator.of(context).pop();
                  await ref.read(updateController.notifier).dismiss();
                  await launchUrl(
                    Uri.parse(update.storeUrl),
                    mode: LaunchMode.externalApplication,
                  );
                },
                child: Text(l10n.update_now),
              ),
              const SizedBox(height: 8),
              ShadButton.ghost(
                size: ShadButtonSize.lg,
                onPressed: () {
                  Navigator.of(context).pop();
                  ref.read(updateController.notifier).dismiss();
                },
                child: Text(l10n.update_later),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
