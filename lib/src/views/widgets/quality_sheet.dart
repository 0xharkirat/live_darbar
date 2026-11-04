import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/quality_mode_controller.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/motion.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/models/quality_policy.dart';
import 'package:live_darbar/src/views/widgets/app_sheet.dart';
import 'package:live_darbar/src/views/widgets/pressable.dart';
import 'package:live_darbar/src/views/widgets/sheet_parts.dart';

/// The smallest tap target: 48 points, Android's minimum. Apple's is 44, and
/// the app ships on Android first, so the larger one wins.
const _minTarget = 48.0;

/// A small capsule that opens the quality choice: a waveform and the words
/// "Sound quality".
///
/// Sound quality is a setting to set once, not a control to reach for while
/// listening, so it stays quiet: muted, on the surface colour, at 32 points.
/// A sliders icon alone said "settings" or "filters", and the listener who
/// most needs it, the one saving data, had no cue. A waveform with a word
/// says what it changes. The target is 48 points high, larger than the
/// capsule, and the screen reader says "Sound quality, Automatic", with the
/// current mode. [DataSaverPill] shows the one mode worth seeing at a glance.
class QualityButton extends ConsumerWidget {
  const QualityButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final mode = ref.watch(qualityModeProvider);

    return Pressable(
      // 0.95, not the default 0.97: the capsule is small, so the fill below
      // does most of the work and the scale only has to be seen.
      scale: 0.95,
      semanticLabel: l10n.quality,
      semanticValue: _name(l10n, mode),
      onTap: () => showQualitySheet(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: _minTarget,
          minHeight: _minTarget,
        ),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: ExcludeSemantics(
            child: PressFill(
              color: Palette.surface,
              pressedColor: Palette.surfaceHigh,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Palette.border),
              ),
              child: SizedBox(
                height: 32,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        CupertinoIcons.waveform,
                        size: 16,
                        color: Palette.muted,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          l10n.quality,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.footnote,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Data saver" in a small pill, beside the LIVE badge, and nothing in any
/// other mode.
///
/// Data saver is the one setting that changes what the listener hears, so it
/// stays in view when the button beside it only names the setting.
///
/// It looks like a chip, so it acts like one: a tap opens the same sheet as
/// [QualityButton]. It has a fixed [height] that the player's badge row also
/// uses, so the row is the same height with the pill and without it.
class DataSaverPill extends ConsumerWidget {
  const DataSaverPill({super.key});

  /// The height of the pill, and so of the row it sits in.
  static const height = 28.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(qualityModeProvider) == QualityMode.dataSaver;

    // No fade: the only way to change the mode is the sheet, which keeps a
    // scrim over the player, so a fade would play where nobody sees it. And
    // when the player opens, the pill is already there.
    if (!active) return const SizedBox.shrink();

    return Pressable(
      onTap: () => showQualitySheet(context),
      child: PressFill(
        color: Palette.surface,
        pressedColor: Palette.surfaceHigh,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Center(
              widthFactor: 1,
              child: Text(
                AppLocalizations.of(context)!.quality_data_saver,
                style: AppType.footnote.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Palette.gold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showQualitySheet(BuildContext context) {
  return showAppSheet<void>(context, (_) => const _QualitySheet());
}

/// DESIGN.md: 20 for cards and tiles. The group of rows is a tile.
const _groupRadius = 20.0;

/// A row held down: a hairline colour over the group's fill.
final _rowPressed = Palette.border.withValues(alpha: 0.6);

String _name(AppLocalizations l10n, QualityMode mode) => switch (mode) {
      QualityMode.automatic => l10n.quality_automatic,
      QualityMode.high => l10n.quality_high,
      QualityMode.dataSaver => l10n.quality_data_saver,
    };

/// Three choices and one paragraph, nothing more. Each row says what it
/// costs in data per hour, because megabytes are the unit someone on a
/// metered plan can act on.
class _QualitySheet extends ConsumerWidget {
  const _QualitySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final current = ref.watch(qualityModeProvider);

    Widget row(QualityMode mode, String detail) {
      final selected = mode == current;
      return Pressable(
        // No scale: 0.99 moves the text 1 to 2 points, and the row has no
        // edge to show it. The fill is the feedback.
        scale: 1,
        // The name and the cost read as one phrase, and the gold check is
        // heard as "selected".
        semanticLabel: '${_name(l10n, mode)}, $detail',
        selected: selected,
        inMutuallyExclusiveGroup: true,
        onTap: () {
          HapticFeedback.selectionClick();
          ref.read(qualityModeProvider.notifier).set(mode);
        },
        child: ExcludeSemantics(
          child: PressFill(
            pressedColor: _rowPressed,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_name(l10n, mode), style: AppType.headline),
                        const SizedBox(height: 2),
                        Text(detail, style: AppType.footnote),
                      ],
                    ),
                  ),
                  AnimatedOpacity(
                    duration: Motion.quick,
                    opacity: selected ? 1 : 0,
                    child: const Icon(
                      CupertinoIcons.checkmark_alt,
                      color: Palette.gold,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

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
            padding: sheetPadding(context, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Palette.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Text(l10n.quality, style: AppType.title2),
                const SizedBox(height: 16),
                DecoratedBox(
                  decoration: ShapeDecoration(
                    color: Palette.surfaceHigh,
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(_groupRadius),
                    ),
                  ),
                  // The pressed fill is a plain rectangle, so the group clips
                  // it: the first and last row keep the rounded corners.
                  child: ClipRSuperellipse(
                    borderRadius: BorderRadius.circular(_groupRadius),
                    child: Column(
                      children: [
                        row(QualityMode.automatic,
                            l10n.quality_automatic_detail),
                        const Divider(
                            height: 1, color: Palette.border, indent: 16),
                        row(QualityMode.high, l10n.quality_high_detail),
                        const Divider(
                            height: 1, color: Palette.border, indent: 16),
                        row(QualityMode.dataSaver,
                            l10n.quality_data_saver_detail),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(l10n.quality_note, style: AppType.footnote),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
