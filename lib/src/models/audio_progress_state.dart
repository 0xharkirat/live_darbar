class AudioProgressState {
  final Duration position;
  final Duration bufferedPosition;
  final Duration totalDuration;

  AudioProgressState({
    required this.position,
    required this.bufferedPosition,
    required this.totalDuration,
  });
}
