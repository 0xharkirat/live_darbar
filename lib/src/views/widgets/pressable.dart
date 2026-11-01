import 'package:flutter/material.dart';
import 'package:live_darbar/src/core/motion.dart';

/// Anything tappable that is bigger than an icon.
///
/// It sinks to 97% on touch-down, not on release, so the screen answers the
/// finger in the same frame. Release springs back slightly slower than the
/// press, because the press is the person acting and the release is the
/// interface settling. Drag off the target and it lifts again without firing,
/// the way a real button does.
///
/// Under Reduce Motion the scale becomes a small dim: the feedback stays, the
/// movement goes.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.semanticLabel,
    this.scale = Motion.pressScale,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final reduced = Motion.reduced(context);
    final pressed = _down && enabled;

    Widget child = widget.child;
    child = reduced
        ? AnimatedOpacity(
            opacity: pressed ? 0.7 : 1,
            duration: Motion.press,
            curve: Motion.easeOut,
            child: child,
          )
        : AnimatedScale(
            scale: pressed ? widget.scale : 1,
            duration: pressed ? Motion.press : Motion.quick,
            curve: Motion.easeOut,
            child: child,
          );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
          child: child,
        ),
      ),
    );
  }
}
