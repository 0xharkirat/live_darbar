import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:live_darbar/src/core/motion.dart';

/// An icon that swaps for a spinner while [busy], and back.
///
/// The swap is a contextual cross-fade, not a cut: the old icon shrinks to 30%
/// and fades while a 3 point blur grows on it, and the new one does the
/// reverse, over [Motion.press] on [Motion.easeOut]. The blur hides the moment
/// when both are on screen, so they read as one thing changing. It never
/// starts from a scale of 0, which would look as if the icon came from
/// nowhere.
///
/// Under Reduce Motion it fades and nothing else: no scale, no blur.
///
/// The box is [size] square in both states, so a button around it does not
/// change width when the spinner arrives.
class BusyIcon extends StatelessWidget {
  const BusyIcon({
    super.key,
    required this.busy,
    required this.icon,
    required this.size,
    required this.color,
  });

  final bool busy;
  final IconData icon;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: AnimatedSwitcher(
        duration: Motion.press,
        switchInCurve: Motion.easeOut,
        switchOutCurve: Motion.easeOut.flipped,
        transitionBuilder: Motion.reduced(context) ? _fade : _swap,
        child: busy
            ? CupertinoActivityIndicator(
                key: const ValueKey('busy'),
                radius: size / 2,
                color: color,
              )
            : Icon(icon, key: const ValueKey('idle'), size: size, color: color),
      ),
    );
  }

  static Widget _fade(Widget child, Animation<double> animation) =>
      FadeTransition(opacity: animation, child: child);

  static Widget _swap(Widget child, Animation<double> animation) {
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.3, end: 1).animate(animation),
        child: AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) {
            final sigma = 3 * (1 - animation.value);
            return ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: child,
            );
          },
        ),
      ),
    );
  }
}
