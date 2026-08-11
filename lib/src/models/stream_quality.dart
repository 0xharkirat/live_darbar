import 'package:flutter/foundation.dart';

/// The two tiers SGPC publishes for the live kirtan Icecast stream.
///
/// Measured from Sydney on 2026-08-12, three runs each, medians:
///
/// | tier | first byte | 2.5 s of audio buffered |
/// | ---- | ---------- | ----------------------- |
/// | high | 1105 ms    | 1620 ms                 |
/// | low  | 2139 ms    | 3050 ms                 |
///
/// Those numbers are the reason this is an ordered fallback rather than a
/// quality preference. The low tier is not a trade of speed for bandwidth: it
/// is slower to start *and* a third of the bitrate, because the two mounts are
/// separate Icecast processes and the small one takes about twice as long to
/// emit its first header. There is no listener who benefits from choosing it
/// on merit. It exists for the places [high] cannot go.
enum StreamQuality {
  /// 96 kbps HE-AAC, cleartext on port 7339.
  ///
  /// Cleartext is why `network_security_config.xml` on Android and
  /// `NSExceptionDomains` on Apple platforms carve out `live.sgpc.net`.
  high(url: 'http://live.sgpc.net:7339/;', kbps: 96, isCleartext: true),

  /// 28 kbps HE-AAC over TLS on port 8442.
  ///
  /// The only reachable tier on web, where a page served over HTTPS may not
  /// load cleartext audio, and the fallback anywhere port 7339 is blocked or
  /// cleartext is stripped, which is common on corporate and captive networks.
  low(url: 'https://live.sgpc.net:8442/;', kbps: 28, isCleartext: false);

  const StreamQuality({
    required this.url,
    required this.kbps,
    required this.isCleartext,
  });

  final String url;
  final int kbps;
  final bool isCleartext;

  /// Where playback starts before anything has gone wrong.
  static StreamQuality get initial =>
      isWeb ? StreamQuality.low : StreamQuality.high;

  /// True when cleartext is unreachable no matter what the network allows.
  static bool get isWeb => kIsWeb || kIsWasm;

  /// The tier to try after this one fails, or null when nothing is left.
  ///
  /// Web has exactly one reachable tier, so a failure there is terminal and
  /// the caller should retry the same URL rather than pretend there is an
  /// alternative.
  StreamQuality? get fallback {
    if (isWeb) return null;
    return this == StreamQuality.high ? StreamQuality.low : StreamQuality.high;
  }

  /// Rough bytes per second of wall-clock audio, for buffer estimates.
  int get bytesPerSecond => kbps * 1000 ~/ 8;
}
