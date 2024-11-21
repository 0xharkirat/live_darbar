import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:live_darbar/src/views/widgets/audio_tile_widget.dart';
import 'package:live_darbar/src/views/widgets/play_pause_button_widget.dart';
import 'package:live_darbar/src/views/widgets/player_data_widget.dart';
import 'package:live_darbar/src/views/widgets/progress_bar_widget.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the audio progress state using the StreamProvider
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Live Darbar',
        ),
        backgroundColor: ShadTheme.of(context).colorScheme.accent,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                AudioTileWidget(
                    onTap: () {
                      ref.read(audioController).play(0);
                    },
                    text: 'Live Kirtan',
                    imageUrl: 'assets/images/bg-5.jpg',
                    height: size.height * 0.3,
                    width: double.infinity,
                    style: ShadTheme.of(context).textTheme.h1Large.copyWith(
                        color:
                            ShadTheme.of(context).colorScheme.accentForeground,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: AudioTileWidget(
                        onTap: () {
                          ref.read(audioController).play(1);
                        },
                        text: "Mukhwak",
                        imageUrl: "assets/images/bg-4.jpg",
                        height: size.height * 0.2,
                        width: null,
                        style: ShadTheme.of(context).textTheme.h3.copyWith(
                            color: ShadTheme.of(context).colorScheme.foreground,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AudioTileWidget(
                        onTap: () {
                          ref.read(audioController).play(2);
                        },
                        text: "Mukhwak Katha",
                        imageUrl: "assets/images/bg-4.jpg",
                        height: size.height * 0.2,
                        width: null,
                        style: ShadTheme.of(context).textTheme.h3.copyWith(
                            color: ShadTheme.of(context).colorScheme.foreground,
                            fontWeight: FontWeight.bold),
                      ),
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
              height: 56,
              width: size.width,
              decoration: BoxDecoration(
                color: ShadTheme.of(context).colorScheme.accent,
                border: Border.all(
                  color: ShadTheme.of(context).colorScheme.border,
                ),
              ),
              child: Stack(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      PlayerDataWidget(),
                      PlayPauseButtonWidget(),
                    ],
                  ),
                  Positioned(bottom: 0, child: ProgressBarWidget(size: size))
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
