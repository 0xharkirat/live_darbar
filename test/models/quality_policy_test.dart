import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/models/quality_policy.dart';
import 'package:live_darbar/src/models/stream_quality.dart';

void main() {
  final t0 = DateTime(2026, 11, 2, 12);
  DateTime at(int seconds) => t0.add(Duration(seconds: seconds));

  group('QualityMode.parse', () {
    test('reads each saved name back', () {
      for (final mode in QualityMode.values) {
        expect(QualityMode.parse(mode.name), mode);
      }
    });

    test('treats missing and unknown values as automatic', () {
      expect(QualityMode.parse(null), QualityMode.automatic);
      expect(QualityMode.parse('turbo'), QualityMode.automatic);
    });
  });

  group('preferred tier', () {
    test('automatic and high start on the high tier', () {
      expect(QualityPolicy().preferred, StreamQuality.high);
      expect(
        QualityPolicy(mode: QualityMode.high).preferred,
        StreamQuality.high,
      );
    });

    test('data saver starts on the low tier', () {
      expect(
        QualityPolicy(mode: QualityMode.dataSaver).preferred,
        StreamQuality.low,
      );
    });

    test('web only has the low tier, whatever the mode', () {
      for (final mode in QualityMode.values) {
        final policy = QualityPolicy(mode: mode, canSwitchTiers: false);
        expect(policy.preferred, StreamQuality.low);
      }
    });
  });

  group('stalls', () {
    test('two stalls are not enough', () {
      final policy = QualityPolicy();
      expect(policy.recordStall(at(0), StreamQuality.high), isNull);
      expect(policy.recordStall(at(10), StreamQuality.high), isNull);
    });

    test('three stalls inside 60 seconds drop to the low tier', () {
      final policy = QualityPolicy();
      expect(policy.recordStall(at(0), StreamQuality.high), isNull);
      expect(policy.recordStall(at(20), StreamQuality.high), isNull);
      expect(policy.recordStall(at(40), StreamQuality.high), StreamQuality.low);
    });

    test('the window includes exactly 60 seconds', () {
      final policy = QualityPolicy();
      policy.recordStall(at(0), StreamQuality.high);
      policy.recordStall(at(30), StreamQuality.high);
      expect(policy.recordStall(at(60), StreamQuality.high), StreamQuality.low);
    });

    test('stalls spread past the window never add up', () {
      final policy = QualityPolicy();
      // One stall every 31 seconds: no 60 second span holds three of them.
      for (var i = 0; i < 20; i++) {
        expect(policy.recordStall(at(i * 31), StreamQuality.high), isNull);
      }
    });

    test('the count starts over after a drop', () {
      final policy = QualityPolicy();
      policy.recordStall(at(0), StreamQuality.high);
      policy.recordStall(at(1), StreamQuality.high);
      expect(policy.recordStall(at(2), StreamQuality.high), StreamQuality.low);
      // Back on high later. One stall must not be enough on its own.
      expect(policy.recordStall(at(3), StreamQuality.high), isNull);
    });

    test('nothing is below the low tier', () {
      final policy = QualityPolicy();
      for (var i = 0; i < 10; i++) {
        expect(policy.recordStall(at(i), StreamQuality.low), isNull);
      }
    });

    test('high mode never drops on stalls', () {
      final policy = QualityPolicy(mode: QualityMode.high);
      for (var i = 0; i < 10; i++) {
        expect(policy.recordStall(at(i), StreamQuality.high), isNull);
      }
    });

    test('data saver never answers a stall', () {
      final policy = QualityPolicy(mode: QualityMode.dataSaver);
      for (var i = 0; i < 10; i++) {
        expect(policy.recordStall(at(i), StreamQuality.low), isNull);
      }
    });

    test('web never switches tiers', () {
      final policy = QualityPolicy(canSwitchTiers: false);
      for (var i = 0; i < 10; i++) {
        expect(policy.recordStall(at(i), StreamQuality.low), isNull);
      }
    });
  });

  group('trying the preferred tier again', () {
    // Each test starts from a policy that has just dropped to the low tier.
    QualityPolicy dropped() {
      final policy = QualityPolicy();
      policy.recordStall(at(0), StreamQuality.high);
      policy.recordStall(at(1), StreamQuality.high);
      policy.recordStall(at(2), StreamQuality.high);
      return policy;
    }

    test('waits for ten minutes of healthy play', () {
      final policy = dropped();
      policy.playbackHealthy(at(10));
      expect(policy.retryTarget(at(10), StreamQuality.low), isNull);
      expect(policy.retryTarget(at(10 + 599), StreamQuality.low), isNull);
      expect(
        policy.retryTarget(at(10 + 600), StreamQuality.low),
        StreamQuality.high,
      );
    });

    test('does not count time before play became healthy', () {
      final policy = dropped();
      expect(policy.retryTarget(at(3600), StreamQuality.low), isNull);
    });

    test('calling playbackHealthy again does not restart the clock', () {
      final policy = dropped();
      policy.playbackHealthy(at(10));
      policy.playbackHealthy(at(300));
      expect(
        policy.retryTarget(at(10 + 600), StreamQuality.low),
        StreamQuality.high,
      );
    });

    test('a pause restarts the clock', () {
      final policy = dropped();
      policy.playbackHealthy(at(10));
      policy.playbackInterrupted();
      policy.playbackHealthy(at(500));
      expect(policy.retryTarget(at(700), StreamQuality.low), isNull);
      expect(
        policy.retryTarget(at(500 + 600), StreamQuality.low),
        StreamQuality.high,
      );
    });

    test('a stall on the low tier restarts the clock', () {
      final policy = dropped();
      policy.playbackHealthy(at(10));
      policy.recordStall(at(400), StreamQuality.low);
      policy.playbackHealthy(at(402));
      expect(policy.retryTarget(at(10 + 600), StreamQuality.low), isNull);
      expect(
        policy.retryTarget(at(402 + 600), StreamQuality.low),
        StreamQuality.high,
      );
    });

    test('says nothing while already on the preferred tier', () {
      final policy = QualityPolicy();
      policy.playbackHealthy(at(0));
      expect(policy.retryTarget(at(7200), StreamQuality.high), isNull);
    });

    test('data saver returns to low after a fallback to high', () {
      final policy = QualityPolicy(mode: QualityMode.dataSaver);
      policy.noteFellBack(at(0));
      policy.playbackHealthy(at(1));
      expect(
        policy.retryTarget(at(1 + 600), StreamQuality.high),
        StreamQuality.low,
      );
    });

    test('high mode returns to high after a connect fallback', () {
      final policy = QualityPolicy(mode: QualityMode.high);
      policy.noteFellBack(at(0));
      policy.playbackHealthy(at(1));
      expect(
        policy.retryTarget(at(1 + 600), StreamQuality.low),
        StreamQuality.high,
      );
    });

    test('a retry that falls back at once doubles the next wait', () {
      final policy = dropped();
      policy.playbackHealthy(at(10));
      policy.recordRetry(at(610));
      // Three stalls on high, 30 seconds after the retry.
      policy.recordStall(at(640), StreamQuality.high);
      policy.recordStall(at(641), StreamQuality.high);
      expect(
        policy.recordStall(at(642), StreamQuality.high),
        StreamQuality.low,
      );
      expect(policy.retryWait, const Duration(minutes: 20));

      policy.playbackHealthy(at(650));
      expect(policy.retryTarget(at(650 + 1199), StreamQuality.low), isNull);
      expect(
        policy.retryTarget(at(650 + 1200), StreamQuality.low),
        StreamQuality.high,
      );
    });

    test('the backoff stops at 40 minutes', () {
      final policy = QualityPolicy();
      var now = 0;
      for (var i = 0; i < 6; i++) {
        policy.recordRetry(at(now));
        now += 5;
        policy.noteFellBack(at(now));
      }
      expect(policy.retryWait, const Duration(minutes: 40));
    });

    test('a retry that held for ten minutes resets the schedule', () {
      final policy = QualityPolicy();
      policy.recordRetry(at(0));
      policy.noteFellBack(at(10));
      expect(policy.retryWait, const Duration(minutes: 20));

      policy.recordRetry(at(2000));
      policy.noteFellBack(at(2000 + 601));
      expect(policy.retryWait, const Duration(minutes: 10));
    });

    test('a new network forgets the stalls and the backoff', () {
      final policy = QualityPolicy();
      policy.recordStall(at(0), StreamQuality.high);
      policy.recordStall(at(1), StreamQuality.high);
      policy.networkChanged();
      // Without the reset this third stall would have dropped the tier.
      expect(policy.recordStall(at(2), StreamQuality.high), isNull);
    });

    test('web never retries', () {
      final policy = QualityPolicy(canSwitchTiers: false);
      policy.playbackHealthy(at(0));
      expect(policy.retryTarget(at(7200), StreamQuality.high), isNull);
    });
  });

  group('a retry that cannot connect', () {
    // Port 7339 blocked: every retry of the high tier fails to connect and
    // costs a working low-tier stream about 20 seconds of silence.
    QualityPolicy blocked() {
      final policy = QualityPolicy();
      policy.noteFellBack(at(0));
      policy.playbackHealthy(at(1));
      expect(
        policy.retryTarget(at(1 + 600), StreamQuality.low),
        StreamQuality.high,
      );
      policy.recordRetry(at(601));
      policy.recordRetryFailed();
      return policy;
    }

    test('stops all further retries, however long the play', () {
      final policy = blocked();
      policy.playbackHealthy(at(700));
      expect(policy.retryTarget(at(700 + 600), StreamQuality.low), isNull);
      expect(policy.retryTarget(at(700 + 7200), StreamQuality.low), isNull);
    });

    test('a new network lifts the block', () {
      final policy = blocked();
      policy.networkChanged();
      policy.noteFellBack(at(800));
      policy.playbackHealthy(at(801));
      expect(
        policy.retryTarget(at(801 + 600), StreamQuality.low),
        StreamQuality.high,
      );
    });

    test('a new mode lifts the block', () {
      final policy = blocked();
      policy.mode = QualityMode.high;
      policy.noteFellBack(at(800));
      policy.playbackHealthy(at(801));
      expect(
        policy.retryTarget(at(801 + 600), StreamQuality.low),
        StreamQuality.high,
      );
    });

    test('does not stop a stall drop on the preferred tier', () {
      final policy = blocked();
      policy.recordStall(at(900), StreamQuality.high);
      policy.recordStall(at(901), StreamQuality.high);
      expect(
        policy.recordStall(at(902), StreamQuality.high),
        StreamQuality.low,
      );
    });
  });

  group('changing the mode', () {
    test('clears what the old mode had learned', () {
      final policy = QualityPolicy();
      policy.recordStall(at(0), StreamQuality.high);
      policy.recordStall(at(1), StreamQuality.high);
      policy.mode = QualityMode.automatic;
      expect(policy.recordStall(at(2), StreamQuality.high), isNull);
    });

    test('moves the preferred tier', () {
      final policy = QualityPolicy();
      policy.mode = QualityMode.dataSaver;
      expect(policy.preferred, StreamQuality.low);
      policy.mode = QualityMode.high;
      expect(policy.preferred, StreamQuality.high);
    });
  });
}
