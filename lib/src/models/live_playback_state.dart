import 'package:live_darbar/src/models/stream_quality.dart';

/// What the live stream is doing, in terms the UI can render directly.
///
/// This exists because `just_audio`'s [ProcessingState] cannot answer the two
/// questions that matter for live radio: which tier are we on, and how far
/// behind the broadcast are we. Widgets should read this rather than
/// reconstructing it from raw player state, which is how the old code ended up
/// with two live-detection heuristics that disagreed with each other.
enum LiveStatus {
  /// Nothing has been asked for yet.
  idle,

  /// Opening a connection. Roughly one second on the high tier.
  connecting,

  /// Connected, filling the buffer before sound starts.
  buffering,

  playing,

  paused,

  /// Every reconnect attempt failed. [LivePlaybackState.error] says why.
  failed,
}

class LivePlaybackState {
  const LivePlaybackState({
    this.status = LiveStatus.idle,
    this.quality = StreamQuality.high,
    this.behindLive = Duration.zero,
    this.error,
    this.reconnectAttempt = 0,
    this.isLiveSource = true,
  });

  final LiveStatus status;
  final StreamQuality quality;

  /// False while Mukhwak or Katha is loaded.
  ///
  /// Tier and drift are meaningless for a fixed-length recording, and showing
  /// "low quality stream" over a Katha file because the live mount failed
  /// earlier would be simply untrue.
  final bool isLiveSource;

  /// How far the playhead trails the newest audio we hold.
  ///
  /// Derived as `bufferedPosition - position`, which is exact rather than
  /// estimated. While playing steadily this sits at the buffer depth, around a
  /// second. It grows one-for-one with paused time, because pausing stops the
  /// playhead but not the download: the server keeps sending and the player
  /// keeps storing.
  final Duration behindLive;

  /// Set only when [status] is [LiveStatus.failed].
  final String? error;

  /// How many consecutive reconnects have been tried. Resets on success.
  final int reconnectAttempt;

  /// Past this, offer the listener a way back to the live edge.
  ///
  /// Below it the drift is either the normal buffer or a pause short enough
  /// that nobody would notice, and interrupting playback to save a few seconds
  /// would cost more than it returns.
  static const behindLiveThreshold = Duration(seconds: 15);

  bool get isBehindLive => isLiveSource && behindLive > behindLiveThreshold;

  /// True while the listener is waiting on us rather than listening.
  bool get isWorking =>
      status == LiveStatus.connecting || status == LiveStatus.buffering;

  LivePlaybackState copyWith({
    LiveStatus? status,
    StreamQuality? quality,
    Duration? behindLive,
    String? error,
    bool clearError = false,
    int? reconnectAttempt,
    bool? isLiveSource,
  }) {
    return LivePlaybackState(
      status: status ?? this.status,
      quality: quality ?? this.quality,
      behindLive: behindLive ?? this.behindLive,
      error: clearError ? null : (error ?? this.error),
      reconnectAttempt: reconnectAttempt ?? this.reconnectAttempt,
      isLiveSource: isLiveSource ?? this.isLiveSource,
    );
  }
}
