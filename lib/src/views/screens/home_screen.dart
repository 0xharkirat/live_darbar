import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:live_darbar/src/core/colors.dart';
import 'package:live_darbar/src/views/widgets/audio_tile_widget.dart';
import 'package:live_darbar/src/views/widgets/home_app_bar_widget.dart';
import 'package:live_darbar/src/views/widgets/individual_item_dialog.dart';
import 'package:live_darbar/src/views/widgets/moving_gradient_widget.dart';
import 'package:live_darbar/src/views/widgets/play_pause_button_widget.dart';
import 'package:live_darbar/src/views/widgets/player_data_widget.dart';
import 'package:live_darbar/src/views/widgets/progress_bar_widget.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the audio progress state using the StreamProvider
    final size = MediaQuery.of(context).size;
    const maxWidth = 500.0;

    return SafeArea(
      top: false,
      child: MovingGradientWidget(
        colors: [
          Theme.of(context).colorScheme.onTertiary,
          Theme.of(context).colorScheme.onPrimary,
          Theme.of(context).colorScheme.inversePrimary,
          Theme.of(context).colorScheme.onSecondary,
        ],
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: const HomeAppBarWidget(),
          body: Stack(
            clipBehavior: Clip.antiAlias,
            children: [
              SingleChildScrollView(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: 20,
                      left: 20,
                      right: 20,
                      bottom: 56,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: maxWidth,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          AudioTileWidget(
                            onTap: () {
                              ref.read(audioController).play(0);
                              showIndividualDialog(context, maxWidth);
                            },
                            color: kFirstColor,
                            id: 0,
                            text: AppLocalizations.of(context)!.live_kirtan,
                            imageUrl: 'assets/images/0.jpg',
                            style: ShadTheme.of(context).textTheme.h3.copyWith(
                                  color:
                                      ShadTheme.of(context).colorScheme.accent,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 20),
                          AudioTileWidget(
                            onTap: () {
                              ref.read(audioController).play(1);
                              showIndividualDialog(context, maxWidth);
                            },
                            color: kSecondColor,
                            id: 1,
                            text: AppLocalizations.of(context)!.mukhwak,
                            imageUrl: "assets/images/1.jpg",
                            style: ShadTheme.of(context).textTheme.h3.copyWith(
                                color: ShadTheme.of(context)
                                    .colorScheme
                                    .foreground,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 20),
                          AudioTileWidget(
                            onTap: () {
                              ref.read(audioController).play(2);
                              showIndividualDialog(context, maxWidth);
                            },
                            color: kThirdColor,
                            id: 2,
                            text: AppLocalizations.of(context)!.mukhwak_katha,
                            imageUrl: "assets/images/2.jpg",
                            style: ShadTheme.of(context).textTheme.h3.copyWith(
                                color: ShadTheme.of(context)
                                    .colorScheme
                                    .foreground,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // This is player controls
              Positioned(
                bottom: 0,
                left: size.width > maxWidth + 48
                    ? (size.width - maxWidth) / 2 -
                        12 // A little "out" for large screens
                    : 12, // At least 12px padding for small screens
                right: size.width > maxWidth + 48
                    ? (size.width - maxWidth) / 2 -
                        12 // A little "out" for large screens
                    : 12, // At least 12px padding for small screens
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
                            .withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Stack(
                        children: [
                          InkWell(
                            onTap: () {
                              showIndividualDialog(context, maxWidth);
                            },
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                PlayerDataWidget(),
                                PlayPauseButtonWidget(
                                  showBackground: false,
                                ),
                              ],
                            ),
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
    );
  }

  Future<dynamic> showIndividualDialog(BuildContext context, double maxWidth) {
    return showDialog(
      context: context,
      builder: (context) {
        return const IndividualItemDialog();
      },
    );
  }
}
