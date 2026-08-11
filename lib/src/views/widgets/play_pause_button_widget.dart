import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// What the button should currently offer.
enum _Action { working, play, pause, replay, failed }

class PlayPauseButtonWidget extends ConsumerWidget {
  const PlayPauseButtonWidget({
    super.key,
    this.showBackground = true,
  });

  final bool showBackground;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerStateAsync = ref.watch(playerStateProvider);
    final index = _currentIndex(ref);
    final action = _resolve(playerStateAsync, index);
    final theme = ShadTheme.of(context);
    final controller = ref.read(audioController);

    // Colours invert for the pause state so the button reads as "active".
    final isActive = action == _Action.pause;
    final background = action == _Action.failed
        ? theme.colorScheme.destructiveForeground
        : isActive
            ? theme.colorScheme.primary
            : theme.colorScheme.foreground;
    final foreground = action == _Action.failed
        ? theme.colorScheme.destructive
        : isActive
            ? theme.colorScheme.foreground
            : theme.colorScheme.primary;

    return CircleAvatar(
      backgroundColor: showBackground ? background : Colors.transparent,
      radius: showBackground ? 40 : 20,
      child: switch (action) {
        _Action.working => IconButton(
            onPressed: null,
            icon: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
            ),
          ),
        _Action.failed => Icon(LucideIcons.circleAlert, color: foreground),
        _Action.pause => IconButton(
            splashRadius: 40,
            onPressed: controller.pause,
            icon: Icon(LucideIcons.pause, color: foreground),
          ),
        _Action.play => IconButton(
            splashRadius: 40,
            onPressed: () => controller.play(index),
            icon: Icon(LucideIcons.play, color: foreground),
          ),
        _Action.replay => IconButton(
            splashRadius: 40,
            onPressed: () async {
              await controller.seek(Duration.zero);
              await controller.play(index);
            },
            icon: Icon(LucideIcons.play, color: foreground),
          ),
      },
    );
  }

  int _currentIndex(WidgetRef ref) {
    final sequence = ref.watch(sequenceStateProvider).value;
    final id = sequence?.currentSource?.tag.id;
    return id == null ? kLiveIndex : int.tryParse('$id') ?? kLiveIndex;
  }

  /// Collapse player state into the one thing the button should do.
  ///
  /// This used to be two near-identical branches, one guarded on `kIsWeb &&
  /// index == 0`, differing only in whether `buffering` showed a spinner. The
  /// duplication also gave the app its second live-detection heuristic, which
  /// disagreed with the progress bar's during loading. One path now, with that
  /// single genuine difference expressed as a condition rather than a fork.
  static _Action _resolve(AsyncValue<PlayerState> async, int index) {
    return async.when(
      loading: () => _Action.working,
      error: (_, __) => _Action.failed,
      data: (state) {
        // A live stream on web re-enters `buffering` constantly as the browser
        // tops up its own buffer. Showing a spinner each time makes the button
        // flicker while audio is playing perfectly well, so on that one
        // combination buffering is not treated as work in progress.
        final webLive = kIsWeb && index == kLiveIndex;
        final busy = state.processingState == ProcessingState.loading ||
            (!webLive && state.processingState == ProcessingState.buffering);

        if (busy) return _Action.working;
        if (state.processingState == ProcessingState.completed) {
          return _Action.replay;
        }
        return state.playing ? _Action.pause : _Action.play;
      },
    );
  }
}
