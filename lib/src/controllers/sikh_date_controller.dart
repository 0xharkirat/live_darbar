import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/src/core/clock.dart';
import 'package:live_darbar/src/models/sgpc_day.dart';
import 'package:live_darbar/src/models/sikh_date.dart';

// Still importable from here, where it was first published.
export 'package:live_darbar/src/core/clock.dart' show untilNextSgpcDay;

/// The bundled table of SGPC month starts. See the file for its sources.
const kSangrandAsset = 'assets/data/sgpc_sangrands.json';

/// The month starts, or null when the asset cannot be read.
///
/// A broken asset is a build mistake, not something a listener can fix, and
/// the date line is a courtesy. So this answers null and the screen shows the
/// Gregorian date alone, the same as for a day outside the table.
final sangrandTableProvider = FutureProvider<SangrandTable?>((ref) async {
  try {
    return SangrandTable.fromJsonString(
      await rootBundle.loadString(kSangrandAsset),
    );
  } catch (e) {
    if (!kReleaseMode) debugPrint('[sikh date] table unusable: $e');
    return null;
  }
});

/// The Sikh date for today at Darbar Sahib, or null when it cannot be known.
///
/// "Today" is SGPC's day (India time), not the phone's. Someone in Vancouver
/// at 20:00 is already in tomorrow at Amritsar, and the Hukamnama and the
/// date label must agree with each other.
///
/// The provider moves to the next day by itself: it invalidates itself at the
/// next midnight in Amritsar, so an app left open overnight shows the new date
/// without a resume. A phone that sleeps through midnight fires the timer when
/// it wakes, and a screen can still invalidate on resume to be sure.
final sikhDateProvider = FutureProvider<SikhDate?>((ref) async {
  // The timer and the day come from one reading of the clock, taken before
  // the first await so they cannot disagree and so a provider disposed while
  // the table loads has nothing left to register.
  final now = ref.read(clockProvider)();
  final rollover = Timer(untilNextSgpcDay(now), ref.invalidateSelf);
  ref.onDispose(rollover.cancel);

  final table = await ref.watch(sangrandTableProvider.future);
  return table?.sikhDateFor(sgpcDayOf(now));
});
