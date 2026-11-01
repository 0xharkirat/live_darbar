import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/now_playing_controller.dart';
import 'package:live_darbar/src/core/motion.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/views/widgets/pressable.dart';

/// How loud the button is.
///
/// There is one gold button per screen, on the thing that matters most. The
/// rest step down, so the eye lands in the right place first.
enum PlayButtonLook {
  /// Gold disc, dark symbol. The primary action.
  gold,

  /// Dark translucent disc, light symbol, for buttons that sit on artwork.
  glass,

  /// Symbol only, for dense rows.
  bare,
}

/// The play button, for one specific source.
///
/// It shows this source's state, not the player's: the Hukamnama tile's button
/// stays a play arrow while live kirtan plays. The symbol changes in place,
/// never the button's size or position, so a finger that is already moving
/// toward it lands where it aimed.
class PlayButton extends ConsumerWidget {
  const PlayButton({
    super.key,
    required this.index,
    this.size = 56,
    this.look = PlayButtonLook.gold,
  });

  final int index;
  final double size;
  final PlayButtonLook look;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowPlayingProvider);
    final action = now.index == index ? now.action : PlayAction.play;
    final l10n = AppLocalizations.of(context)!;
    final color =
        look == PlayButtonLook.gold ? Palette.onGold : Palette.foreground;

    final (icon, label) = switch (action) {
      PlayAction.pause => (CupertinoIcons.pause_fill, l10n.pause),
      PlayAction.stop => (CupertinoIcons.stop_fill, l10n.stop_tooltip),
      PlayAction.failed => (CupertinoIcons.arrow_clockwise, l10n.retry),
      PlayAction.replay => (CupertinoIcons.arrow_counterclockwise, l10n.retry),
      PlayAction.working || PlayAction.play => (
          CupertinoIcons.play_fill,
          l10n.play
        ),
    };

    final glyph = AnimatedSwitcher(
      duration: Motion.quick,
      switchInCurve: Motion.easeOut,
      switchOutCurve: Motion.easeOut,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 0.6, end: 1.0).animate(animation),
          child: child,
        ),
      ),
      child: Padding(
        key: ValueKey(icon),
        // The play triangle's visual centre sits left of its box.
        padding: EdgeInsets.only(
          left: icon == CupertinoIcons.play_fill ? size * 0.06 : 0,
        ),
        child: Icon(icon, size: size * 0.42, color: color),
      ),
    );

    return Pressable(
      semanticLabel: label,
      scale: 0.92,
      onTap: () {
        HapticFeedback.selectionClick();
        togglePlayback(ref, index);
      },
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (look != PlayButtonLook.bare)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: look == PlayButtonLook.gold
                      ? Palette.gold
                      : const Color(0xB30C0A09),
                  shape: BoxShape.circle,
                  border: look == PlayButtonLook.glass
                      ? Border.all(color: const Color(0x33F5F1EB))
                      : null,
                ),
                child: SizedBox.square(dimension: size),
              ),
            glyph,
            if (action == PlayAction.working)
              SizedBox.square(
                dimension: size - 4,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  strokeCap: StrokeCap.round,
                  color: color,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
