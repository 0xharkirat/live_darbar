import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/clock.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/views/widgets/live_badge.dart';

/// The time now in Amritsar, for the Live Kirtan card: "7:43 PM in Amritsar".
///
/// A listener abroad reads it to know which part of the day's programme
/// plays now. It is [clockProvider] moved to India time, so the phone's own
/// time zone never changes it. The hours follow the phone's 12 or 24 hour
/// setting.
///
/// It changes when the real minute changes, and only while someone can see
/// it. A page over Home, or the app in the background, stops the timer. When
/// Home comes back, the time is right at once.
class AmritsarClock extends ConsumerStatefulWidget {
  const AmritsarClock({super.key});

  @override
  ConsumerState<AmritsarClock> createState() => _AmritsarClockState();
}

class _AmritsarClockState extends ConsumerState<AmritsarClock>
    with WidgetsBindingObserver {
  Timer? _tick;

  bool _foreground = _inFront(WidgetsBinding.instance.lifecycleState);
  bool _onScreen = true;

  /// Whether the app can be seen. Inactive still shows the app, under the
  /// control centre or in the app switcher. No report yet counts as in front.
  static bool _inFront(AppLifecycleState? state) => switch (state) {
        AppLifecycleState.hidden ||
        AppLifecycleState.paused ||
        AppLifecycleState.detached =>
          false,
        _ => true,
      };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A route over Home turns tickers off below it; the clock follows.
    _onScreen = TickerMode.valuesOf(context).enabled;
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = _inFront(state);
    if (foreground == _foreground) return;
    _foreground = foreground;
    _schedule();
    if (foreground) setState(() {});
  }

  /// Sets 1 timer for the next whole minute, or none while nobody can see
  /// the clock.
  void _schedule() {
    _tick?.cancel();
    _tick = null;
    if (!_foreground || !_onScreen) return;
    final now = ref.read(clockProvider)();
    _tick = Timer(untilNextMinute(now), () {
      if (!mounted) return;
      setState(() {});
      // A timer that fires a little early finds the same minute, and the
      // next one waits only for what is left of it.
      _schedule();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final there = amritsarWallClock(ref.watch(clockProvider)());
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: there.hour, minute: there.minute),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

    return Semantics(
      container: true,
      label: l10n.amritsar_time_now_semantics(time),
      excludeSemantics: true,
      child: OnImageChip(
        child: Text(
          l10n.amritsar_time_now(time),
          maxLines: 1,
          softWrap: false,
          style: AppType.eyebrow.copyWith(
            color: Palette.foreground.withValues(alpha: 0.78),
            fontWeight: FontWeight.w500,
            // The width holds still as the minutes change.
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
