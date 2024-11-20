import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:live_darbar/src/views/widgets/audio_tile_widget.dart';
import 'package:live_darbar/src/views/widgets/progress_bar_widget.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool isPlaying = false;

  @override
  Widget build(BuildContext context) {
    // Watch the audio progress state using the StreamProvider
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Live Darbar',
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                AudioTileWidget(
                    text: 'Live Kirtan',
                    imageUrl: 'assets/images/bg-5.jpg',
                    height: size.height * 0.3,
                    width: double.infinity,
                    style: Theme.of(context).textTheme.displayLarge!.copyWith(
                        color: Theme.of(context).colorScheme.surface,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AudioTileWidget(
                      text: "Mukhwak",
                      imageUrl: "assets/images/bg-4.jpg",
                      height: size.height * 0.2,
                      width: size.width * 0.45,
                      style: Theme.of(context).textTheme.displaySmall!.copyWith(
                          color: Theme.of(context).colorScheme.surface,
                          fontWeight: FontWeight.bold),
                    ),
                    AudioTileWidget(
                      text: "Mukhwak Katha",
                      imageUrl: "assets/images/bg-4.jpg",
                      height: size.height * 0.2,
                      width: size.width * 0.45,
                      style: Theme.of(context).textTheme.displaySmall!.copyWith(
                          color: Theme.of(context).colorScheme.surface,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            child: Container(
              height: 48,
              width: size.width,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ),
              child: Stack(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            height: 48,
                            width: 48,
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(context).colorScheme.surfaceBright,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            "Live Kirtan",
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge!
                                .copyWith(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () async {
                          if (isPlaying) {
                            await ref.read(audioController).pause();
                            setState(() {
                              isPlaying = false;
                            });
                          } else {
                            await ref.read(audioController).play();
                            setState(() {
                              isPlaying = true;
                            });
                          }
                        },
                        icon: Icon(!isPlaying ? Icons.play_arrow : Icons.pause),
                      ),
                    ],
                  ),
                  Positioned(bottom: 0, child:  ProgressBarWidget(size: size))
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
