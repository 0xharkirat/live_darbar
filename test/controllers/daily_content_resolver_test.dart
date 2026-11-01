import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:live_darbar/src/controllers/daily_content_controller.dart';
import 'package:live_darbar/src/models/daily_edition.dart';
import 'package:live_darbar/src/models/sgpc_day.dart';

/// 09:00 IST on 12 August 2026, an hour into the window where the Hukamnama
/// for the day is up and the Katha is not.
final _morning = DateTime.utc(2026, 8, 12, 3, 30);

/// A client that answers 200 for the listed paths and 404 for everything else,
/// recording what it was asked.
MockClient _server(Set<String> present, {List<String>? log}) {
  return MockClient((request) async {
    log?.add(request.url.toString());
    final found = present.contains(request.url.toString());
    return http.Response('', found ? 200 : 404);
  });
}

void main() {
  final today = DateTime.utc(2026, 8, 12);
  final yesterday = DateTime.utc(2026, 8, 11);

  group('DailyContentResolver', () {
    test('takes today when today is up', () async {
      final resolver = DailyContentResolver(
        client: _server({DailyAsset.hukamnama.urlFor(today)}),
        clock: () => _morning,
      );
      addTearDown(resolver.dispose);

      final edition = await resolver.resolve(DailyAsset.hukamnama);
      expect(edition.freshness, DailyFreshness.today);
      expect(edition.day, today);
      expect(edition.url, contains('SGPCNET120826'));
      expect(edition.isStale, isFalse);
    });

    test('falls back to yesterday when today is not published yet', () async {
      // This is the ordinary state of the Katha at 09:00 IST, not an error.
      final resolver = DailyContentResolver(
        client: _server({DailyAsset.katha.urlFor(yesterday)}),
        clock: () => _morning,
      );
      addTearDown(resolver.dispose);

      final edition = await resolver.resolve(DailyAsset.katha);
      expect(edition.freshness, DailyFreshness.previousDay);
      expect(edition.day, yesterday);
      expect(edition.url, contains('katha110826'));
      expect(edition.isStale, isTrue);
    });

    test('asks about today first', () async {
      final log = <String>[];
      final resolver = DailyContentResolver(
        client: _server({DailyAsset.katha.urlFor(yesterday)}, log: log),
        clock: () => _morning,
      );
      addTearDown(resolver.dispose);

      await resolver.resolve(DailyAsset.katha);
      expect(log, [
        DailyAsset.katha.urlFor(today),
        DailyAsset.katha.urlFor(yesterday),
      ]);
    });

    test('asks about both days before either has answered', () async {
      final pending = <String, Completer<http.Response>>{};
      final resolver = DailyContentResolver(
        client: MockClient((request) {
          return (pending[request.url.toString()] = Completer<http.Response>())
              .future;
        }),
        clock: () => _morning,
      );
      addTearDown(resolver.dispose);

      final result = resolver.resolve(DailyAsset.katha);
      await Future<void>.delayed(Duration.zero);

      // Neither probe has answered, and both are already out.
      expect(pending.keys, [
        DailyAsset.katha.urlFor(today),
        DailyAsset.katha.urlFor(yesterday),
      ]);

      pending[DailyAsset.katha.urlFor(today)]!
          .complete(http.Response('', 404));
      pending[DailyAsset.katha.urlFor(yesterday)]!
          .complete(http.Response('', 200));
      expect((await result).freshness, DailyFreshness.previousDay);
    });

    test('takes today without waiting for yesterday to answer', () async {
      final yesterdayAnswer = Completer<http.Response>();
      final resolver = DailyContentResolver(
        client: MockClient((request) {
          if (request.url.toString() == DailyAsset.katha.urlFor(today)) {
            return Future.value(http.Response('', 200));
          }
          return yesterdayAnswer.future;
        }),
        clock: () => _morning,
      );
      addTearDown(resolver.dispose);

      final edition = await resolver
          .resolve(DailyAsset.katha)
          .timeout(const Duration(seconds: 5));
      expect(edition.freshness, DailyFreshness.today);
      yesterdayAnswer.complete(http.Response('', 404));
    });

    test('settles for the undated URL when neither day answers', () async {
      final resolver = DailyContentResolver(
        client: _server(const {}),
        clock: () => _morning,
      );
      addTearDown(resolver.dispose);

      final edition = await resolver.resolve(DailyAsset.hukamnama);
      expect(edition.freshness, DailyFreshness.latest);
      expect(edition.url, DailyAsset.hukamnama.latestUrl);
      expect(edition.day, isNull);
      // Nothing is claimed about the day, so nothing is said about it.
      expect(edition.isStale, isFalse);
    });

    test('a hanging probe resolves rather than waiting forever', () async {
      // The bug that started all of this. A server that accepts the connection
      // and then sends nothing must not be able to hold the app open.
      final resolver = DailyContentResolver(
        client: MockClient((_) => Completer<http.Response>().future),
        clock: () => _morning,
      );
      addTearDown(resolver.dispose);

      final edition = await resolver
          .resolve(DailyAsset.hukamnama)
          .timeout(const Duration(seconds: 30));
      expect(edition.freshness, DailyFreshness.latest);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a confirmed today is not probed again', () async {
      final log = <String>[];
      final resolver = DailyContentResolver(
        client: _server({DailyAsset.hukamnama.urlFor(today)}, log: log),
        clock: () => _morning,
      );
      addTearDown(resolver.dispose);

      await resolver.resolve(DailyAsset.hukamnama);
      final probed = log.length;
      await resolver.resolve(DailyAsset.hukamnama);
      // One pair of probes for the first call, none for the second.
      expect(probed, 2);
      expect(log, hasLength(probed));
    });

    test('a yesterday answer is rechecked, so today lands when it does',
        () async {
      var present = <String>{DailyAsset.hukamnama.urlFor(yesterday)};
      var now = _morning;
      final resolver = DailyContentResolver(
        client: MockClient((request) async {
          final found = present.contains(request.url.toString());
          return http.Response('', found ? 200 : 404);
        }),
        clock: () => now,
      );
      addTearDown(resolver.dispose);

      expect(
        (await resolver.resolve(DailyAsset.hukamnama)).freshness,
        DailyFreshness.previousDay,
      );

      // Within the recheck window the earlier answer still stands.
      now = _morning.add(const Duration(minutes: 5));
      present = {DailyAsset.hukamnama.urlFor(today)};
      expect(
        (await resolver.resolve(DailyAsset.hukamnama)).freshness,
        DailyFreshness.previousDay,
      );

      // Past it, the app notices that today has been uploaded.
      now = _morning.add(const Duration(minutes: 11));
      expect(
        (await resolver.resolve(DailyAsset.hukamnama)).freshness,
        DailyFreshness.today,
      );
    });

    test('a cached today expires when the day rolls over in Amritsar',
        () async {
      var now = _morning;
      final present = <String>{
        DailyAsset.hukamnama.urlFor(today),
        DailyAsset.hukamnama.urlFor(DateTime.utc(2026, 8, 13)),
      };
      final resolver = DailyContentResolver(
        client: MockClient((request) async {
          final found = present.contains(request.url.toString());
          return http.Response('', found ? 200 : 404);
        }),
        clock: () => now,
      );
      addTearDown(resolver.dispose);

      expect((await resolver.resolve(DailyAsset.hukamnama)).day, today);

      // 18:30 UTC is midnight IST, so this is the next day at Darbar Sahib
      // even though it is still the 12th almost everywhere else.
      now = DateTime.utc(2026, 8, 12, 19, 0);
      expect(
        (await resolver.resolve(DailyAsset.hukamnama)).day,
        DateTime.utc(2026, 8, 13),
      );
    });

    test('the two assets resolve independently', () async {
      // The four-hour window every morning where the Hukamnama is up and the
      // Katha is not is the normal case, not an edge case.
      final resolver = DailyContentResolver(
        client: _server({
          DailyAsset.hukamnama.urlFor(today),
          DailyAsset.katha.urlFor(yesterday),
        }),
        clock: () => _morning,
      );
      addTearDown(resolver.dispose);

      expect(
        (await resolver.resolve(DailyAsset.hukamnama)).freshness,
        DailyFreshness.today,
      );
      expect(
        (await resolver.resolve(DailyAsset.katha)).freshness,
        DailyFreshness.previousDay,
      );
    });

    test('concurrent callers share one pair of probes', () async {
      final log = <String>[];
      final resolver = DailyContentResolver(
        client: _server({DailyAsset.hukamnama.urlFor(today)}, log: log),
        clock: () => _morning,
      );
      addTearDown(resolver.dispose);

      final results = await Future.wait([
        resolver.resolve(DailyAsset.hukamnama),
        resolver.resolve(DailyAsset.hukamnama),
        resolver.resolve(DailyAsset.hukamnama),
      ]);
      expect(log, hasLength(2));
      expect(
        results.map((e) => e.freshness),
        everyElement(DailyFreshness.today),
      );
    });
  });
}
