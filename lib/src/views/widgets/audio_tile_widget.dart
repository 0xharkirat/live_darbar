import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:lottie/lottie.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:transparent_image/transparent_image.dart';

class AudioTileWidget extends ConsumerWidget {
  const AudioTileWidget({
    super.key,
    required this.text,
    required this.imageUrl,
    required this.style,
    required this.onTap,
    required this.id,
    required this.color,
  });

  final String text;
  final String imageUrl;

  final TextStyle style;
  final VoidCallback onTap;
  final int id;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final currentAudio = ref.watch(sequenceStateProvider);
    final bool isSelected = currentAudio.when(
      data: (value) {
        if (value == null) {
          return false;
        }
        return value.currentSource?.tag.id == id;
      },
      loading: () => false,
      error: (error, _) => false,
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: ShadTheme.of(context).colorScheme.card,
          border: Border.all(
            color: !isSelected ? Colors.transparent : color,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              child: FadeInImage(
                placeholder: MemoryImage(kTransparentImage),
                image: AssetImage(imageUrl),
                fit: BoxFit.cover,
                width: double.infinity,
                height: size.height * 0.3,
              ),
            ),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: ListTile(
                title: Text(
                  text,
                  style: style,
                ),
                trailing: SizedBox(
                  height: 56,
                  width: 56,
                  child: Consumer(
                    builder: (context, ref, _) {
                      final playerStateAsync = ref.watch(playerStateProvider);

                      final bool isPlaying = playerStateAsync.when(
                        data: (playerState) {
                          return playerState.playing &&
                              playerState.processingState !=
                                  ProcessingState.completed;
                        },
                        loading: () => false,
                        error: (error, _) => false,
                      );

                      if (isPlaying && isSelected) {
                        return LottieBuilder.asset(
                          "assets/images/playing.json",
                          delegates: LottieDelegates(
                            values: [
                              ValueDelegate.color(
                                const ['**'],
                                value:
                                    ShadTheme.of(context).colorScheme.primary,
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
