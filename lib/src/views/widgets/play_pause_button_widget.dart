import 'dart:developer';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class PlayPauseButtonWidget extends ConsumerWidget {
  const PlayPauseButtonWidget({
    super.key,
    this.showBackground = true,
  });

  final bool showBackground;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerStateAsync = ref.watch(playerStateProvider);
    final sequenceStateAsync = ref.watch(sequenceStateProvider);

    // Get the current index
    final index = sequenceStateAsync.when(
      data: (value) {
        if (value == null) {
          return 0;
        }
        return int.parse(value.currentSource?.tag.id);
      },
      loading: () => 0,
      error: (error, _) => 0,
    );

    // Detect if it's a live stream (assuming ID 0 is the live stream)
    final isLiveStream = index == 0;

    return playerStateAsync.when(
      data: (playerState) {
        // Web-Specific Live Stream Handling
        if (kIsWeb && isLiveStream) {
          // Show the loading indicator only if it's buffering/loading AND not playing
          if (playerState.processingState == ProcessingState.loading) {
            log("Web Live Stream: Loading ");
            return CircleAvatar(
              backgroundColor: showBackground
                  ? ShadTheme.of(context).colorScheme.foreground
                  : Colors.transparent,
              radius: showBackground ? 40 : 20,
              child: const IconButton(
                onPressed: null,
                icon: SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          // Show play button if paused
          if (!playerState.playing) {
            log("Web Live Stream: Paused");
            return CircleAvatar(
              backgroundColor: showBackground
                  ? ShadTheme.of(context).colorScheme.foreground
                  : Colors.transparent,
              radius: showBackground ? 40 : 20,
              child: IconButton(
                onPressed: () {
                  ref.read(audioController).play(index);
                },
                icon: Icon(LucideIcons.play,
                    color: ShadTheme.of(context).colorScheme.primary),
              ),
            );
          }

          // Show pause button if playing
          if (playerState.playing) {
            log("Web Live Stream: Playing");
            return CircleAvatar(
              backgroundColor: showBackground
                  ? ShadTheme.of(context).colorScheme.primary
                  : Colors.transparent,
              radius: showBackground ? 40 : 20,
              child: IconButton(
                onPressed: () {
                  ref.read(audioController).pause();
                },
                icon: Icon(LucideIcons.pause,
                    color: ShadTheme.of(context).colorScheme.foreground),
              ),
            );
          }
        }

        // Handle non-live audio and mobile platforms
        if (playerState.processingState == ProcessingState.loading ||
            playerState.processingState == ProcessingState.buffering) {
          log("Loading or Buffering");
          return CircleAvatar(
            backgroundColor: showBackground
                ? ShadTheme.of(context).colorScheme.foreground
                : Colors.transparent,
            radius: showBackground ? 40 : 20,
            child: const IconButton(
              onPressed: null,
              icon: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        if (playerState.processingState == ProcessingState.completed) {
          log("Completed");
          return CircleAvatar(
            backgroundColor: showBackground
                ? ShadTheme.of(context).colorScheme.foreground
                : Colors.transparent,
            radius: showBackground ? 40 : 20,
            child: IconButton(
              splashRadius: 40,
              onPressed: () async {
                await ref.read(audioController).seek(Duration.zero);
                ref.read(audioController).play(index);
              },
              icon: Icon(LucideIcons.play,
                  color: ShadTheme.of(context).colorScheme.primary),
            ),
          );
        }

        if (playerState.playing) {
          log("Playing");
          return CircleAvatar(
            backgroundColor: showBackground
                ? ShadTheme.of(context).colorScheme.primary
                : Colors.transparent,
            radius: showBackground ? 40 : 20,
            child: IconButton(
              splashRadius: 40,
              onPressed: () {
                ref.read(audioController).pause();
              },
              icon: Icon(LucideIcons.pause,
                  color: ShadTheme.of(context).colorScheme.foreground),
            ),
          );
        }

        if (playerState.processingState == ProcessingState.ready ||
            !playerState.playing) {
          log("Ready or Paused");
          return CircleAvatar(
            backgroundColor: showBackground
                ? ShadTheme.of(context).colorScheme.foreground
                : Colors.transparent,
            radius: showBackground ? 40 : 20,
            child: IconButton(
              splashRadius: 40,
              onPressed: () {
                ref.read(audioController).resume();
              },
              icon: Icon(LucideIcons.play,
                  color: ShadTheme.of(context).colorScheme.primary),
            ),
          );
        }

        log("Unexpected State");
        return CircleAvatar(
          backgroundColor: showBackground
              ? ShadTheme.of(context).colorScheme.destructiveForeground
              : Colors.transparent,
          radius: showBackground ? 40 : 20,
          child: Icon(LucideIcons.circleAlert,
              color: ShadTheme.of(context).colorScheme.destructive),
        );
      },
      loading: () => CircleAvatar(
        backgroundColor: showBackground
            ? ShadTheme.of(context).colorScheme.foreground
            : Colors.transparent,
        radius: showBackground ? 40 : 20,
        child: const IconButton(
          onPressed: null,
          icon: SizedBox.square(
            dimension: 40,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (error, stack) => CircleAvatar(
        backgroundColor: showBackground
            ? ShadTheme.of(context).colorScheme.destructiveForeground
            : Colors.transparent,
        radius: showBackground ? 40 : 20,
        child: IconButton(
          onPressed: null,
          icon: Icon(LucideIcons.circleAlert,
              color: ShadTheme.of(context).colorScheme.destructive),
        ),
      ),
    );
  }
}
