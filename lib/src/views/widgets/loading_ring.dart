import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/core/motion.dart';
import 'package:live_darbar/src/core/palette.dart';

/// The 1 ring that says "loading" in the app.
///
/// It is thin and gold, a faint ring with a short bright arc that turns, not
/// Material's wide spinner. It shows nothing for [delay] and then fades in, so
/// a load that ends inside the delay leaves no flicker. Most do: a recording
/// that opens in 200 ms should not draw a spinner for 200 ms.
///
/// It keeps its [size] before it shows, so what is beside it does not move
/// when it arrives. It turns under Reduce Motion too, because it is the only
/// sign that something is happening, but its fade in is then as short as
/// Flutter makes any fade.
///
/// A screen reader hears "Loading" in the listener's language, from the first
/// moment, as the picture is not what it relies on. Where the words beside the
/// ring already say what is happening, pass `announce: false`.
class LoadingRing extends StatefulWidget {
  const LoadingRing({
    super.key,
    required this.size,
    this.color = Palette.gold,
    this.strokeWidth = 1.5,
    this.delay = Motion.ringDelay,
    this.announce = true,
  });

  final double size;
  final Color color;
  final double strokeWidth;

  /// How long it shows nothing.
  final Duration delay;

  /// Whether a screen reader says "Loading" for it.
  final bool announce;

  @override
  State<LoadingRing> createState() => _LoadingRingState();
}

class _LoadingRingState extends State<LoadingRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  Timer? _timer;
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (!mounted) return;
      setState(() => _shown = true);
      _turn.repeat();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget ring = AnimatedOpacity(
      opacity: _shown ? 1 : 0,
      duration: Motion.quick,
      curve: Motion.easeOut,
      child: RotationTransition(
        turns: _turn,
        child: CustomPaint(
          painter: _RingPainter(
            color: widget.color,
            strokeWidth: widget.strokeWidth,
          ),
        ),
      ),
    );
    ring = RepaintBoundary(
      child: SizedBox.square(dimension: widget.size, child: ring),
    );

    if (!widget.announce) return ExcludeSemantics(child: ring);
    return Semantics(
      label: AppLocalizations.of(context)!.loading,
      child: ring,
    );
  }
}

/// A faint ring, and on it an arc of a quarter turn, with round ends.
class _RingPainter extends CustomPainter {
  const _RingPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      paint..color = color.withValues(alpha: 0.18),
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi / 2,
      false,
      paint..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}
