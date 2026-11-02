import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/models/daily_edition.dart';
import 'package:live_darbar/src/models/sgpc_day.dart';

void main() {
  group('DailyEdition', () {
    test('today is not stale', () {
      final edition = DailyEdition(
        asset: DailyAsset.hukamnama,
        url: DailyAsset.hukamnama.urlFor(DateTime.utc(2026, 8, 12)),
        freshness: DailyFreshness.today,
        day: DateTime.utc(2026, 8, 12),
      );
      expect(edition.isStale, isFalse);
    });

    test('the previous day is stale, so the UI says so', () {
      final edition = DailyEdition(
        asset: DailyAsset.katha,
        url: DailyAsset.katha.urlFor(DateTime.utc(2026, 8, 11)),
        freshness: DailyFreshness.previousDay,
        day: DateTime.utc(2026, 8, 11),
      );
      expect(edition.isStale, isTrue);
    });

    test('the undated URL is not stale, because it is the newest there is', () {
      // It carries no date, so there is nothing true to tell the listener.
      // Calling it stale would be a claim the app cannot support.
      final edition = DailyEdition.latest(DailyAsset.hukamnama);
      expect(edition.isStale, isFalse);
      expect(edition.day, isNull);
      expect(edition.url, DailyAsset.hukamnama.latestUrl);
      expect(edition.freshness, DailyFreshness.latest);
    });
  });
}
