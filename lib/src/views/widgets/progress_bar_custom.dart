import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:lottie/lottie.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ProgressBarCustom extends ConsumerWidget {
  const ProgressBarCustom({
    super.key,
    this.onSeek,
  });

  final Function(Duration)? onSeek;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressStateAsync = ref.watch(audioProgressProvider);

    return progressStateAsync.when(
      data: (progressState) {
        if (progressState.totalDuration == Duration.zero) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const LinearProgressIndicator(
                value: 1,
                minHeight: 4,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    AppLocalizations.of(context)!.live,
                    style: ShadTheme.of(context).textTheme.p,
                  ),
                  const SizedBox(width: 4),
                  LottieBuilder.asset(
                    "assets/images/dot.json",
                    width: 20,
                    height: 20,
                    delegates: LottieDelegates(
                      values: [
                        ValueDelegate.color(
                          const ['**'],
                          value: ShadTheme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  )
                ],
              ),
              const SizedBox(height: 20),
            ],
          );
        }
        return ProgressBar(
          barHeight: 4,
          progress: progressState.position,
          buffered: progressState.bufferedPosition,
          total: progressState.totalDuration,
          barCapShape: BarCapShape.square,
          thumbGlowRadius: 16,
          thumbRadius: 8,
          timeLabelLocation: TimeLabelLocation.below,
          timeLabelPadding: 4,
          timeLabelTextStyle: ShadTheme.of(context).textTheme.p,
          onSeek: onSeek,
        );
      },
      loading: () => const LinearProgressIndicator(
        minHeight: 4,
      ),
      error: (error, stack) => Text('Error: $error'),
    );
  }
}
