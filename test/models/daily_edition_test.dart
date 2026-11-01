import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/models/daily_edition.dart';
import 'package:live_darbar/src/models/mukhwak_document.dart';
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

  group('MukhwakDocument cache names', () {
    test('a dated name carries the day the content belongs to', () {
      expect(
        MukhwakDocument.datedFileName(DateTime.utc(2026, 8, 12)),
        'mukhwak_day_2026_08_12.pdf',
      );
    });

    test('an undated name carries the day it was fetched on', () {
      expect(
        MukhwakDocument.latestFileName(DateTime.utc(2026, 8, 12)),
        'mukhwak_latest_2026_08_12.pdf',
      );
    });

    test('the two never collide, so one is never mistaken for the other', () {
      final day = DateTime.utc(2026, 8, 12);
      expect(
        MukhwakDocument.datedFileName(day),
        isNot(MukhwakDocument.latestFileName(day)),
      );
    });

    test('both are swept by the shared prefix', () {
      final day = DateTime.utc(2026, 8, 12);
      expect(
        MukhwakDocument.datedFileName(day),
        startsWith(MukhwakDocument.filePrefix),
      );
      expect(
        MukhwakDocument.latestFileName(day),
        startsWith(MukhwakDocument.filePrefix),
      );
      // The names written before the cache was keyed on SGPC's day must be
      // swept too, because their content cannot be trusted to match the date
      // they claim.
      expect('mukhwak_2026_08_12.pdf',
          startsWith(MukhwakDocument.filePrefix));
    });

    test('the day rolls the name over, which is what expires the cache', () {
      final names = <String>{};
      var day = DateTime.utc(2026, 1, 1);
      for (var i = 0; i < 365; i++) {
        names.add(MukhwakDocument.datedFileName(day));
        day = DateTime.utc(day.year, day.month, day.day + 1);
      }
      expect(names, hasLength(365));
    });
  });

  group('MukhwakDocument.looksLikePdf', () {
    test('accepts the PDF magic number', () {
      // What hs.sgpc.net actually served: "%PDF-1.7".
      expect(
        MukhwakDocument.looksLikePdf(
          Uint8List.fromList('%PDF-1.7\n'.codeUnits),
        ),
        isTrue,
      );
    });

    test('rejects the HTML error page served for an unknown id', () {
      // pdfdownload.php answers an unknown id with HTTP 200 and 403 bytes of
      // HTML, so without this the app would cache an error page as a Mukhwak.
      expect(
        MukhwakDocument.looksLikePdf(
          Uint8List.fromList('<!DOCTYPE html><html>'.codeUnits),
        ),
        isFalse,
      );
    });

    test('rejects an empty or truncated body', () {
      expect(MukhwakDocument.looksLikePdf(Uint8List(0)), isFalse);
      expect(
        MukhwakDocument.looksLikePdf(Uint8List.fromList('%PDF'.codeUnits)),
        isFalse,
      );
    });
  });

  group('MukhwakDocument', () {
    test('only the previous day is reported stale', () {
      expect(
        const MukhwakDocument(
          filePath: '/tmp/a.pdf',
          freshness: DailyFreshness.today,
        ).isStale,
        isFalse,
      );
      expect(
        const MukhwakDocument(
          filePath: '/tmp/a.pdf',
          freshness: DailyFreshness.previousDay,
        ).isStale,
        isTrue,
      );
      expect(
        const MukhwakDocument(
          filePath: '/tmp/a.pdf',
          freshness: DailyFreshness.latest,
        ).isStale,
        isFalse,
      );
    });
  });
}
