import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:live_darbar/src/core/colors.dart';
import 'package:live_darbar/src/views/widgets/audio_tile_widget.dart';
import 'package:live_darbar/src/views/widgets/info_dialog_widget.dart';
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
    const maxWidth = 500.0;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: Container(
          decoration: BoxDecoration(
            border: Border.symmetric(
              vertical: BorderSide(
                color: ShadTheme.of(context).colorScheme.border,
              ),
            ),
          ),
          child: Scaffold(
            appBar: AppBar(
              leadingWidth: 40,
              title: const Text(
                'Live Darbar',
              ),
              centerTitle: true,
              backgroundColor: ShadTheme.of(context).colorScheme.accent,
              actions: [
                IconButton(
                    tooltip: "Refresh Audio Sources",
                    onPressed: () {
                      ref.read(audioController).stop();
                    },
                    icon: const Icon(LucideIcons.rotateCcw)),
                IconButton(
                  tooltip: "About",
                  icon: const Icon(LucideIcons.info),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return Center(
                          child: ConstrainedBox(
                            constraints:
                                const BoxConstraints(maxWidth: maxWidth),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.symmetric(
                                  vertical: BorderSide(
                                    color: ShadTheme.of(context)
                                        .colorScheme
                                        .border,
                                  ),
                                ),
                              ),
                              child: const InfoDialogWidget(),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
            body: Stack(
              children: [
                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: 20,
                      left: 20,
                      right: 20,
                      bottom: 56,
                    ),
                    child: Column(
                      children: [
                        AudioTileWidget(
                          onTap: () {
                            ref.read(audioController).play(0);
                          },
                          color: kFirstColor,
                          id: 0,
                          text: 'Live Kirtan',
                          imageUrl: 'assets/images/0.jpg',
                          style: ShadTheme.of(context).textTheme.h3.copyWith(
                                color: ShadTheme.of(context).colorScheme.accent,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 20),
                        AudioTileWidget(
                          onTap: () {
                            ref.read(audioController).play(1);
                          },
                          color: kSecondColor,
                          id: 1,
                          text: "Mukhwak",
                          imageUrl: "assets/images/1.jpg",
                          style: ShadTheme.of(context).textTheme.h3.copyWith(
                              color:
                                  ShadTheme.of(context).colorScheme.foreground,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),
                        AudioTileWidget(
                          onTap: () {
                            ref.read(audioController).play(2);
                          },
                          color: kThirdColor,
                          id: 2,
                          text: "Mukhwak Katha",
                          imageUrl: "assets/images/2.jpg",
                          style: ShadTheme.of(context).textTheme.h3.copyWith(
                              color:
                                  ShadTheme.of(context).colorScheme.foreground,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),

                // This is player controls
                // I want to apply backdrop filter here such that when scrolling, anything which gets behind this player controls should be blurred
                Positioned(
                  bottom: 0,
                  left: 12, // Added padding for left
                  right: 12,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        height: 56,
                        width: size.width > maxWidth ? maxWidth : size.width,
                        decoration: BoxDecoration(
                          color: ShadTheme.of(context)
                              .colorScheme
                              .accent
                              .withOpacity(0.8),
                          borderRadius: BorderRadius.circular(16),
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
                            Positioned(
                              bottom: 0,
                              left: 56,
                              right: 12,
                              child: ProgressBarWidget(
                                  width: size.width > maxWidth
                                      ? maxWidth
                                      : size.width),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
