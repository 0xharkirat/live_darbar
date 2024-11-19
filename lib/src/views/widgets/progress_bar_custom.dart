import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';

class ProgressBarCustom extends ConsumerWidget {
  const ProgressBarCustom({
    super.key,
    required this.barHeight,
    required this.thumbRadius,
    this.onSeek,
  });

  final double barHeight;
  final double thumbRadius;
  final Function(Duration)? onSeek;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressStateAsync = ref.watch(audioProgressProvider);
    return progressStateAsync.when(
      data: (progressState) {
        return ProgressBar(
          barHeight: barHeight,
          progress: progressState.position,
          buffered: progressState.bufferedPosition,
          total: progressState.totalDuration,
          barCapShape: BarCapShape.square,
          
          thumbRadius: thumbRadius,
          timeLabelLocation: TimeLabelLocation.none,
          onSeek: onSeek,
        );
      },
      loading: () => LinearProgressIndicator(
        minHeight: barHeight,
      ),
      error: (error, stack) => Text('Error: $error'),
    );
  }
}
