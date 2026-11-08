import 'package:flutter/foundation.dart';
import 'package:live_darbar/src/models/hukamnama.dart';
import 'package:live_darbar/src/models/sgpc_day.dart';
import 'package:live_darbar/src/services/hukamnama_cache.dart';
import 'package:live_darbar/src/services/hukamnama_service.dart';

/// The newest text the service has for [today], stored on disk.
///
/// Today's if it is posted, else yesterday's. When [have] is given it is the
/// fallback for every failure, so this only throws when there is nothing to
/// show. It also skips asking for yesterday when [have] is already
/// yesterday's or newer, so an app opened at 03:00 IST does not make a second
/// request to learn what it holds.
///
/// This is the one place that decides what to ask for. The Hukamnama
/// controller uses it while the app is open, and the home screen widget's
/// background refresh uses it while the app is closed, so the two cannot
/// disagree about which day's text is the best one.
Future<Hukamnama> loadLatestHukamnama({
  required HukamnamaService service,
  required HukamnamaCache cache,
  required DateTime today,
  Hukamnama? have,
}) async {
  final yesterday = previousSgpcDay(today);

  try {
    try {
      final fresh = await service.fetch(today);
      await cache.write(fresh);
      return fresh;
    } on HukamnamaNotPublishedException {
      // A copy with no line meanings is asked for once more: one saved before
      // the apps read the mirror has none, and the mirror may have them now.
      // Once a copy has them, this is 1 request, as it was.
      if (have != null &&
          !have.date.isBefore(yesterday) &&
          have.shabad != null) {
        return have;
      }
      final fresh = await service.fetch(yesterday);
      await cache.write(fresh);
      return fresh;
    }
  } catch (e) {
    // Offline, a timeout, or an answer that could not be read.
    if (have == null) rethrow;
    if (!kReleaseMode) debugPrint('[hukamnama] keeping ${have.date}: $e');
    return have;
  }
}
