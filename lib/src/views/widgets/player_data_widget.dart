import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:live_darbar/src/models/source.dart';
import 'package:lottie/lottie.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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
        final source = sequenceState?.currentSource?.tag as Source?;

        // Fall back to default source if current source is null

        final title = source?.name ?? 'Loading...';

        return title;
      },
      loading: () => 'Loading...',
      error: (error, _) => 'Error: $error',
    );

    final playerStateAsync = ref.watch(playerStateProvider);

    final isPlaying = playerStateAsync.when<bool>(
      data: (playerState) => playerState.playing,
      loading: () => false,
      error: (error, _) => false,
    );

    return Row(
      children: [
        Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: ShadTheme.of(context).colorScheme.card,
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
