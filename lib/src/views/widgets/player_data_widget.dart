import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:live_darbar/src/core/get_localized_title.dart';
import 'package:lottie/lottie.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class PlayerDataWidget extends ConsumerWidget {
  const PlayerDataWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sequenceStateAsync = ref.watch(sequenceStateProvider);

    final title = sequenceStateAsync.when<String>(
      data: (sequenceState) {
        // Extract current media item details as Source
        final source = sequenceState?.currentSource?.tag;

        // Fall back to default source if current source is null

        if (source == null) {
          return AppLocalizations.of(context)!.loading;
        }

        final title = source?.title;

        return getLocalizedTitle(title, context);
      },
      loading: () => AppLocalizations.of(context)!.loading,
      error: (error, _) => AppLocalizations.of(context)!.loading,
    );

    final playerStateAsync = ref.watch(playerStateProvider);

    final isPlaying = playerStateAsync.when<bool>(
      data: (playerState) =>
          playerState.playing &&
          playerState.processingState != ProcessingState.completed,
      loading: () => false,
      error: (error, _) => false,
    );

    return Row(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            bottomLeft: Radius.circular(16),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  color:
                      ShadTheme.of(context).colorScheme.card.withValues(alpha: 0.5),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                  border: Border(
                    left: BorderSide(
                      color: ShadTheme.of(context).colorScheme.border,
                    ),
                    top: BorderSide(
                      color: ShadTheme.of(context).colorScheme.border,
                    ),
                    bottom: BorderSide(
                      color: ShadTheme.of(context).colorScheme.border,
                    ),
                  ),
                ),
                child: !isPlaying
                    ? const Icon(LucideIcons.audioLines)
                    : LottieBuilder.asset(
                        "assets/images/playing.json",
                        delegates: LottieDelegates(
                          values: [
                            ValueDelegate.color(
                              const ['**'],
                              value: ShadTheme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                      )),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          title, // Source.name

          style: ShadTheme.of(context).textTheme.large.copyWith(
                color: !isPlaying
                    ? ShadTheme.of(context).colorScheme.accentForeground
                    : ShadTheme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}
