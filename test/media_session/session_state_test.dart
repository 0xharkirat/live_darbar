import 'package:audio_service/audio_service.dart'
    show AudioProcessingState, MediaAction, MediaControl, PlaybackState;
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState;
import 'package:live_darbar/src/media_session/session_state.dart';
import 'package:live_darbar/src/models/live_playback_state.dart';
import 'package:live_darbar/src/models/source_index.dart';

/// What the notification, a headset and a car are told about the player.
void main() {
  PlaybackState build({
    int source = kLiveIndex,
    ProcessingState processing = ProcessingState.ready,
    bool playerPlaying = true,
    bool wants = true,
    bool engaged = true,
    LiveStatus status = LiveStatus.playing,
    bool canSeek = false,
    Duration position = Duration.zero,
    Duration buffered = Duration.zero,
  }) =>
      buildPlaybackState(
        sourceIndex: source,
        processing: processing,
        playerPlaying: playerPlaying,
        wantsPlayback: wants,
        engaged: engaged,
        status: status,
        canSeek: canSeek,
        position: position,
        bufferedPosition: buffered,
      );

  group('isSessionEngaged', () {
    bool engaged({
      bool was = false,
      bool playing = false,
      bool wants = false,
      bool stopped = false,
    }) =>
        isSessionEngaged(
          wasEngaged: was,
          playerPlaying: playing,
          wantsPlayback: wants,
          stopped: stopped,
        );

    test('the launch warm-up is not engaged', () {
      expect(engaged(), isFalse);
    });

    test('a tap engages it, even before the player moves', () {
      expect(engaged(wants: true), isTrue);
    });

    test('sound engages it', () {
      expect(engaged(playing: true), isTrue);
    });

    test('a pause keeps it engaged, so the notification stays', () {
      expect(engaged(was: true), isTrue);
    });

    test('a server that drops a paused stream does not let go', () {
      // The player goes idle here, and nobody asked for sound. That is a
      // pause, and the foreground service has to survive it.
      expect(engaged(was: true, wants: false, playing: false), isTrue);
    });

    test('a stop lets go', () {
      expect(engaged(was: true, stopped: true), isFalse);
    });

    test('a play after a stop engages it again', () {
      expect(engaged(wants: true, stopped: false), isTrue);
    });

    test('a stop still yields to sound that was asked for since', () {
      expect(engaged(was: true, wants: true, stopped: true), isTrue);
    });
  });

  group('buildPlaybackState', () {
    test('a session that is not engaged is idle and has no buttons', () {
      final state = build(engaged: false);
      expect(state.processingState, AudioProcessingState.idle);
      expect(state.playing, isFalse);
      expect(state.controls, isEmpty);
      expect(state.systemActions, isEmpty);
    });

    group('live', () {
      test('offers pause and stop while playing', () {
        final state = build();
        expect(state.processingState, AudioProcessingState.ready);
        expect(state.playing, isTrue);
        expect(state.controls, [MediaControl.pause, MediaControl.stop]);
      });

      test('offers play and stop while paused', () {
        final state = build(
          playerPlaying: false,
          wants: false,
          status: LiveStatus.paused,
        );
        expect(state.playing, isFalse);
        expect(state.controls, [MediaControl.play, MediaControl.stop]);
      });

      test('has no seek, no fast forward, no rewind and no skip', () {
        final state = build(canSeek: true);
        final actions = {
          ...state.controls.map((control) => control.action),
          ...state.systemActions,
        };
        expect(actions, {
          MediaAction.pause,
          MediaAction.stop,
        });
        expect(actions.contains(MediaAction.seek), isFalse);
        expect(actions.contains(MediaAction.fastForward), isFalse);
        expect(actions.contains(MediaAction.rewind), isFalse);
        expect(actions.contains(MediaAction.skipToNext), isFalse);
        expect(actions.contains(MediaAction.skipToPrevious), isFalse);
      });

      test('reports no position, whatever the player counts', () {
        final state = build(
          position: const Duration(minutes: 3),
          buffered: const Duration(minutes: 3, seconds: 1),
        );
        expect(state.updatePosition, Duration.zero);
        expect(state.bufferedPosition, Duration.zero);
      });
    });

    group('a recording', () {
      test('adds rewind and fast forward around play and pause', () {
        final state = build(source: kKathaIndex, canSeek: true);
        expect(state.controls, [
          MediaControl.rewind,
          MediaControl.pause,
          MediaControl.fastForward,
          MediaControl.stop,
        ]);
        expect(state.androidCompactActionIndices, [0, 1, 2]);
      });

      test('shows play when paused', () {
        final state = build(
          source: kMukhwakIndex,
          canSeek: true,
          playerPlaying: false,
          wants: false,
        );
        expect(state.controls[1], MediaControl.play);
      });

      test('turns on the seek bar once the length is known', () {
        expect(
          build(source: kKathaIndex, canSeek: true).systemActions,
          containsAll({MediaAction.seek, MediaAction.stop}),
        );
        expect(
          build(source: kKathaIndex).systemActions,
          isNot(contains(MediaAction.seek)),
        );
      });

      test('passes the position on', () {
        final state = build(
          source: kKathaIndex,
          canSeek: true,
          position: const Duration(minutes: 4),
          buffered: const Duration(minutes: 9),
        );
        expect(state.updatePosition, const Duration(minutes: 4));
        expect(state.bufferedPosition, const Duration(minutes: 9));
      });
    });

    group('processing state', () {
      test('follows the player', () {
        expect(
          build(processing: ProcessingState.buffering).processingState,
          AudioProcessingState.buffering,
        );
        expect(
          build(processing: ProcessingState.loading, status: LiveStatus.idle)
              .processingState,
          AudioProcessingState.loading,
        );
        expect(
          build(processing: ProcessingState.completed).processingState,
          AudioProcessingState.completed,
        );
      });

      test('says loading between a tap and the first byte', () {
        final state = build(
          processing: ProcessingState.idle,
          playerPlaying: false,
          status: LiveStatus.idle,
        );
        expect(state.processingState, AudioProcessingState.loading);
        expect(state.playing, isTrue);
      });

      test('a stream dropped while paused is paused, not idle', () {
        // The server hangs up on a paused live stream, and the player goes
        // idle. An idle state would end the foreground service, and the
        // play after a phone call could not start another from the
        // background.
        final state = build(
          processing: ProcessingState.idle,
          playerPlaying: false,
          wants: false,
          status: LiveStatus.idle,
        );
        expect(state.processingState, AudioProcessingState.ready);
        expect(state.playing, isFalse);
        expect(state.controls.first, MediaControl.play);
      });

      test('a session that let go is the only idle one', () {
        final state = build(
          processing: ProcessingState.idle,
          playerPlaying: false,
          wants: false,
          engaged: false,
          status: LiveStatus.idle,
        );
        expect(state.processingState, AudioProcessingState.idle);
      });

      test('says loading while a new source opens over the old one', () {
        final state = build(
          source: kKathaIndex,
          status: LiveStatus.connecting,
          position: const Duration(minutes: 40),
        );
        expect(state.processingState, AudioProcessingState.loading);
        expect(state.updatePosition, Duration.zero);
      });

      test('a failure that is retrying is buffering, never an error', () {
        final state = build(
          processing: ProcessingState.idle,
          playerPlaying: false,
          status: LiveStatus.failed,
        );
        expect(state.processingState, AudioProcessingState.buffering);
        expect(state.playing, isTrue);
        expect(state.errorMessage, isNull);
      });
    });
  });

  group('isMeaningfulChange', () {
    test('a buffer that grew is not worth sending', () {
      final before = build(source: kKathaIndex, canSeek: true);
      final after = build(
        source: kKathaIndex,
        canSeek: true,
        buffered: const Duration(minutes: 2),
      );
      expect(isMeaningfulChange(before, after), isFalse);
    });

    test('a pause is', () {
      final before = build();
      final after = build(playerPlaying: false, wants: false);
      expect(isMeaningfulChange(before, after), isTrue);
    });

    test('a new processing state is', () {
      final before = build();
      final after = build(processing: ProcessingState.buffering);
      expect(isMeaningfulChange(before, after), isTrue);
    });

    test('a change of buttons is', () {
      final live = build();
      final recording = build(source: kKathaIndex, canSeek: true);
      expect(isMeaningfulChange(live, recording), isTrue);
    });

    test('a jump in the position is, and a small drift is not', () {
      final before = build(
        source: kKathaIndex,
        canSeek: true,
        playerPlaying: false,
        wants: false,
        position: const Duration(minutes: 5),
      );
      PlaybackState at(Duration position) => build(
            source: kKathaIndex,
            canSeek: true,
            playerPlaying: false,
            wants: false,
            position: position,
          );
      expect(
        isMeaningfulChange(before, at(const Duration(minutes: 8))),
        isTrue,
      );
      expect(
        isMeaningfulChange(
          before,
          at(const Duration(minutes: 5, milliseconds: 400)),
        ),
        isFalse,
      );
    });

    test('the same state twice is not', () {
      expect(isMeaningfulChange(build(), build()), isFalse);
    });
  });
}
