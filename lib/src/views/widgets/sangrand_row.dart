import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/locale_controller.dart';
import 'package:live_darbar/src/controllers/sangrand_controller.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/motion.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/views/app_router.dart';
import 'package:live_darbar/src/views/widgets/pressable.dart';

/// The Home row for the Sangrand Hukamnama: "SANGRAND · KATAK", then the
/// first line of the month's pauri. On Sangrand day itself it says so. A tap
/// opens the page ([AppRoutes.sangrand]).
///
/// It has the shape of the Sikh history line at the top of Home: a gold rule
/// on the left, a small label, 2 lines at most. Nothing shows until the Sikh
/// date and Barah Maha are known.
class SangrandRow extends ConsumerWidget {
  const SangrandRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sangrand = ref.watch(sangrandProvider).value;
    return AnimatedSize(
      duration: Motion.quick,
      curve: Motion.easeOut,
      alignment: Alignment.topCenter,
      child: sangrand == null
          ? const SizedBox(width: double.infinity)
          : _row(context, ref, sangrand),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, Sangrand s) {
    final l10n = AppLocalizations.of(context)!;
    final punjabi = ref.watch(localeController) == 'pa';
    final month = punjabi ? s.date.monthGurmukhi : s.date.monthEnglish;
    final lead =
        s.isToday ? l10n.sangrand_row_today(month) : l10n.sangrand_row(month);
    // English capitals, Gurmukhi as it is.
    final label = punjabi ? lead : lead.toUpperCase();
    final line = s.lines.first.gurmukhi;

    final type = AppType.callout;
    final twoLines =
        MediaQuery.textScalerOf(context).scale(type.fontSize! * type.height!) *
            2;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Pressable(
        scale: 0.99,
        semanticLabel: '${l10n.sangrand_title}, $month: $line',
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.sangrand),
        child: ExcludeSemantics(
          child: Container(
            // A target of 44 points or more, though the line is small.
            constraints: BoxConstraints(minHeight: math.max(44, twoLines + 12)),
            padding: const EdgeInsets.only(left: 10),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: Palette.gold.withValues(alpha: s.isToday ? 1 : 0.5),
                  width: 2,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: label, style: AppType.eyebrow),
                          const TextSpan(text: '  '),
                          TextSpan(text: line),
                        ],
                      ),
                      style: type,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  CupertinoIcons.chevron_right,
                  size: 15,
                  color: Palette.faint,
                ),
                const SizedBox(width: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
