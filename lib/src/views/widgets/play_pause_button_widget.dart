import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class PlayPauseButtonWidget extends ConsumerWidget {
  const PlayPauseButtonWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerStateAsync = ref.watch(playerStateProvider);
    final sequenceStateAsync = ref.watch(sequenceStateProvider);

    final index = sequenceStateAsync.when(
      data: (value) {
        if (value == null) {
          return 0;
        }
        return value.currentSource?.tag.id;
      },
      loading: () => 0,
      error: (error, _) => 0,
    );

    return playerStateAsync.when(
      data: (playerState) {
        // check the current player state
        if (playerState.processingState == ProcessingState.loading ||
            playerState.processingState == ProcessingState.buffering) {
          // show the loading indicator while loading or buffering
          return const IconButton(
            onPressed: null,
            icon: IconButton(
              onPressed: null,
              icon: SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        } else if (playerState.processingState == ProcessingState.completed) {
          // show the play button when the audio is completed
          return IconButton(
            onPressed: () async {
              await ref.read(audioController).seek(Duration.zero);
              ref.read(audioController).play(index);
            },
            icon: Icon(LucideIcons.play,
                color: ShadTheme.of(context).colorScheme.primary),
          );
        } else if (playerState.playing) {
          // show the pause button
          return IconButton(
            onPressed: () {
              ref.read(audioController).pause();
            },
            icon: Icon(LucideIcons.pause,
                color: ShadTheme.of(context).colorScheme.primaryForeground),
          );
        } else if (playerState.processingState == ProcessingState.ready ||
            !playerState.playing) {
          // show the play button (well resume techincally if paused -> !playerState.playing)
          return IconButton(
            onPressed: () {
              ref.read(audioController).resume();
            },
            icon: Icon(LucideIcons.play,
                color: ShadTheme.of(context).colorScheme.primary),
          );
        } else {
          // Handle the idle state (e.g, no audio source set)
          return Icon(LucideIcons.circleAlert,
              color: ShadTheme.of(context).colorScheme.destructive);
        }
      },
      loading: () => const IconButton(
        onPressed: null,
        icon: SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (error, stack) => IconButton(
        onPressed: null,
        icon: Icon(LucideIcons.circleAlert,
            color: ShadTheme.of(context).colorScheme.destructive),
      ),
    );
  }
}
