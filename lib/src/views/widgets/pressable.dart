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
/// A small target barely moves at 97%: a 32 point circle shrinks by 1 point.
/// Put a [PressFill] inside it and the surface also eases to a lighter colour,
/// a change the thumb does not hide. A row that sits in a group takes [scale]
/// 1 and the fill alone.
///
/// Under Reduce Motion the scale becomes a small dim: the feedback stays, the
/// movement goes. With no scale there is no movement to swap, so the fill is
/// all the feedback and nothing dims.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.semanticLabel,
    this.semanticValue,
    this.selected,
    this.inMutuallyExclusiveGroup = false,
    this.scale = Motion.pressScale,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// What the screen reader says. When it is set, hide the visible text from
  /// the reader (with [ExcludeSemantics]) or the text is read a second time.
  final String? semanticLabel;

  /// The current setting of a control, which the screen reader says after the
  /// label: "Sound quality, Automatic".
  final String? semanticValue;

  /// Whether this is the chosen one of several, for the screen reader. Null
  /// means the target is not a choice and has no selected state.
  final bool? selected;

  /// Set on each target of a group of which exactly one is [selected].
  final bool inMutuallyExclusiveGroup;
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
  void didUpdateWidget(Pressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A target turned off mid-press never gets its release.
    if (widget.onTap == null) _down = false;
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final reduced = Motion.reduced(context);
    final pressed = _down && enabled;

    Widget child = widget.child;
    child = _PressScope(pressed: pressed, child: child);
    child = reduced
        ? (widget.scale < 1
            ? AnimatedOpacity(
                opacity: pressed ? 0.7 : 1,
                duration: Motion.press,
                curve: Motion.easeOut,
                child: child,
              )
            : child)
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
      value: widget.semanticValue,
      selected: widget.selected,
      inMutuallyExclusiveGroup: widget.inMutuallyExclusiveGroup,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        // Null when off: any tap handler makes a recognizer, and a recognizer
        // gives the screen reader a tap action on a button that is disabled.
        onTapCancel: enabled ? () => _set(false) : null,
        onTap: widget.onTap,
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
          child: child,
        ),
      ),
    );
  }
}

/// Tells [PressFill] whether the [Pressable] around it is held.
class _PressScope extends InheritedWidget {
  const _PressScope({required this.pressed, required super.child});

  final bool pressed;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PressScope>()?.pressed ??
      false;

  @override
  bool updateShouldNotify(_PressScope oldWidget) =>
      pressed != oldWidget.pressed;
}

/// A surface that eases to [pressedColor] while the [Pressable] around it is
/// held: in over [Motion.press] on touch-down, out over [Motion.quick] on
/// release, on [Motion.easeOut].
///
/// With no [color] it is clear when idle, in the same hue as [pressedColor] so
/// the fade does not pass through black. Give [shape] to round it; the default
/// is a plain rectangle, for a row that an outer clip rounds.
///
/// It animates the colour alone and paints the shape's border inside its own
/// bounds, as a [DecoratedBox] does, so [child] keeps the full size.
class PressFill extends StatelessWidget {
  const PressFill({
    super.key,
    required this.pressedColor,
    this.color,
    this.shape = const RoundedRectangleBorder(),
    this.child,
  });

  final Color pressedColor;
  final Color? color;
  final ShapeBorder shape;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final pressed = _PressScope.of(context);
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(
        end: pressed ? pressedColor : color ?? pressedColor.withAlpha(0),
      ),
      duration: pressed ? Motion.press : Motion.quick,
      curve: Motion.easeOut,
      child: child,
      builder: (context, fill, child) => DecoratedBox(
        decoration: ShapeDecoration(color: fill, shape: shape),
        child: child,
      ),
    );
  }
}
