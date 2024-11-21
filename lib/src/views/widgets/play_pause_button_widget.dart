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

    return playerStateAsync.when(
      data: (playerState) {
        // check the current plyaer state
        if (playerState.processingState == ProcessingState.loading ||
            playerState.processingState == ProcessingState.buffering) {
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
        } else if (playerState.playing) {
          // show the pause button
          return IconButton(
            onPressed: () {},
            icon: Icon(LucideIcons.pause,
                color: ShadTheme.of(context).colorScheme.primary),
          );
        } else {
          // show the play button
          return IconButton(
            onPressed: () {},
            icon: Icon(LucideIcons.play,
                color: ShadTheme.of(context).colorScheme.primary),
          );
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

    // return IconButton(
    //   onPressed: () async {

    //   },
    //   icon: Icon(
    //       LucideIcons.play,
    //       color: ShadTheme.of(context).colorScheme.primary),
    // );
  }
}
