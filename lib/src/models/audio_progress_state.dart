/// A snapshot of where playback is, for the progress bar to render.
class AudioProgressState {
  const AudioProgressState({
    required this.position,
    required this.bufferedPosition,
    required this.totalDuration,
    required this.isLive,
  });

  final Duration position;
  final Duration bufferedPosition;

  /// How long the track is, when that is a meaningful question.
  ///
  /// Do not infer liveness from this. It is null on Android for the live
  /// stream and [Duration.zero] on iOS, because ExoPlayer and AVPlayer
  /// disagree about how to describe a stream that never ends. Measured on an
  /// iPhone 17 Pro simulator: `duration reported as 0:00:00.000000`.
  final Duration? totalDuration;

  /// Whether the loaded source is the live stream.
  ///
  /// Taken from which source the controller chose, not guessed from the
  /// player. That is the only version of this fact that is true on every
  /// platform, and it is knowable with certainty rather than inferred.
  ///
  /// Both previous attempts got this wrong in opposite directions. Checking
  /// `duration == Duration.zero` worked by accident on both platforms but also
  /// matched a genuinely empty track. Checking `duration == null` was correct
  /// on Android and silently wrong on iOS, where live kirtan would have drawn
  /// a seek bar instead of the live state.
  final bool isLive;

  /// True when there is a real length to draw a progress fraction against.
  bool get hasDuration =>
      !isLive && totalDuration != null && totalDuration! > Duration.zero;
}
