import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/src/models/sgpc_day.dart';

/// The current instant, behind a provider so a test can fix it.
///
/// Both daily features key on "now" (which Sikh date, which Hukamnama), and
/// both are wrong in the same way if the clock is wrong, so they read the same
/// seam. Read it with `ref.read(clockProvider)()`.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

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
