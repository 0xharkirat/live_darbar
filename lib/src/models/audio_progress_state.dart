/// A snapshot of where playback is, for the progress bar to render.
class AudioProgressState {
  const AudioProgressState({
    required this.position,
    required this.bufferedPosition,
    required this.totalDuration,
  });

  final Duration position;
  final Duration bufferedPosition;

  /// Null for the live stream, which has no end.
  ///
  /// This used to collapse to [Duration.zero], which meant the progress bar
  /// and the play button each had to guess whether the source was live, and
  /// they guessed differently during loading. Keeping it null makes "live" a
  /// fact rather than an inference.
  final Duration? totalDuration;

  bool get isLive => totalDuration == null;
}
