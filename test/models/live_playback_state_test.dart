import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/models/live_playback_state.dart';
import 'package:live_darbar/src/models/stream_quality.dart';

void main() {
  group('LivePlaybackState.isBehindLive', () {
    test('normal buffer depth does not count as behind', () {
      // Playing steadily, the gap is just the playback buffer. Offering to
      // reconnect over a second of drift would cost more than it saves.
      const state = LivePlaybackState(behindLive: Duration(seconds: 2));
      expect(state.isBehindLive, isFalse);
    });

    test('the threshold itself is not yet behind', () {
      const state = LivePlaybackState(
        behindLive: LivePlaybackState.behindLiveThreshold,
      );
      expect(state.isBehindLive, isFalse);
    });

    test('a long pause counts as behind', () {
      const state = LivePlaybackState(behindLive: Duration(seconds: 40));
      expect(state.isBehindLive, isTrue);
    });

    test('a recording is never behind, however large the gap', () {
      // Mukhwak and Katha are fixed-length files. Their buffer runs far ahead
      // of the playhead by design, which must not be read as drift.
      const state = LivePlaybackState(
        behindLive: Duration(minutes: 5),
        isLiveSource: false,
      );
      expect(state.isBehindLive, isFalse);
    });
  });

  group('LivePlaybackState.isWorking', () {
    test('connecting and buffering are the listener waiting on us', () {
      for (final status in [LiveStatus.connecting, LiveStatus.buffering]) {
        expect(LivePlaybackState(status: status).isWorking, isTrue,
            reason: '$status should count as working');
      }
    });

    test('everything else is not', () {
      for (final status in [
        LiveStatus.idle,
        LiveStatus.playing,
        LiveStatus.paused,
        LiveStatus.failed,
      ]) {
        expect(LivePlaybackState(status: status).isWorking, isFalse,
            reason: '$status should not count as working');
      }
    });
  });

  group('LivePlaybackState.copyWith', () {
    test('leaves untouched fields alone', () {
      const original = LivePlaybackState(
        status: LiveStatus.playing,
        quality: StreamQuality.low,
        behindLive: Duration(seconds: 3),
        reconnectAttempt: 2,
        isLiveSource: false,
      );

      final next = original.copyWith(status: LiveStatus.paused);

      expect(next.status, LiveStatus.paused);
      expect(next.quality, StreamQuality.low);
      expect(next.behindLive, const Duration(seconds: 3));
      expect(next.reconnectAttempt, 2);
      expect(next.isLiveSource, isFalse);
    });

    test('clearError wins over an omitted error', () {
      // A plain copyWith cannot null a field out, so recovery needs its own
      // flag. Without it a stale error would survive every later update.
      const failed = LivePlaybackState(
        status: LiveStatus.failed,
        error: 'connection refused',
      );

      expect(failed.copyWith(status: LiveStatus.playing).error,
          'connection refused');
      expect(
        failed.copyWith(status: LiveStatus.playing, clearError: true).error,
        isNull,
      );
    });
  });
}
