import 'package:live_darbar/src/models/sgpc_day.dart';

/// Which day's content a resolved URL actually holds.
///
/// This exists so the UI never has to guess. The app asks for today, and quite
/// often today is not up yet, and the difference between those two is
/// something the listener is entitled to know before they wonder why the
/// shabad does not match the one they heard this morning.
enum DailyFreshness {
  /// Today's file, on SGPC's calendar, confirmed to exist.
  today,

  /// Today's is not published yet, so this is the day before.
  previousDay,

  /// The fixed URL that SGPC overwrites in place.
  ///
  /// Always the newest thing they have, and therefore never *worse* than the
  /// dated file we were reaching for. But it carries no date, so we cannot
  /// claim which day it is and must not pretend otherwise.
  latest,
}

/// A daily asset, resolved to something that will actually load.
class DailyEdition {
  const DailyEdition({
    required this.asset,
    required this.url,
    required this.freshness,
    this.day,
  });

  /// Where the app should point the player, no further checks needed.
  final String url;

  final DailyAsset asset;

  final DailyFreshness freshness;

  /// The SGPC day this content belongs to, or null for [DailyFreshness.latest]
  /// where the day is genuinely unknown.
  final DateTime? day;

  /// Whether the listener is hearing a day older than the one they asked for.
  ///
  /// [DailyFreshness.latest] is not stale. It is undated, which is a different
  /// thing: there is nothing true to tell the listener about it, so telling
  /// them nothing is the honest option.
  bool get isStale => freshness == DailyFreshness.previousDay;

  /// The fallback when nothing could be confirmed.
  factory DailyEdition.latest(DailyAsset asset) => DailyEdition(
        asset: asset,
        url: asset.latestUrl,
        freshness: DailyFreshness.latest,
      );

  @override
  String toString() {
    final on = day == null ? 'undated' : sgpcDayIso(day!);
    return 'DailyEdition(${asset.name}, ${freshness.name}, $on)';
  }
}
