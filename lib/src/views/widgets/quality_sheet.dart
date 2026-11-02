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
import 'package:live_darbar/src/views/widgets/pressable.dart';

/// A small round button that opens the quality choice.
///
/// Icon only, and quiet: sound quality is a setting to set once, not a
/// control to reach for while listening. It has a 44 point target around a
/// 32 point circle, and the screen reader says "Sound quality". The current
/// setting is not named here. [DataSaverPill] shows the one state worth
/// seeing at a glance.
class QualityButton extends StatelessWidget {
  const QualityButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      semanticLabel: AppLocalizations.of(context)!.quality,
      onTap: () => showQualitySheet(context),
      child: const SizedBox.square(
        dimension: 44,
        child: Center(
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: Palette.surface,
              shape: CircleBorder(side: BorderSide(color: Palette.border)),
            ),
            child: SizedBox.square(
              dimension: 32,
              child: Icon(
                CupertinoIcons.slider_horizontal_3,
                size: 18,
                color: Palette.muted,
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
/// stays in view without a label on the button that opens the choice.
class DataSaverPill extends ConsumerWidget {
  const DataSaverPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(qualityModeProvider) == QualityMode.dataSaver;

    return AnimatedSwitcher(
      duration: Motion.quick,
      switchInCurve: Motion.easeOut,
      child: !active
          ? const SizedBox.shrink(key: ValueKey('off'))
          : DecoratedBox(
              key: const ValueKey('on'),
              decoration: ShapeDecoration(
                color: Palette.surface,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                child: Text(
                  AppLocalizations.of(context)!.quality_data_saver,
                  style: AppType.footnote.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Palette.gold,
                  ),
                ),
              ),
            ),
    );
  }
}

Future<void> showQualitySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _QualitySheet(),
  );
}

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
        scale: 0.99,
        semanticLabel: _name(l10n, mode),
        onTap: () {
          HapticFeedback.selectionClick();
          ref.read(qualityModeProvider.notifier).set(mode);
        },
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
        // Scrolls when it does not fit: on a 360 x 640 phone, common among
        // low-cost Android phones, this sheet is taller than the screen.
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
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
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Column(
                    children: [
                      row(QualityMode.automatic, l10n.quality_automatic_detail),
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
