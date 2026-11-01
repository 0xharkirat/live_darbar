import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// Every curve, duration and spring in the app, in one place.
///
/// The rules behind the numbers:
///
/// - Things that respond to a finger respond on touch-down, within 120 ms.
/// - Entering and exiting UI eases out: it starts fast, so the response is
///   visible in the first frame, which is the frame people are watching.
/// - Nothing here takes longer than 300 ms except the sheet, which is a
///   spring and has no fixed duration.
/// - Anything a finger can drag is a spring, because a spring starts from
///   wherever the thing is now and keeps the finger's velocity.
/// - Reduce Motion swaps movement for a short fade. It does not remove
///   feedback.
abstract final class Motion {
  /// Strong ease-out for UI that enters, exits or responds.
  static const easeOut = Cubic(0.23, 1, 0.32, 1);

  /// Strong ease-in-out for something moving from one place to another.
  static const easeInOut = Cubic(0.77, 0, 0.175, 1);

  /// The iOS sheet curve, for the rare sheet move that is not a spring.
  static const drawer = Cubic(0.32, 0.72, 0, 1);

  static const press = Duration(milliseconds: 120);
  static const quick = Duration(milliseconds: 180);
  static const standard = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 300);

  /// How far a pressed card sinks. Subtle enough to feel physical.
  static const pressScale = 0.97;

  /// The sheet spring. Critically damped by default: it settles without
  /// overshoot when it was not thrown.
  static final sheet = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 380),
  );

  /// The same sheet, but thrown: a little bounce, only because a flick
  /// preceded it.
  static final sheetFlick = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 380),
    bounce: 0.12,
  );

  /// Artwork growing and shrinking with play and pause.
  static final artwork = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 450),
    bounce: 0.18,
  );

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// A spring, sampled as a [Curve], for implicit animations.
///
/// Implicit widgets such as [AnimatedScale] take a duration and a curve, not a
/// physics simulation. This runs the spring once from 0 to 1 and plays it back
/// over [duration], which keeps the overshoot and settle of the real thing.
/// Use it with a duration that matches the spring's own.
class SpringCurve extends Curve {
  SpringCurve(this.spring, {this.duration = const Duration(milliseconds: 450)})
      : _simulation = SpringSimulation(spring, 0, 1, 0);

  final SpringDescription spring;
  final Duration duration;
  final SpringSimulation _simulation;

  @override
  double transformInternal(double t) {
    if (t >= 1) return 1;
    return _simulation.x(t * duration.inMicroseconds / 1e6);
  }
}
