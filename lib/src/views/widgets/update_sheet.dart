import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/locale_controller.dart';
import 'package:live_darbar/src/controllers/update_controller.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/open_link.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/models/app_update.dart';
import 'package:live_darbar/src/views/widgets/pressable.dart';

/// Offers a newer release, once, as a sheet the listener can wave away.
///
/// A sheet rather than a dialog: it never blocks the kirtan that may already
/// be playing, and a downward swipe dismisses it like any other sheet.
Future<void> showUpdateSheet(BuildContext context, AppUpdate update) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _UpdateSheet(update: update),
  );
}

class _UpdateSheet extends ConsumerWidget {
  const _UpdateSheet({required this.update});

  final AppUpdate update;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final notes = update.notesFor(ref.watch(localeController));

    return Container(
      decoration: const ShapeDecoration(
        color: Palette.surface,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          side: BorderSide(color: Palette.border),
        ),
      ),
      child: SafeArea(
        top: false,
        // Scrolls when it does not fit: on a 360 x 640 phone, common among
        // low-cost Android phones, this sheet is taller than the screen.
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Palette.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Text(l10n.update_available, style: AppType.title2),
                const SizedBox(height: 4),
                Text(l10n.update_version(update.version),
                    style: AppType.callout),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  for (final note in notes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 4, right: 12),
                            child: Icon(
                              CupertinoIcons.checkmark_alt,
                              size: 16,
                              color: Palette.gold,
                            ),
                          ),
                          Expanded(child: Text(note, style: AppType.body)),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 20),
                Pressable(
                  semanticLabel: l10n.update_now,
                  onTap: () async {
                    Navigator.of(context).pop();
                    await ref.read(updateController.notifier).dismiss();
                    await openLink(update.storeUrl);
                  },
                  child: Container(
                    height: 54,
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      color: Palette.gold,
                      shape: RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      l10n.update_now,
                      style: AppType.headline.copyWith(color: Palette.onGold),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                CupertinoButton(
                  minimumSize: const Size(44, 48),
                  onPressed: () {
                    Navigator.of(context).pop();
                    ref.read(updateController.notifier).dismiss();
                  },
                  child: Text(
                    l10n.update_later,
                    style: AppType.callout.copyWith(color: Palette.muted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
