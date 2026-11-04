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
