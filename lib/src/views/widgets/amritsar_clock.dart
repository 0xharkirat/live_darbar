import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/clock.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/views/widgets/clock_label.dart';
import 'package:live_darbar/src/views/widgets/on_image_chip.dart';

/// The time now in Amritsar, for the Live Kirtan card: "7:43 PM in Amritsar".
///
/// A listener abroad reads it to know which part of the day's programme
/// plays now. It is [clockProvider] moved to India time, so the phone's own
/// time zone never changes it. The hours follow [uses24HourClock], as the
/// reminder does: the phone's 12 or 24 hour setting in English, and always
/// 24-hour in Punjabi.
///
/// It changes when the real minute changes. A page over Home, or the app in
/// the background, stops the timer, and the time is right at once when Home
/// comes back. Home scrolled down keeps the timer: 1 rebuild a minute.
class AmritsarClock extends ConsumerStatefulWidget {
  const AmritsarClock({super.key});

  @override
  ConsumerState<AmritsarClock> createState() => AmritsarClockState();
}

class AmritsarClockState extends ConsumerState<AmritsarClock>
    with WidgetsBindingObserver {
  Timer? _tick;

  /// The minute on screen, in minutes since the epoch.
  int? _shown;

  bool _foreground = _inFront(WidgetsBinding.instance.lifecycleState);
  bool _onScreen = true;

  /// Whether a timer waits for the next minute. False while a page covers
  /// Home or the app is in the background.
  @visibleForTesting
  bool get isTicking => _tick != null;

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
    // A route over Home turns tickers off below it; the clock follows. A
    // rebuild follows this call, so the time is right when Home comes back.
    _onScreen = TickerMode.valuesOf(context).enabled;
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = _inFront(state);
    if (foreground == _foreground) return;
    _foreground = foreground;
    _schedule();
    if (foreground) _refresh();
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
      // A timer that fires a little early finds the same minute and draws
      // nothing. The next one waits only for what is left of the minute.
      _refresh();
      _schedule();
    });
  }

  /// Rebuilds only when the minute on screen is out of date, so a clock that
  /// stands still (a test's, or a demo's) asks for no frames.
  void _refresh() {
    final now = ref.read(clockProvider)();
    if (now.millisecondsSinceEpoch ~/ Duration.millisecondsPerMinute !=
        _shown) {
      setState(() {});
    }
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
    final now = ref.watch(clockProvider)();
    _shown = now.millisecondsSinceEpoch ~/ Duration.millisecondsPerMinute;
    final there = amritsarWallClock(now);
    final time = clockLabel(context, there.hour, there.minute);

    final style = AppType.eyebrow.copyWith(
      color: Palette.foreground.withValues(alpha: 0.78),
      fontWeight: FontWeight.w500,
      // The width holds still as the minutes change.
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    // Its own stop for the screen reader, inside the Live Kirtan button, so
    // the button's label stays "Live Kirtan".
    return Semantics(
      container: true,
      label: l10n.amritsar_time_now_semantics(time),
      excludeSemantics: true,
      child: OnImageChip(
        child: Text(
          l10n.amritsar_time_now(time),
          maxLines: 1,
          softWrap: false,
          style: style,
          // Gurmukhi words with Latin digits mix 2 fonts, and the line grew
          // 1 point taller than the LIVE badge beside it. The strut holds the
          // line at the badge's height; the vowel signs still draw in full.
          strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
        ),
      ),
    );
  }
}
