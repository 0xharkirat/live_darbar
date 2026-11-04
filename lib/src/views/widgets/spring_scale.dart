import 'package:flutter/widgets.dart';
import 'package:flutter/physics.dart';
import 'package:live_darbar/src/core/motion.dart';

/// Scales [child] to [scale] on a spring.
///
/// An implicit widget such as [AnimatedScale] restarts from rest each time its
/// target changes, so a target that flips mid-move turns at once, with a seam.
/// This one starts each new spring from where the scale is and at the speed it
/// has, so the move stays continuous however often the target changes.
///
/// Under Reduce Motion the scale jumps. It is the size that carries the
/// meaning, not the way it arrives.
class SpringScale extends StatefulWidget {
  const SpringScale({
    super.key,
    required this.scale,
    required this.spring,
    required this.child,
  });

  final double scale;

  /// A token from [Motion].
  final SpringDescription spring;

  final Widget child;

  @override
  State<SpringScale> createState() => _SpringScaleState();
}

class _SpringScaleState extends State<SpringScale>
    with SingleTickerProviderStateMixin {
  /// The controller's value is the scale, so a spring can run on it from the
  /// current value and speed.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: widget.scale,
    lowerBound: 0,
    upperBound: 2,
  );

  @override
  void didUpdateWidget(SpringScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scale != widget.scale) _retarget();
  }

  void _retarget() {
    if (Motion.reduced(context)) {
      _controller.value = widget.scale;
      return;
    }
    _controller.animateWith(
      SpringSimulation(
        widget.spring,
        _controller.value,
        widget.scale,
        _controller.velocity,
        // At rest the scale is exactly the target, not 0.9995 of it, which
        // would soften the edges of everything inside.
        snapToEnd: true,
        tolerance: const Tolerance(distance: 0.0005, velocity: 0.005),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _controller, child: widget.child);
  }
}
