import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:live_darbar/src/controllers/now_playing_controller.dart';
import 'package:live_darbar/src/models/live_playback_state.dart';

/// The one big button's state, for every player state that matters.
void main() {
  AsyncValue<PlayerState> state(bool playing, ProcessingState processing) =>
      AsyncValue.data(PlayerState(playing, processing));

  group('resolvePlayAction', () {
    test('a source that is not playing offers play', () {
      expect(
        resolvePlayAction(state(false, ProcessingState.ready), kKathaIndex, null),
        PlayAction.play,
      );
    });

    test('a recording that plays offers pause', () {
      expect(
        resolvePlayAction(
          state(true, ProcessingState.ready),
          kMukhwakIndex,
          null,
        ),
        PlayAction.pause,
      );
    });

    test('live that plays offers stop, because a broadcast does not pause', () {
      expect(
        resolvePlayAction(state(true, ProcessingState.ready), kLiveIndex, null),
        PlayAction.stop,
      );
    });

    test('loading after a tap shows work in progress', () {
      expect(
        resolvePlayAction(state(true, ProcessingState.loading), kLiveIndex, null),
        PlayAction.working,
      );
    });

    test('preloading at launch does not show a spinner nobody asked for', () {
      expect(
        resolvePlayAction(
          state(false, ProcessingState.loading),
          kLiveIndex,
          null,
        ),
        PlayAction.play,
      );
    });

    test('a finished recording offers to play again', () {
      expect(
        resolvePlayAction(
          state(false, ProcessingState.completed),
          kKathaIndex,
          null,
        ),
        PlayAction.replay,
      );
    });

    test('a stream that has given up reconnecting offers retry', () {
      const live = LivePlaybackState(
        status: LiveStatus.failed,
        reconnectAttempt: 3,
      );
      expect(
        resolvePlayAction(state(false, ProcessingState.idle), kLiveIndex, live),
        PlayAction.failed,
      );
    });

    test('a stream still reconnecting is not shown as failed yet', () {
      const live = LivePlaybackState(
        status: LiveStatus.failed,
        reconnectAttempt: 1,
      );
      expect(
        resolvePlayAction(state(true, ProcessingState.buffering), kLiveIndex, live),
        PlayAction.working,
      );
    });
  });
}
