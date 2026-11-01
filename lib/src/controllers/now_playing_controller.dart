import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:live_darbar/src/models/live_playback_state.dart';

/// What the one big button should offer right now.
///
/// Live shows [stop] where a recording shows [pause]. Pausing a broadcast does
/// not pause the broadcast, and the controller already reopens the live edge
/// when you come back, so the square is the honest symbol for it.
enum PlayAction { working, play, pause, stop, replay, failed }

/// Everything the player UI needs, collapsed out of four streams.
///
/// The widgets used to each watch `sequenceStateProvider` and re-derive the
/// current source and the button state on their own, which is how the app
/// ended up with two live-detection heuristics that disagreed during loading.
/// One derivation, here, and every screen reads it.
@immutable
class NowPlaying {
  const NowPlaying({
    required this.index,
    required this.action,
    required this.started,
    required this.live,
  });

  /// [kLiveIndex], [kMukhwakIndex] or [kKathaIndex].
  final int index;

  final PlayAction action;

  /// True once anything has played this session. The mini player appears
  /// then, and stays, so it never vanishes from under a reaching finger.
  final bool started;

  final LivePlaybackState? live;

  bool get isLive => index == kLiveIndex;

  bool get isPlaying =>
      action == PlayAction.pause || action == PlayAction.stop;

  bool get isWorking => action == PlayAction.working;

  @override
  bool operator ==(Object other) =>
      other is NowPlaying &&
      other.index == index &&
      other.action == action &&
      other.started == started &&
      identical(other.live, live);

  @override
  int get hashCode => Object.hash(index, action, started, live);
}

/// Flips true the first time the player actually plays, and stays true.
class _StartedNotifier extends Notifier<bool> {
  @override
  bool build() {
    ref.listen(playerStateProvider, (_, next) {
      if (next.value?.playing ?? false) state = true;
    });
    return false;
  }
}

final _startedProvider = NotifierProvider<_StartedNotifier, bool>(
  _StartedNotifier.new,
);

final nowPlayingProvider = Provider<NowPlaying>((ref) {
  final sequence = ref.watch(sequenceStateProvider).value;
  final id = sequence?.currentSource?.tag.id;
  final index = id == null ? kLiveIndex : int.tryParse('$id') ?? kLiveIndex;
  final live = ref.watch(livePlaybackProvider).value;

  return NowPlaying(
    index: index,
    action: resolvePlayAction(ref.watch(playerStateProvider), index, live),
    started: ref.watch(_startedProvider),
    live: live,
  );
});

@visibleForTesting
PlayAction resolvePlayAction(
  AsyncValue<PlayerState> async,
  int index,
  LivePlaybackState? live,
) {
  if (live?.status == LiveStatus.failed && (live?.reconnectAttempt ?? 0) >= 3) {
    return PlayAction.failed;
  }
  return async.when(
    loading: () => PlayAction.play,
    error: (_, __) => PlayAction.failed,
    data: (state) {
      // A live stream on web re-enters `buffering` constantly as the browser
      // tops up its own buffer. A spinner each time would flicker over audio
      // that is playing perfectly well.
      final webLive = kIsWeb && index == kLiveIndex;
      final loading = state.processingState == ProcessingState.loading ||
          (!webLive && state.processingState == ProcessingState.buffering);

      // Preloading at launch also passes through `loading`. Only show work
      // in progress when someone asked for sound.
      if (loading && state.playing) return PlayAction.working;
      if (state.processingState == ProcessingState.completed) {
        return PlayAction.replay;
      }
      if (!state.playing) return PlayAction.play;
      return index == kLiveIndex ? PlayAction.stop : PlayAction.pause;
    },
  );
}

/// The one way the UI starts, pauses or resumes a source.
void togglePlayback(WidgetRef ref, int index) {
  final controller = ref.read(audioController);
  final now = ref.read(nowPlayingProvider);

  if (now.index == index && now.isPlaying) {
    controller.pause();
    return;
  }
  if (now.index == index && now.action == PlayAction.replay) {
    controller.seek(Duration.zero).then((_) => controller.play(index));
    return;
  }
  controller.play(index);
}
