import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/src/models/sgpc_day.dart';

/// The current instant, behind a provider so a test can fix it.
///
/// Both daily features key on "now" (which Sikh date, which Hukamnama), and
/// both are wrong in the same way if the clock is wrong, so they read the same
/// seam. Read it with `ref.read(clockProvider)()`.
final clockProvider = Provider<DateTime Function()>((ref) => appClock());

/// A fixed date for a demo or a screenshot, never for a release:
/// `--dart-define=DEMO_TODAY=2026-11-03`. Release builds ignore it.
const kDemoToday = String.fromEnvironment('DEMO_TODAY');

/// The real clock, or in a debug or profile build with [kDemoToday] set, a
/// clock moved to that date. The time of day stays real, so the demo day
/// still ends at midnight.
DateTime Function() appClock() {
  final day = kReleaseMode ? null : DateTime.tryParse(kDemoToday);
  if (day == null) return DateTime.now;
  final now = DateTime.now();
  final shift = DateTime(day.year, day.month, day.day)
      .difference(DateTime(now.year, now.month, now.day));
  return () => DateTime.now().add(shift);
}

/// How long until SGPC's next day begins, counted from [now].
///
/// For a provider or a screen that must change exactly at midnight in
/// Amritsar. A second is added so the change lands after midnight, not on it.
Duration untilNextSgpcDay(DateTime now) {
  final india = now.toUtc().add(kIndiaOffset);
  // Midnight IST, written on the shifted clock, then moved back to real UTC.
  final nextMidnight = DateTime.utc(india.year, india.month, india.day + 1)
      .subtract(kIndiaOffset);
  return nextMidnight.difference(now.toUtc()) + const Duration(seconds: 1);
}

/// How long until the next whole minute, counted from [now].
///
/// For a clock on screen that must change when the real minute changes. The
/// India offset is a whole number of minutes, so the minute changes at the
/// same moment in Amritsar and in UTC.
Duration untilNextMinute(DateTime now) =>
    const Duration(minutes: 1) -
    Duration(
      seconds: now.second,
      milliseconds: now.millisecond,
      microseconds: now.microsecond,
    );

/// The wall clock in Amritsar at [now], wherever the phone is.
DateTime amritsarWallClock(DateTime now) => now.toUtc().add(kIndiaOffset);
