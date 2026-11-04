import 'dart:math' as math;

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

  /// How long the loading ring shows nothing. A load that ends inside it
  /// leaves no flicker, and most do.
  static const ringDelay = Duration(milliseconds: 300);

  /// How far a pressed card sinks. Subtle enough to feel physical.
  static const pressScale = 0.97;

  /// Where something small starts when it enters, and where it ends when it
  /// leaves, with a fade. Nothing in the real world comes from nothing, so it
  /// is never 0, and a swap this small needs no more than 5%.
  static const enterScale = 0.95;

  /// A pressed target sinking to [pressScale]. Critically damped: it settles
  /// without a bounce, and is most of the way down in 120 ms, so the screen
  /// answers the finger in the frame it lands.
  static final pressSpring = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 150),
  );

  /// The same target coming back up. A little bounce, because the finger has
  /// let go and the thing is free: it springs past 100% by a hair and rests.
  static final releaseSpring = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 300),
    bounce: 0.3,
  );

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

  /// The sheet leaving. Faster than it came, because the listener has decided
  /// and is waiting for the screen. Critically damped: a sheet that is going
  /// away has nothing to bounce against.
  static final sheetExit = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 240),
  );

  /// The speed, in sheet heights per second, from which a release counts as
  /// thrown. Under it a sheet settles on [sheet]. At or over it the finger gave
  /// the sheet momentum, and it settles on [sheetFlick].
  static const flickSpeed = 0.5;

  /// Artwork growing and shrinking with play and pause.
  static final artwork = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 450),
    bounce: 0.18,
  );

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// A spring that a route draws through a [Curve], played back as the spring.
///
/// Some routes pass their controller through a curve before they draw. The
/// Cupertino sheet does: `fastEaseInToSlowEaseOut`, which is 99% of the way
/// after the first half of the controller. A spring on that controller would
/// reach the top in under 100 ms and lose the finger's speed in the warp.
/// This feeds the controller the value that the curve turns back into
/// [spring]'s own, so the sheet on screen follows the spring, and the speed
/// of the finger is the speed at which it starts.
///
/// [spring] runs in screen space: its value is how far the sheet has come, and
/// its velocity is in sheet heights per second.
class SpringThroughCurve extends Simulation {
  SpringThroughCurve(this.spring, this.curve)
      : super(tolerance: spring.tolerance);

  final SpringSimulation spring;
  final Curve curve;

  /// The controller value whose curve value is [y]. The curves in use rise
  /// from 0 to 1, so a bisection finds it.
  double _inverse(double y) {
    if (y <= 0) return 0;
    if (y >= 1) return 1;
    var low = 0.0;
    var high = 1.0;
    for (var i = 0; i < 24; i++) {
      final mid = (low + high) / 2;
      if (curve.transform(mid) < y) {
        low = mid;
      } else {
        high = mid;
      }
    }
    return (low + high) / 2;
  }

  @override
  double x(double time) => _inverse(spring.x(time));

  @override
  double dx(double time) {
    const step = 1e-3;
    final before = math.max(0.0, time - step);
    return (x(time + step) - x(before)) / (time + step - before);
  }

  @override
  bool isDone(double time) => spring.isDone(time);
}
