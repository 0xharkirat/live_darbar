import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/models/stream_quality.dart';

void main() {
  group('StreamQuality', () {
    test('high is the cleartext 96 kbps mount', () {
      expect(StreamQuality.high.kbps, 96);
      expect(StreamQuality.high.isCleartext, isTrue);
      expect(StreamQuality.high.url, startsWith('http://'));
      expect(StreamQuality.high.url, contains(':7339'));
    });

    test('low is the TLS 28 kbps mount', () {
      expect(StreamQuality.low.kbps, 28);
      expect(StreamQuality.low.isCleartext, isFalse);
      expect(StreamQuality.low.url, startsWith('https://'));
      expect(StreamQuality.low.url, contains(':8442'));
    });

    test('starts on the faster, higher tier off web', () {
      // These tests run on the Dart VM, so kIsWeb is false.
      expect(StreamQuality.isWeb, isFalse);
      expect(StreamQuality.initial, StreamQuality.high);
    });

    test('the two tiers fall back to each other', () {
      // Alternating rather than a one-way downgrade, because a failure on the
      // TLS mount says nothing about the cleartext one.
      expect(StreamQuality.high.fallback, StreamQuality.low);
      expect(StreamQuality.low.fallback, StreamQuality.high);
    });

    test('bytesPerSecond matches the advertised bitrate', () {
      expect(StreamQuality.high.bytesPerSecond, 12000);
      expect(StreamQuality.low.bytesPerSecond, 3500);
    });
  });
}
