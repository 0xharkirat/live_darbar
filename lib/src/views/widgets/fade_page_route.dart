import 'package:flutter/widgets.dart';
import 'package:live_darbar/src/core/motion.dart';

/// A page that fades in and out, in place of the iOS slide from the right.
///
/// The web uses this. A page that slides in from the edge is a gesture of a
/// phone: it pairs with the swipe back, which a mouse does not have. On a
/// website the same slide reads as a native app pretending, so the page
/// changes with a short fade, over [Motion.quick] in and [Motion.press] out,
/// both easing out. Nothing moves, so there is nothing for Reduce Motion to
/// remove, and the fade stays: it is what DESIGN.md swaps movement for.
///
/// iOS and Android keep [CupertinoPageRoute], so the swipe back and the slide
/// stay as they were.
class FadePageRoute<T> extends PageRoute<T> {
  FadePageRoute({required this.builder, super.settings});

  final WidgetBuilder builder;

  @override
  Duration get transitionDuration => Motion.quick;

  @override
  Duration get reverseTransitionDuration => Motion.press;

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  /// Flutter runs every [AnimationController] at 5% of its length while
  /// Reduce Motion is on, so a fade would last one frame, which is a cut.
  /// This one opts out, so the fade is the same fade, as in `showAppSheet`.
  @override
  AnimationController createAnimationController() => AnimationController(
        duration: transitionDuration,
        reverseDuration: reverseTransitionDuration,
        animationBehavior: AnimationBehavior.preserve,
        debugLabel: debugLabel,
        vsync: navigator!,
      );

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: builder(context),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _Fade(animation: animation, child: child);
  }
}

/// Fades [child] with [animation], easing out in both directions, so the
/// page leaves as fast as it arrives rather than lingering at the start.
class _Fade extends StatefulWidget {
  const _Fade({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  State<_Fade> createState() => _FadeState();
}

class _FadeState extends State<_Fade> {
  late final CurvedAnimation _opacity = CurvedAnimation(
    parent: widget.animation,
    curve: Motion.easeOut,
    reverseCurve: Motion.easeOut.flipped,
  );

  @override
  void dispose() {
    _opacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}
