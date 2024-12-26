import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ProgressBarWidget extends ConsumerWidget {
  const ProgressBarWidget({super.key, required this.width});

  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressStateAsync = ref.watch(audioProgressProvider);

    // return ConstrainedBox(
    //   constraints: BoxConstraints(
    //     maxWidth: width,
    //   ),
    //   child: const ShadProgress(
    //     minHeight: 2,
    //   ),
    // );

    return progressStateAsync.when(
      data: (progressState) {
        final position = progressState.position.inMilliseconds.toDouble();
        final bufferedPosition =
            progressState.bufferedPosition.inMilliseconds.toDouble();
        final totalDuration =
            progressState.totalDuration.inMilliseconds.toDouble();

        // Calculate progress and buffered percentage
        final progress = totalDuration > 0 ? position / totalDuration : 0.0;
        final bufferedProgress =
            totalDuration > 0 ? bufferedPosition / totalDuration : 0.0;

        return Stack(
          children: [
            // Buffered Progress (background indicator)
            Container(
              height: 2,
              width: width * bufferedProgress,
              decoration: BoxDecoration(
                color: ShadTheme.of(context).colorScheme.foreground,
                borderRadius: BorderRadius.circular(16),
              ),
            ),

            // Current Progress
            Container(
              height: 2,
              width: width * progress,
              decoration: BoxDecoration(
                color: ShadTheme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ],
        );
      },
      loading: () => ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: width,
        ),
        child: const ShadProgress(
          minHeight: 2,
        ),
      ),
      error: (error, stackTrace) => Text('Error: $error'),
    );
  }
}
