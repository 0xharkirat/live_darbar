import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:live_darbar/src/core/motion.dart';

/// Opens a bottom sheet with the app's motion.
///
/// Every small sheet in the app opens through this, so none can forget the
/// rules:
///
/// - The sheet moves on a spring ([Motion.sheet] in, [Motion.sheetExit] out),
///   not on a fixed curve, so it can start from wherever a finger left it.
/// - A finger that drags the sheet moves it 1:1, from any part of it. On
///   release the sheet takes the finger's speed: a flick down closes it, a
///   flick up keeps it open, and a slow drag closes it past the halfway mark.
///   Pulled up past its place, it resists and settles back.
/// - A list in the sheet hands over to the sheet: at the top of the list, a
///   swipe down moves the sheet, not the list. The list takes
///   [appSheetScrollController].
/// - A tap on the dimmed area closes it.
///
/// With [dismissible] false the sheet stays until the code closes it. A tap on
/// the dimmed area, a drag, a flick and the back button do nothing. It is for
/// a forced update, where the only way on is the store.
///
/// Under Reduce Motion the sheet does not slide in or out. It stays where it
/// ends and fades, in over [Motion.quick] and out over [Motion.press]. That
/// swaps the movement for a fade and keeps the feedback. A finger that drags
/// the sheet still moves it 1:1, because the finger does that, not the app.
Future<T?> showAppSheet<T>(
  BuildContext context,
  WidgetBuilder builder, {
  bool dismissible = true,
}) {
  return Navigator.of(context).push(
    AppSheetRoute<T>(
      builder: builder,
      dismissible: dismissible,
      barrierColor:
          Theme.of(context).bottomSheetTheme.modalBarrierColor ??
          Colors.black54,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      reduced: Motion.reduced(context),
    ),
  );
}

/// The scroll controller of the sheet that [context] is in, or null outside a
/// sheet.
///
/// Give it to the sheet's scroll view. When the view is at the top, a swipe
/// down on it then moves the sheet instead of bouncing the list, as it does in
/// a native sheet. A view with another controller still scrolls, but the
/// sheet does not take the swipe from it.
ScrollController? appSheetScrollController(BuildContext context) =>
    context.dependOnInheritedWidgetOfExactType<_AppSheetScope>()?.controller;

/// The route behind [showAppSheet].
class AppSheetRoute<T> extends PopupRoute<T> {
  AppSheetRoute({
    required this.builder,
    required this.barrierColor,
    required String barrierLabel,
    this.reduced = false,
    this.dismissible = true,
  }) : _barrierLabel = barrierLabel;

  final WidgetBuilder builder;

  /// Reduce Motion is on: the sheet fades and does not slide.
  final bool reduced;

  /// Whether the listener can close the sheet: by a tap on the dim, a drag, or
  /// the back button.
  final bool dismissible;

  final String _barrierLabel;

  /// The widest a sheet gets. On a wide window it stays a sheet, in the
  /// middle, and does not stretch across the screen.
  static const maxWidth = 640.0;

  // How far past the top a sheet can be pulled, and how hard it resists.
  static const _overdragResistance = 100.0;

  // A release past these closes the sheet: its speed in sheet heights per
  // second, or its place as a fraction of its height.
  static const _closeVelocity = 0.9;
  static const _closePosition = 0.5;

  @override
  final Color barrierColor;

  @override
  bool get barrierDismissible => dismissible;

  @override
  RoutePopDisposition get popDisposition =>
      dismissible ? super.popDisposition : RoutePopDisposition.doNotPop;

  @override
  String? get barrierLabel => _barrierLabel;

  /// Only the Reduce Motion fade has a duration. A spring has none, and these
  /// two are bounds for the rest.
  @override
  Duration get transitionDuration => reduced ? Motion.quick : Motion.standard;

  @override
  Duration get reverseTransitionDuration =>
      reduced ? Motion.press : Motion.quick;

  final _sheetKey = GlobalKey();

  /// The sheet's place: 1 is open, 0 is gone, and the controller's value is
  /// this. It runs past 1 while the sheet is pulled up. A spring drives it, so
  /// every move starts from where the sheet is and at the speed it has.
  @override
  AnimationController createAnimationController() {
    return AnimationController.unbounded(
      duration: transitionDuration,
      reverseDuration: reverseTransitionDuration,
      vsync: navigator!,
      debugLabel: 'AppSheet',
    );
  }

  /// The scrim and the fade read the place from 0 to 1, so a sheet pulled past
  /// open does not push them out of range.
  @override
  Animation<double>? get animation {
    final raw = super.animation;
    if (raw == null) return null;
    if (_clamped?.parent != raw) _clamped = _Clamped(raw);
    return _clamped;
  }

  _Clamped? _clamped;

  // The speed the finger had on release, in sheet heights per second, down
  // positive. The next simulation starts from it.
  double? _releaseVelocity;

  bool _popped = false;

  // With Reduce Motion the sheet stays in place until a finger moves it, and
  // then it follows the finger.
  bool _slid = false;

  @override
  Simulation? createSimulation({required bool forward}) {
    final from = controller!.value;
    final released = _releaseVelocity;
    _releaseVelocity = null;

    if (reduced) {
      return _Ramp(
        from: from,
        to: forward ? 1 : 0,
        duration: forward ? Motion.quick : Motion.press,
        curve: Motion.easeOut,
      );
    }
    final thrown = released != null && released.abs() >= Motion.flickSpeed;
    return SpringSimulation(
      forward
          ? (thrown ? Motion.sheetFlick : Motion.sheet)
          : Motion.sheetExit,
      from,
      forward ? 1 : 0,
      // The place falls as the sheet goes down, so down is negative.
      -(released ?? 0),
      snapToEnd: true,
    );
  }

  @override
  bool didPop(T? result) {
    _popped = true;
    return super.didPop(result);
  }

  @override
  void dispose() {
    _scrollController?.dispose();
    super.dispose();
  }

  double get _height {
    final size = _sheetKey.currentContext?.size;
    return size == null || size.height <= 0 ? 1 : size.height;
  }

  // A finger has the sheet: from the first move of a drag to its release. A
  // sheet that is only opening or settling is not held, and a scroll view
  // that lays out in the meantime must not stop it.
  bool _held = false;

  void _dragBy(double fraction) {
    if (_popped || !dismissible) return;
    final c = controller!;
    _held = true;
    _slid = true;
    var delta = fraction;
    if (c.value > 1) {
      // Past open, each point of finger moves the sheet less.
      delta /= 1 + (c.value - 1) * _overdragResistance;
    }
    c.value -= delta;
  }

  void _endDrag(double velocity) {
    // A tap on a button inside the sheet also ends in a cancelled drag.
    if (_popped || !_held) return;
    _held = false;
    final c = controller!;
    final value = c.value;

    if (value > 1) {
      // Pulled past open: settle back, with the finger's speed damped by the
      // same resistance that was applied while dragging.
      final damped = velocity / (1 + (value - 1) * _overdragResistance);
      _settle(Motion.sheet, value, -damped);
      return;
    }

    final close = switch (velocity) {
      > _closeVelocity => true,
      < -_closeVelocity => false,
      _ => value < _closePosition,
    };
    if (close) {
      _releaseVelocity = velocity;
      navigator?.pop();
    } else {
      final thrown = velocity.abs() >= Motion.flickSpeed;
      _settle(thrown ? Motion.sheetFlick : Motion.sheet, value, -velocity);
    }
  }

  /// Back to open, from [from] and at [velocity] (the place per second).
  void _settle(SpringDescription spring, double from, double velocity) {
    final c = controller!;
    c
        .animateWith(
          SpringSimulation(spring, from, 1, velocity, snapToEnd: true),
        )
        .whenCompleteOrCancel(() {
          if (!_popped && c.value == 1) _slid = false;
        });
  }

  // The scroll view's side of the hand-over, in points.
  void _dragByPixels(double down) => _dragBy(down / _height);
  void _endDragPixels(double downPerSecond) =>
      _endDrag(downPerSecond / _height);

  _SheetScrollController? _scrollController;

  _SheetScrollController get _scroll =>
      _scrollController ??= _SheetScrollController(this);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final media = MediaQuery.of(context);
    final maxHeight = math.max(0.0, media.size.height - media.padding.top);

    final sheet = GestureDetector(
      // The whole sheet takes the drag, even where its content is empty.
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onVerticalDragUpdate: (d) => _dragBy((d.primaryDelta ?? 0) / _height),
      onVerticalDragEnd: (d) =>
          _endDrag((d.primaryVelocity ?? 0) / _height),
      onVerticalDragCancel: () => _endDrag(0),
      child: SizedBox(
        key: _sheetKey,
        width: double.infinity,
        // Sheets draw their own surface. This only gives their text and
        // switches a Material to stand on.
        child: Material(
          type: MaterialType.transparency,
          child: _AppSheetScope(
            controller: _scroll,
            child: Builder(builder: builder),
          ),
        ),
      ),
    );

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: AnimatedBuilder(
          animation: controller!,
          child: sheet,
          builder: (context, child) {
            final place = controller!.value;
            // The translation is always in the tree, at 0 when the sheet only
            // fades. A widget that appears above the gesture detector in
            // the middle of a drag would rebuild it and drop the finger.
            Widget out = FractionalTranslation(
              translation: Offset(0, !reduced || _slid ? 1 - place : 0),
              child: child,
            );
            if (reduced) {
              out = Opacity(
                opacity: Motion.easeOut.transform(place.clamp(0.0, 1.0)),
                child: out,
              );
            }
            return out;
          },
        ),
      ),
    );
  }
}

class _AppSheetScope extends InheritedWidget {
  const _AppSheetScope({required this.controller, required super.child});

  final ScrollController controller;

  @override
  bool updateShouldNotify(_AppSheetScope oldWidget) =>
      controller != oldWidget.controller;
}

/// The controller that lets a list in a sheet hand its swipe to the sheet.
class _SheetScrollController extends ScrollController {
  _SheetScrollController(this._route);

  final AppSheetRoute<dynamic> _route;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _SheetScrollPosition(
      _route,
      physics: physics,
      context: context,
      oldPosition: oldPosition,
    );
  }
}

/// A scroll position that gives the sheet the swipe the list cannot use.
///
/// At the top of the list, a finger moving down pulls the sheet down. Once
/// the finger has the sheet it keeps it, up or down, until it lets go. On
/// release the sheet takes the finger's speed, and the list does not coast.
class _SheetScrollPosition extends ScrollPositionWithSingleContext {
  _SheetScrollPosition(
    this._route, {
    required super.physics,
    required super.context,
    super.oldPosition,
  });

  final AppSheetRoute<dynamic> _route;

  @override
  void applyUserOffset(double delta) {
    // A positive delta is a finger moving down.
    if (_route._held || (pixels <= minScrollExtent && delta > 0)) {
      _route._dragByPixels(delta);
      return;
    }
    super.applyUserOffset(delta);
  }

  @override
  void goBallistic(double velocity) {
    if (_route._held) {
      // The scroll view waits for this call to end its drag, so the list goes
      // idle first. Its velocity is positive when the content moves up, which
      // is a finger moving up. The sheet wants it the other way.
      goIdle();
      _route._endDragPixels(-velocity);
      return;
    }
    super.goBallistic(velocity);
  }
}

/// The route's value, held between 0 and 1.
class _Clamped extends Animation<double> with AnimationWithParentMixin<double> {
  _Clamped(this.parent);

  @override
  final Animation<double> parent;

  @override
  double get value => parent.value.clamp(0.0, 1.0);
}

/// A move from [from] to [to] over [duration], on [curve]. It is how a timed
/// fade runs on the same controller as the spring. A simulation is not slowed
/// to 5% by Reduce Motion the way a timed animation is, so the fade is seen.
class _Ramp extends Simulation {
  _Ramp({
    required this.from,
    required this.to,
    required this.duration,
    required this.curve,
  });

  final double from;
  final double to;
  final Duration duration;
  final Curve curve;

  double get _seconds => duration.inMicroseconds / 1e6;

  @override
  double x(double time) {
    final t = (time / _seconds).clamp(0.0, 1.0);
    return from + (to - from) * curve.transform(t);
  }

  @override
  double dx(double time) {
    const step = 1e-3;
    return (x(time + step) - x(math.max(0, time - step))) / (2 * step);
  }

  @override
  bool isDone(double time) => time >= _seconds;
}
