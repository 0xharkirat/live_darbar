import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/models/audio_progress_state.dart';

AudioProgressState state({Duration? total, required bool isLive}) {
  return AudioProgressState(
    position: const Duration(seconds: 5),
    bufferedPosition: const Duration(seconds: 8),
    totalDuration: total,
    isLive: isLive,
  );
}

void main() {
  group('liveness does not depend on the reported duration', () {
    // The regression this guards against, in both directions it has failed.
    //
    // ExoPlayer reports null for the live stream; AVPlayer reports
    // Duration.zero, measured on an iPhone 17 Pro simulator. Any check against
    // the duration is therefore right on one platform and wrong on the other,
    // which is how live kirtan came to draw a seek bar on iOS.

    test('live with a null duration, as Android reports it', () {
      final s = state(total: null, isLive: true);
      expect(s.isLive, isTrue);
      expect(s.hasDuration, isFalse);
    });

    test('live with a zero duration, as iOS reports it', () {
      final s = state(total: Duration.zero, isLive: true);
      expect(s.isLive, isTrue);
      expect(s.hasDuration, isFalse,
          reason: 'a live stream never has a length to draw against');
    });

    test('a recording is not live even before its length arrives', () {
      // Duration is null here only because loading has not finished. Treating
      // that as live would flash the LIVE badge over a Katha recording.
      final s = state(total: null, isLive: false);
      expect(s.isLive, isFalse);
      expect(s.hasDuration, isFalse, reason: 'nothing to draw against yet');
    });

    test('a loaded recording has a length', () {
      final s = state(total: const Duration(minutes: 4), isLive: false);
      expect(s.isLive, isFalse);
      expect(s.hasDuration, isTrue);
    });

    test('a recording reporting zero length has nothing to draw', () {
      // Dividing by this is what produced the old zero-width bar.
      final s = state(total: Duration.zero, isLive: false);
      expect(s.hasDuration, isFalse);
    });
  });
}
