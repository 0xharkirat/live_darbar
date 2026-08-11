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
        // The live stream has no duration, so there is no fraction to draw.
        // The old code arrived at the same place by dividing by zero and
        // rendering a zero-width bar, which cost a repaint every 16 ms to show
        // nothing at all.
        if (progressState.isLive) return SizedBox(width: width, height: 2);

        final total = progressState.totalDuration!.inMilliseconds.toDouble();
        final progress =
            total > 0 ? progressState.position.inMilliseconds / total : 0.0;
        final bufferedProgress = total > 0
            ? progressState.bufferedPosition.inMilliseconds / total
            : 0.0;

        // The bar sits inside a BackdropFilter, so without this boundary every
        // tick marks the blurred layer above it dirty too.
        return RepaintBoundary(
          child: Stack(
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
          ),
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
      // A progress bar that cannot read its position is not worth a message.
      // The player above it already reports anything the listener can act on,
      // and the old `Text('Error: $error')` put a raw Dart exception on screen.
      error: (error, stackTrace) => SizedBox(width: width, height: 2),
    );
  }
}
