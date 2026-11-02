import 'package:flutter/material.dart';
import 'package:live_darbar/src/core/motion.dart';

/// Opens a bottom sheet with the app's motion.
///
/// Flutter's own defaults slide in over 250 ms and out over 200 ms, and both
/// directions use a decelerate curve. Run backwards, that curve starts slow, so
/// a dismissal feels like ease-in. Here the sheet enters on the iOS drawer
/// curve over [Motion.standard] and leaves on its mirror over [Motion.quick],
/// which starts fast in both directions.
///
/// Under Reduce Motion the sheet does not move. It stays where it ends and its
/// content fades, in over [Motion.quick] and out over [Motion.press]. That
/// swaps the movement for a fade and keeps the feedback. A finger that drags
/// the sheet still moves it 1:1, because the finger does that, not the app.
///
/// Every sheet in the app opens through this, so none can forget the rule.
Future<T?> showAppSheet<T>(BuildContext context, WidgetBuilder builder) {
  if (!Motion.reduced(context)) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: _style,
      builder: builder,
    );
  }

  // When Reduce Motion is on, Flutter runs every [AnimationController] at 5%
  // of its length, so a sheet would swap in within a frame, with no fade at
  // all. This controller opts out, so the fade below is a real one.
  final controller = AnimationController(
    vsync: Navigator.of(context),
    duration: _reducedStyle.duration,
    reverseDuration: _reducedStyle.reverseDuration,
    animationBehavior: AnimationBehavior.preserve,
    debugLabel: 'AppSheet',
  );

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    sheetAnimationStyle: _reducedStyle,
    transitionAnimationController: controller,
    builder: (context) =>
        _SheetFade(controller: controller, child: builder(context)),
  );
}

final _style = AnimationStyle(
  duration: Motion.standard,
  reverseDuration: Motion.quick,
  curve: Motion.drawer,
  reverseCurve: Motion.drawer.flipped,
);

/// Jumps to "fully in place" as soon as the route starts, so the sheet never
/// slides. The route's own animation still runs, and [_SheetFade] reads it.
const _inPlace = Threshold(0);

const _reducedStyle = AnimationStyle(
  duration: Motion.quick,
  reverseDuration: Motion.press,
  curve: _inPlace,
  reverseCurve: _inPlace,
);

/// Fades the sheet with the route's animation, easing out in both directions.
///
/// It also owns [controller]: the route does not dispose a controller it was
/// given, and this widget leaves the tree exactly when the sheet is gone.
class _SheetFade extends StatefulWidget {
  const _SheetFade({required this.controller, required this.child});

  final AnimationController controller;
  final Widget child;

  @override
  State<_SheetFade> createState() => _SheetFadeState();
}

class _SheetFadeState extends State<_SheetFade> {
  CurvedAnimation? _opacity;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opacity != null) return;
    _opacity = CurvedAnimation(
      parent: ModalRoute.of(context)!.animation!,
      curve: Motion.easeOut,
      reverseCurve: Motion.easeOut.flipped,
    );
  }

  @override
  void dispose() {
    _opacity?.dispose();
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _opacity!, child: widget.child);
  }
}
