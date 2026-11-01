// Answers one question that only a real device can answer: does this platform
// actually let the app open the live kirtan stream?
//
// It exists because the stream is cleartext, `http://live.sgpc.net:7339/;`,
// and every platform blocks that by default. Android needs the domain listed
// in `network_security_config.xml`; iOS and macOS need it under
// `NSExceptionDomains`. Both were narrowed from blanket exemptions, and a
// mistake in either would not fail to compile, would not fail a unit test, and
// would not be obvious in the UI beyond audio that never starts.
//
// Audio also does not travel through Dart's HTTP client. It goes through
// ExoPlayer on Android and AVPlayer on Apple platforms, each with its own
// networking, so a `package:http` request proves nothing about it. This drives
// the real player.
//
// Run deliberately, not in CI. It needs the network and the SGPC server:
//
//   flutter test integration_test/live_stream_reachability_test.dart -d <device>

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:live_darbar/src/models/stream_quality.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('live stream reachability', () {
    late AudioPlayer player;

    setUp(() => player = AudioPlayer());
    tearDown(() => player.dispose());

    testWidgets('the cleartext tier opens and plays', (tester) async {
      final watch = Stopwatch()..start();

      // Throws PlayerException if the platform blocks cleartext, which is the
      // failure this test is here to catch.
      await player.setUrl(StreamQuality.high.url);
      final toLoad = watch.elapsedMilliseconds;

      // Reported, not asserted. ExoPlayer returns null for a live stream;
      // AVPlayer does not, which is exactly the platform difference that made
      // inferring "is this live" from the duration a bug.
      debugPrint('[itest] cleartext duration reported as: ${player.duration}');

      await player.play();
      // Real time, not pumped frames. There is no widget tree here, so
      // `tester.pump` has nothing to drive and simply blocks until the test
      // times out, which is what happened the first time this was run.
      // AVPlayer needs noticeably longer than ExoPlayer to report playing on
      // the simulator. Two seconds was not enough and produced a failure that
      // looked like a real one.
      await Future<void>.delayed(const Duration(seconds: 8));

      expect(player.playing, isTrue);

      // Sample both clocks, because the app derives "how far behind live are
      // we" from the gap between them. If one advances and the other does not,
      // that feature is broken on this platform even though audio is fine.
      for (var i = 0; i < 5; i++) {
        debugPrint('[itest] t=${i * 2}s '
            'position=${player.position.inMilliseconds}ms '
            'buffered=${player.bufferedPosition.inMilliseconds}ms '
            'gap=${(player.bufferedPosition - player.position).inMilliseconds}ms');
        await Future<void>.delayed(const Duration(seconds: 2));
      }

      debugPrint('[itest] cleartext tier loaded in ${toLoad}ms');
    }, timeout: const Timeout(Duration(seconds: 90)));

    testWidgets('the TLS fallback tier opens and plays', (tester) async {
      // The fallback has to work too, or a cleartext failure has nowhere to go.
      final watch = Stopwatch()..start();
      await player.setUrl(StreamQuality.low.url);
      final toLoad = watch.elapsedMilliseconds;

      await player.play();
      await Future<void>.delayed(const Duration(seconds: 6));

      expect(player.playing, isTrue);

      debugPrint('[itest] tls tier: loaded in ${toLoad}ms, '
          'position=${player.position.inMilliseconds}ms '
          'buffered=${player.bufferedPosition.inMilliseconds}ms');
    }, timeout: const Timeout(Duration(seconds: 90)));
  });
}
