import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/locale_controller.dart';
import 'package:live_darbar/src/controllers/update_controller.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/open_link.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/models/app_update.dart';
import 'package:live_darbar/src/views/widgets/app_sheet.dart';
import 'package:live_darbar/src/views/widgets/pressable.dart';
import 'package:live_darbar/src/views/widgets/sheet_parts.dart';

/// Offers a newer release, once, as a sheet the listener can wave away.
///
/// A forced update ([AppUpdate.forced]: the installed build is below the
/// manifest's `minBuild`) is the other case. The sheet cannot be waved away: a
/// tap on the dim, a swipe and the back button do nothing, and it has 1 button,
/// which goes to the store. It keeps its place when the store opens, so the
/// listener who comes back without updating meets it again. It asks at every
/// launch, whatever was declined. The audio keeps playing: only the screen is
/// held.
///
/// A sheet rather than a dialog: it never blocks the kirtan that may already
/// be playing, and a downward swipe dismisses it like any other sheet.
///
/// Every way out saves the answer: both buttons, a swipe down, a tap on the
/// dim, and the back gesture. The answer is saved here, after the sheet
/// closes, and not in each button. When only the buttons saved it, a swipe
/// left the release unanswered, and the sheet came back at every launch.
Future<void> showUpdateSheet(BuildContext context, AppUpdate update) async {
  final updates = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(updateController.notifier);
  await showAppSheet<void>(
    context,
    (_) => _UpdateSheet(update: update),
    // A forced update stays until the listener has updated. See
    // [AppUpdate.forced].
    dismissible: !update.forced,
  );
  if (!update.forced) await updates.dismiss();
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
        // Not at the bottom: the space for the navigation bar is inside the
        // scroll view (see [sheetPadding]), so a line slides under the bar.
        bottom: false,
        // Scrolls when it does not fit: on a 360 x 640 phone, common among
        // low-cost Android phones, this sheet is taller than the screen.
        child: SingleChildScrollView(
          // Hands a swipe down at the top of the list to the sheet.
          controller: appSheetScrollController(context),
          child: Padding(
            padding: sheetPadding(context),
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
                Text(
                  update.forced
                      ? l10n.update_required_title
                      : l10n.update_available,
                  style: AppType.title2,
                ),
                const SizedBox(height: 4),
                if (update.forced) ...[
                  Text(l10n.update_required_body, style: AppType.callout),
                  const SizedBox(height: 4),
                ],
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
                    // A forced sheet stays. The store opens over the app.
                    if (!update.forced) Navigator.of(context).pop();
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
                if (!update.forced) ...[
                  const SizedBox(height: 4),
                  CupertinoButton(
                    minimumSize: const Size(44, 48),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      l10n.update_later,
                      style: AppType.callout.copyWith(color: Palette.muted),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
