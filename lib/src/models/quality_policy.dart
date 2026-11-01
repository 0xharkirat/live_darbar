import 'dart:math' as math;

import 'package:live_darbar/src/models/stream_quality.dart';

/// What the listener chose for live kirtan quality.
///
/// Persisted by name, so renaming a value orphans every saved setting.
enum QualityMode {
  /// Start on the high tier, drop to low when the link keeps stalling, and
  /// try high again once it has been quiet for a while. The default.
  automatic,

  /// Stay on the 96 kbps tier. Falls back only when the tier will not connect.
  high,

  /// Stay on the 28 kbps tier, for metered or very slow data.
  dataSaver;

  /// Reads a saved name. Anything unknown, including null, is [automatic].
  static QualityMode parse(String? name) {
    for (final mode in values) {
      if (mode.name == name) return mode;
    }
    return automatic;
  }
}

/// Decides which live tier to play. Pure Dart: no timers, no player, no clock.
///
/// Every method that depends on time takes `now`, so the controller owns the
/// clock and a test can walk through ten minutes in a few lines.
///
/// The model is one preferred tier and one current tier. The preferred tier
/// comes from [mode]. The current tier lives in the controller, and moves off
/// the preferred one for two reasons: the link keeps stalling ([recordStall]),
/// or the tier will not connect ([noteFellBack]). Once playback has then been
/// healthy for [retryWait], [retryTarget] says to go back.
class QualityPolicy {
  QualityPolicy({
    QualityMode mode = QualityMode.automatic,
    // False on web, where only the TLS tier is reachable.
    bool? canSwitchTiers,
  })  : _mode = mode,
        canSwitchTiers = canSwitchTiers ?? !StreamQuality.isWeb;

  /// Buffering events inside [stallWindow] that count as a failing link.
  static const stallsBeforeDrop = 3;
  static const stallWindow = Duration(seconds: 60);

  /// Healthy playback needed on a lower tier before trying the preferred one.
  static const retryHighAfter = Duration(minutes: 10);

  /// Each retry that fails doubles the wait, up to 10, 20 then 40 minutes.
  ///
  /// A link that cannot hold the high tier would otherwise cost the listener a
  /// reload gap every ten minutes, for hours.
  static const _maxBackoffSteps = 2;

  final bool canSwitchTiers;

  QualityMode _mode;
  final _stalls = <DateTime>[];
  DateTime? _healthySince;
  DateTime? _lastRetryAt;
  int _failedRetries = 0;
  bool _retryBlocked = false;

  QualityMode get mode => _mode;

  set mode(QualityMode value) {
    _mode = value;
    reset();
  }

  /// The tier to open when nothing has gone wrong.
  StreamQuality get preferred {
    if (!canSwitchTiers) return StreamQuality.low;
    return _mode == QualityMode.dataSaver
        ? StreamQuality.low
        : StreamQuality.high;
  }

  /// How long playback must stay healthy before [retryTarget] answers.
  Duration get retryWait =>
      retryHighAfter * (1 << math.min(_failedRetries, _maxBackoffSteps));

  /// Playback is running cleanly: the player is ready and playing.
  ///
  /// Safe to call on every state change. Only the first call after an
  /// interruption starts the clock.
  void playbackHealthy(DateTime now) => _healthySince ??= now;

  /// Playback stopped being clean: a pause, a stall, a failure or a reload.
  ///
  /// Paused time must not count as stable time, so a pause restarts the clock.
  void playbackInterrupted() => _healthySince = null;

  /// The player went from playing to buffering on [current].
  ///
  /// Returns the tier to switch to, or null to stay. Only [QualityMode.automatic]
  /// ever answers, and only from the high tier, because nothing is below low.
  StreamQuality? recordStall(DateTime now, StreamQuality current) {
    playbackInterrupted();
    if (_mode != QualityMode.automatic || !canSwitchTiers) return null;
    if (current == StreamQuality.low) {
      _stalls.clear();
      return null;
    }
    _stalls.removeWhere((t) => now.difference(t) > stallWindow);
    _stalls.add(now);
    if (_stalls.length < stallsBeforeDrop) return null;
    noteFellBack(now);
    return StreamQuality.low;
  }

  /// Playback moved off the tier it wanted, whatever the reason.
  ///
  /// Also tells the policy whether the last retry was a mistake. A retry that
  /// falls back again before it has played [retryHighAfter] backs the next
  /// retry off. One that held longer starts the schedule over.
  void noteFellBack(DateTime now) {
    playbackInterrupted();
    _stalls.clear();
    final retriedAt = _lastRetryAt;
    if (retriedAt != null && now.difference(retriedAt) < retryHighAfter) {
      _failedRetries++;
    } else {
      _failedRetries = 0;
    }
    _lastRetryAt = null;
  }

  /// The tier to go back to, or null when it is not time.
  ///
  /// Call this about once a second while live audio is playing.
  StreamQuality? retryTarget(DateTime now, StreamQuality current) {
    if (!canSwitchTiers || _retryBlocked) return null;
    final want = preferred;
    if (current == want) return null;
    final since = _healthySince;
    if (since == null || now.difference(since) < retryWait) return null;
    return want;
  }

  /// The retry could not connect at all, so the preferred tier is out of reach
  /// on this network.
  ///
  /// That is not a bad stretch that might pass, it is a closed port or a
  /// stripped cleartext link, and each retry costs the listener a working
  /// stream and about 20 seconds of silence. So [retryTarget] stops answering
  /// until the network or the mode changes.
  void recordRetryFailed() {
    _retryBlocked = true;
    _lastRetryAt = null;
    playbackInterrupted();
  }

  /// The controller acted on [retryTarget].
  void recordRetry(DateTime now) {
    _lastRetryAt = now;
    _healthySince = null;
    _stalls.clear();
  }

  /// The network changed under the stream. What failed before is not evidence
  /// about the new link, so forget it.
  void networkChanged() => reset();

  void reset() {
    _stalls.clear();
    _healthySince = null;
    _lastRetryAt = null;
    _failedRetries = 0;
    _retryBlocked = false;
  }
}
