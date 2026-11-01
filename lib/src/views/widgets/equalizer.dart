import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:live_darbar/src/core/motion.dart';
import 'package:live_darbar/src/core/palette.dart';

/// Three bars that move while sound is playing.
///
/// It is the "audio is flowing" signal, and it is the only thing in the app
/// that loops. It stops dead when playback stops, so motion always means
/// sound. Under Reduce Motion the bars hold still at mixed heights: still
/// recognisable, no movement.
class Equalizer extends StatefulWidget {
  const Equalizer({
    super.key,
    required this.active,
    this.color = Palette.gold,
    this.height = 14,
  });

  final bool active;
  final Color color;
  final double height;

  @override
  State<Equalizer> createState() => _EqualizerState();
}

class _EqualizerState extends State<Equalizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(Equalizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final run = widget.active && !Motion.reduced(context);
    if (run && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!run && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: Size(13, widget.height),
          painter: _BarsPainter(
            t: _controller.value,
            active: widget.active,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({required this.t, required this.active, required this.color});

  final double t;
  final bool active;
  final Color color;

  static const _rest = [0.45, 0.8, 0.6];
  static const _phase = [0.0, 0.33, 0.66];
  static const _speed = [1.0, 2.0, 1.0];

  @override
  void paint(Canvas canvas, Size size) {
    const barWidth = 3.0;
    const gap = 2.0;
    final paint = Paint()..color = color;
    for (var i = 0; i < 3; i++) {
      final wave = 0.5 + 0.5 * math.sin((t * _speed[i] + _phase[i]) * 2 * math.pi);
      final f = active ? 0.3 + 0.7 * wave : _rest[i] * 0.6;
      final h = size.height * f;
      final x = i * (barWidth + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - h, barWidth, h),
          const Radius.circular(1.5),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.t != t || old.active != active || old.color != color;
}
