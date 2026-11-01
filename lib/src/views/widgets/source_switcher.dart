import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:live_darbar/src/controllers/now_playing_controller.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/motion.dart';
import 'package:live_darbar/src/core/palette.dart';

/// Switch between the three sources without leaving the player.
///
/// A segmented control rather than a list, because there are exactly three
/// things and they are siblings. The gold thumb slides to the new choice, so
/// the eye follows the change instead of hunting for it.
class SourceSwitcher extends ConsumerWidget {
  const SourceSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final current = ref.watch(nowPlayingProvider.select((n) => n.index));
    // Short names: three of them have to fit one row on a small phone.
    final labels = [l10n.live, l10n.mukhwak, l10n.katha];
    const indices = [kLiveIndex, kMukhwakIndex, kKathaIndex];
    final selected = indices.indexOf(current).clamp(0, 2);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Inside the 3 px padding on each side.
        final segment = (constraints.maxWidth - 6) / 3;
        return Container(
          height: 44,
          padding: const EdgeInsets.all(3),
          decoration: ShapeDecoration(
            color: Palette.surface,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Palette.border),
            ),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: Motion.standard,
                curve: Motion.easeInOut,
                left: selected * segment,
                top: 0,
                bottom: 0,
                width: segment,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: Palette.surfaceHigh,
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(11),
                      side: const BorderSide(color: Palette.border),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < 3; i++)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: i == selected,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (i == selected) return;
                            HapticFeedback.selectionClick();
                            ref.read(audioController).play(indices[i]);
                          },
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: Motion.quick,
                              style: AppType.footnote.copyWith(
                                color: i == selected
                                    ? Palette.foreground
                                    : Palette.muted,
                                fontWeight: i == selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                              child: Text(
                                labels[i],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
