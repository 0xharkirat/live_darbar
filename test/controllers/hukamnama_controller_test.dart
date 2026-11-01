import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:live_darbar/src/controllers/hukamnama_controller.dart';
import 'package:live_darbar/src/core/clock.dart';
import 'package:live_darbar/src/models/hukamnama.dart';
import 'package:live_darbar/src/models/sgpc_day.dart';
import 'package:live_darbar/src/services/hukamnama_cache.dart';
import 'package:live_darbar/src/services/hukamnama_service.dart';

final _recorded = jsonDecode(
  File('test/fixtures/sgpc_hukamnama_2026_11_02.json').readAsStringSync(),
) as Map<String, dynamic>;

/// The recorded response re-dated to [day], with the Ang changed to
/// 600 + day-of-month so a test can tell one day's text from another's.
List<int> _bodyFor(DateTime day) {
  final json = jsonDecode(jsonEncode(_recorded)) as Map<String, dynamic>;
  final text = json['hukamnama'] as Map<String, dynamic>;
  text['date'] = sgpcDayIso(day);
  text['ang'] = '${600 + day.day}';
  return utf8.encode(jsonEncode(json));
}

/// What SGPC answers for a day it has no Hukamnama for: HTTP 200 and
/// `supported: false`.
List<int> _notPostedBody(DateTime day) => utf8.encode(
      '{"supported":false,"hukamnama":{"date":"${sgpcDayIso(day)}",'
      '"message":"No Hukamnama Available for this date."},"pdfFiles":[]}',
    );

/// A stand-in for SGPC that has the listed days posted, can go offline,
/// and records which day each request asked for (`yyyy-MM-dd`).
class FakeSgpc {
  FakeSgpc(this.posted);

  final Set<DateTime> posted;
  bool offline = false;
  bool hang = false;
  final List<String> log = [];

  /// A day listed here is answered only once its completer completes, so a
  /// test can make one request slower than another.
  final Map<DateTime, Completer<void>> gates = {};

  /// A day listed here is answered with this body instead of the usual one.
  final Map<DateTime, List<int>> bodies = {};

  late final MockClient client = MockClient((request) async {
    final asked = request.bodyFields['selected_date']!;
    log.add(asked);
    final day = DateTime.parse('${asked}T00:00:00Z');
    // The server's state at the moment it answers, not at the moment it was
    // asked, which is what a held-back answer needs.
    await gates[day]?.future;
    if (offline) throw const SocketException('Failed host lookup');
    if (hang) return Completer<http.Response>().future;
    if (!posted.contains(day)) {
      return http.Response.bytes(_notPostedBody(day), 200);
    }
    return http.Response.bytes(bodies[day] ?? _bodyFor(day), 200);
  });
}

/// The cache without a disk, for tests that run on fake time. File I/O does
/// not complete under `fakeAsync`.
class MemoryCache extends HukamnamaCache {
  Hukamnama? stored;

  @override
  Future<Hukamnama?> read(DateTime day) async {
    final held = stored;
    return held != null && held.isFor(day) ? held : null;
  }

  @override
  Future<Hukamnama?> readLatest() async => stored;

  @override
  Future<void> write(Hukamnama hukamnama) async {
    final held = stored;
    if (held == null || !hukamnama.date.isBefore(held.date)) {
      stored = hukamnama;
    }
  }
}

/// Polls until [done] holds, so a test can wait for a timer it did not start.
Future<void> waitUntil(bool Function() done,
    {Duration timeout = const Duration(seconds: 6)}) async {
  final end = DateTime.now().add(timeout);
  while (!done()) {
    if (DateTime.now().isAfter(end)) fail('Timed out waiting for a change.');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  final nov1 = DateTime.utc(2026, 11, 1);
  final nov2 = DateTime.utc(2026, 11, 2);
  final nov3 = DateTime.utc(2026, 11, 3);

  // 09:00 IST on 2 November: SGPC's day is the 2nd and its Hukamnama is up.
  final morning = DateTime.utc(2026, 11, 2, 3, 30);
  // 03:00 IST on 2 November: the 2nd has begun and nothing is posted yet.
  final beforeDawn = DateTime.utc(2026, 11, 1, 21, 30);

  late Directory dir;
  late DateTime now;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('hukamnama_controller_test');
    now = morning;
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  /// One launch of the app: its own container over the same disk.
  ProviderContainer launch(FakeSgpc server,
      {Duration timeout = const Duration(seconds: 8)}) {
    final service = HukamnamaService(client: server.client, timeout: timeout);
    final container = ProviderContainer(overrides: [
      clockProvider.overrideWithValue(() => now),
      hukamnamaServiceProvider.overrideWithValue(service),
      hukamnamaCacheProvider.overrideWithValue(
        HukamnamaCache(directory: () async => dir),
      ),
    ]);
    addTearDown(() {
      container.dispose();
      service.close();
    });
    return container;
  }

  /// Waits for the background refresh a launch on stored text starts, which
  /// runs as its own event after the build delivers the stored text.
  Future<void> settle(ProviderContainer container) async {
    await Future<void>.delayed(Duration.zero);
    while (container.read(hukamnamaProvider).isLoading) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  Future<void> seedDisk(DateTime day) async {
    await HukamnamaCache(directory: () async => dir).write(Hukamnama.fromSgpc(
        jsonDecode(utf8.decode(_bodyFor(day))) as Map<String, dynamic>));
  }

  List<String> filesOnDisk() =>
      dir.listSync().map((e) => e.uri.pathSegments.last).toList()..sort();

  group('first launch', () {
    test('fetches today\'s text, labels it with its date, and stores it',
        () async {
      final server = FakeSgpc({nov2});
      final container = launch(server);

      final h = await container.read(hukamnamaProvider.future);

      expect(h.date, nov2);
      expect(h.isFor(sgpcDayOf(now)), isTrue);
      expect(h.ang, 602);
      expect(server.log, ['2026-11-02']);
      expect(filesOnDisk(), ['hukamnama_2026_11_02.json']);
    });

    test('asks for SGPC\'s day, not the phone\'s', () async {
      // 19:00 UTC on 1 November is already the 2nd at Amritsar.
      now = DateTime.utc(2026, 11, 1, 19, 0);
      final server = FakeSgpc({nov1, nov2});
      final h = await launch(server).read(hukamnamaProvider.future);
      expect(h.date, nov2);
      expect(server.log, ['2026-11-02']);
    });

    test('before SGPC posts, shows yesterday\'s text under yesterday\'s date',
        () async {
      now = beforeDawn;
      final server = FakeSgpc({nov1});
      final h = await launch(server).read(hukamnamaProvider.future);

      expect(h.date, nov1);
      expect(h.isFor(sgpcDayOf(now)), isFalse,
          reason: 'the screen can see this is not today\'s');
      expect(h.ang, 601);
      expect(server.log, ['2026-11-02', '2026-11-01']);
      expect(filesOnDisk(), ['hukamnama_2026_11_01.json']);
    });

    test('is an error when offline with nothing stored, and refresh recovers',
        () async {
      final server = FakeSgpc({nov2})..offline = true;
      final container = launch(server);
      final states = <AsyncValue<Hukamnama>>[];
      container.listen(hukamnamaProvider, (_, next) => states.add(next),
          fireImmediately: true);

      await expectLater(container.read(hukamnamaProvider.future),
          throwsA(isA<SocketException>()));
      expect(container.read(hukamnamaProvider).hasError, isTrue);
      expect(container.read(hukamnamaProvider).value, isNull);

      server.offline = false;
      await container.read(hukamnamaProvider.notifier).refresh();

      final now2 = container.read(hukamnamaProvider);
      expect(now2.hasError, isFalse);
      expect(now2.requireValue.date, nov2);
    });

    test('does not retry a failed build behind the listener\'s back', () async {
      final server = FakeSgpc({nov2})..offline = true;
      final container = launch(server);
      await expectLater(container.read(hukamnamaProvider.future),
          throwsA(isA<SocketException>()));
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(server.log, hasLength(1));
    });

    test('is an error when the service hangs, after the timeout', () async {
      final server = FakeSgpc({nov2})..hang = true;
      final container =
          launch(server, timeout: const Duration(milliseconds: 50));
      await expectLater(container.read(hukamnamaProvider.future),
          throwsA(isA<TimeoutException>()));
    });
  });

  group('later launches', () {
    test('open from disk with no network when today\'s text is stored',
        () async {
      await launch(FakeSgpc({nov2})).read(hukamnamaProvider.future);

      final offline = FakeSgpc({nov2})..offline = true;
      final h = await launch(offline).read(hukamnamaProvider.future);

      expect(h.date, nov2);
      expect(h.lines, hasLength(10));
      expect(offline.log, isEmpty, reason: 'no request when today is on disk');
    });

    test('open on yesterday\'s text at once, then switch to today\'s',
        () async {
      await seedDisk(nov1);
      final server = FakeSgpc({nov1, nov2});
      final container = launch(server);

      final seen = <String>[];
      container.listen(hukamnamaProvider, (_, next) {
        seen.add('${next.isLoading ? 'loading ' : ''}'
            '${next.value?.date.day ?? 'no value'}');
      }, fireImmediately: true);

      // It opens on what is stored, without waiting for the network.
      final first = await container.read(hukamnamaProvider.future);
      expect(first.date, nov1);

      await settle(container);

      expect(container.read(hukamnamaProvider).requireValue.date, nov2);
      // Yesterday's text was readable throughout, including while loading.
      expect(seen, ['loading no value', '1', 'loading 1', '2']);
      expect(filesOnDisk(), ['hukamnama_2026_11_02.json']);
    });

    test('keep yesterday\'s text, labelled, while today\'s is not posted',
        () async {
      now = beforeDawn;
      await seedDisk(nov1);
      final server = FakeSgpc({nov1});
      final container = launch(server);

      await container.read(hukamnamaProvider.future);
      await settle(container);

      final h = container.read(hukamnamaProvider).requireValue;
      expect(h.date, nov1);
      expect(h.isFor(sgpcDayOf(now)), isFalse);
      expect(server.log, ['2026-11-02'],
          reason: 'one request, not a second one for the day already held');
    });

    test('keep yesterday\'s text, labelled, when offline', () async {
      await seedDisk(nov1);
      final server = FakeSgpc({nov2})..offline = true;
      final container = launch(server);

      await container.read(hukamnamaProvider.future);
      await settle(container);

      final state = container.read(hukamnamaProvider);
      expect(state.hasError, isFalse);
      expect(state.requireValue.date, nov1);
      expect(state.requireValue.isFor(sgpcDayOf(now)), isFalse);
      expect(server.log, isNotEmpty, reason: 'it did try');
    });

    test('keep stored text when the service hangs', () async {
      await seedDisk(nov1);
      final server = FakeSgpc({nov2})..hang = true;
      final container =
          launch(server, timeout: const Duration(milliseconds: 50));

      await container.read(hukamnamaProvider.future);
      await settle(container);

      final state = container.read(hukamnamaProvider);
      expect(state.hasError, isFalse);
      expect(state.requireValue.date, nov1);
    });

    test('reach past a stale day to yesterday when today is not posted',
        () async {
      // Last opened three days ago; today is not posted; yesterday is.
      await seedDisk(DateTime.utc(2026, 10, 30));
      now = beforeDawn;
      final server = FakeSgpc({nov1});
      final container = launch(server);

      final first = await container.read(hukamnamaProvider.future);
      expect(first.date, DateTime.utc(2026, 10, 30));
      await settle(container);

      expect(container.read(hukamnamaProvider).requireValue.date, nov1);
      expect(filesOnDisk(), ['hukamnama_2026_11_01.json']);
    });
  });

  group('refresh', () {
    test('keeps the text on screen while it runs, then swaps in the new day',
        () async {
      now = beforeDawn;
      final server = FakeSgpc({nov1});
      final container = launch(server);
      await container.read(hukamnamaProvider.future);

      // SGPC posts, and the phone has been open since before dawn.
      server.posted.add(nov2);
      now = morning;

      final states = <AsyncValue<Hukamnama>>[];
      container.listen(hukamnamaProvider, (_, next) => states.add(next));
      await container.read(hukamnamaProvider.notifier).refresh();

      expect(states.first.isLoading, isTrue);
      expect(states.first.value?.date, nov1,
          reason: 'yesterday\'s text stays readable during the refresh');
      expect(states.last.requireValue.date, nov2);
      expect(filesOnDisk(), ['hukamnama_2026_11_02.json']);
    });

    test('picks up a new day when the clock passes SGPC midnight', () async {
      final server = FakeSgpc({nov2, nov3});
      final container = launch(server);
      expect((await container.read(hukamnamaProvider.future)).date, nov2);

      now = DateTime.utc(2026, 11, 2, 18, 31); // 00:01 IST on the 3rd
      await container.read(hukamnamaProvider.notifier).refresh();

      expect(container.read(hukamnamaProvider).requireValue.date, nov3);
    });

    test('never replaces shown text with an error', () async {
      final server = FakeSgpc({nov2});
      final container = launch(server);
      final shown = await container.read(hukamnamaProvider.future);

      server.offline = true;
      await container.read(hukamnamaProvider.notifier).refresh();

      final after = container.read(hukamnamaProvider);
      expect(after.hasError, isFalse);
      expect(after.isLoading, isFalse);
      expect(after.requireValue, same(shown));
    });

    test('can be called again after an error', () async {
      final server = FakeSgpc({})..offline = true;
      final container = launch(server);
      await expectLater(
          container.read(hukamnamaProvider.future), throwsA(anything));

      final notifier = container.read(hukamnamaProvider.notifier);
      await notifier.refresh();
      expect(container.read(hukamnamaProvider).hasError, isTrue);

      server
        ..offline = false
        ..posted.add(nov2);
      await notifier.refresh();
      expect(container.read(hukamnamaProvider).requireValue.date, nov2);
    });

    test('a slow refresh for an old day never undoes a newer one', () async {
      final server = FakeSgpc({nov2, nov3});
      final container = launch(server);
      await container.read(hukamnamaProvider.future);
      final notifier = container.read(hukamnamaProvider.notifier);

      // Asked on the 2nd, and the answer is held back.
      server.gates[nov2] = Completer<void>();
      final slow = notifier.refresh();

      // Asked on the 3rd, and answered at once.
      now = DateTime.utc(2026, 11, 3, 3, 30);
      await notifier.refresh();
      expect(container.read(hukamnamaProvider).requireValue.date, nov3);

      // The old answer arrives last.
      server.gates[nov2]!.complete();
      await slow;

      final after = container.read(hukamnamaProvider);
      expect(after.requireValue.date, nov3);
      expect(after.isLoading, isFalse);
      expect(filesOnDisk(), ['hukamnama_2026_11_03.json']);
    });

    test('a failed slow refresh does not put an error over newer text',
        () async {
      final server = FakeSgpc({nov2, nov3})..offline = true;
      final container = launch(server);
      await expectLater(
          container.read(hukamnamaProvider.future), throwsA(anything));
      final notifier = container.read(hukamnamaProvider.notifier);

      // Nothing is shown, so this refresh has no text to fall back on. It is
      // held back and then fails.
      server
        ..offline = false
        ..gates[nov2] = Completer<void>();
      final slow = notifier.refresh();

      // A newer refresh succeeds first.
      now = DateTime.utc(2026, 11, 3, 3, 30);
      await notifier.refresh();
      expect(container.read(hukamnamaProvider).requireValue.date, nov3);

      // The held-back request now fails.
      server.offline = true;
      server.gates[nov2]!.complete();
      await slow;

      final after = container.read(hukamnamaProvider);
      expect(after.hasError, isFalse);
      expect(after.requireValue.date, nov3);
    });
  });

  group('an incomplete response', () {
    /// The recorded text with its Gurmukhi removed.
    List<int> noGurmukhi() {
      final json =
          jsonDecode(utf8.decode(_bodyFor(nov2))) as Map<String, dynamic>;
      (json['hukamnama'] as Map<String, dynamic>)['ghukamnama'] = '';
      return utf8.encode(jsonEncode(json));
    }

    /// The recorded text under another day's date.
    List<int> wrongDay() => _bodyFor(nov1);

    for (final entry in {
      'with no Gurmukhi': noGurmukhi,
      'for another day': wrongDay,
    }.entries) {
      test('${entry.key} is not stored and not shown as today\'s', () async {
        final server = FakeSgpc({nov2})..bodies[nov2] = entry.value();
        final container = launch(server);

        await expectLater(container.read(hukamnamaProvider.future),
            throwsA(isA<HukamnamaException>()));
        expect(filesOnDisk(), isEmpty);
      });

      test('${entry.key} leaves the stored text where it was', () async {
        await seedDisk(nov1);
        final server = FakeSgpc({nov1, nov2})..bodies[nov2] = entry.value();
        final container = launch(server);

        await container.read(hukamnamaProvider.future);
        await settle(container);

        final state = container.read(hukamnamaProvider);
        expect(state.hasError, isFalse);
        expect(state.requireValue.date, nov1);
        expect(filesOnDisk(), ['hukamnama_2026_11_01.json']);
      });
    }
  });

  // These run on fake time, so a wait of 15 minutes or a night costs nothing.
  // The clock the controller reads moves with it.
  group('on fake time', () {
    /// Runs [body] with the controller alive on a clock that starts at [start]
    /// and moves with `async.elapse`. The container listens, as a screen does.
    /// [stored] is what the cache holds when the app opens.
    void fakeTimeTest(
      String name,
      DateTime start,
      FakeSgpc server,
      void Function(
              FakeAsync async, ProviderContainer container, FakeSgpc server)
          body, {
      bool isWeb = false,
      Hukamnama? stored,
      bool disposeAtEnd = true,
    }) {
      test(name, () {
        fakeAsync((async) {
          final service = HukamnamaService(client: server.client, isWeb: isWeb);
          final container = ProviderContainer(overrides: [
            clockProvider.overrideWithValue(() => start.add(async.elapsed)),
            hukamnamaServiceProvider.overrideWithValue(service),
            hukamnamaCacheProvider
                .overrideWithValue(MemoryCache()..stored = stored),
          ]);
          container.listen(hukamnamaProvider, (_, __) {});
          async.flushMicrotasks();

          body(async, container, server);

          if (disposeAtEnd) container.dispose();
          service.close();
        });
      });
    }

    Hukamnama? shown(ProviderContainer c) => c.read(hukamnamaProvider).value;
    Hukamnama textFor(DateTime day) => Hukamnama.fromSgpc(
        jsonDecode(utf8.decode(_bodyFor(day))) as Map<String, dynamic>);
    const step = Duration(minutes: 15);

    group('stale retry', () {
      fakeTimeTest(
        'asks every 15 minutes while it holds yesterday\'s text, then stops '
        'once it has today\'s',
        beforeDawn,
        FakeSgpc({nov1}),
        (async, container, server) {
          expect(shown(container)?.date, nov1);
          expect(server.log, ['2026-11-02', '2026-11-01']);

          // Just short of 15 minutes: nothing yet.
          async.elapse(step - const Duration(seconds: 1));
          expect(server.log, hasLength(2));

          // 15 minutes: one more ask for today. It already holds yesterday's,
          // so it does not ask for that again.
          async.elapse(const Duration(seconds: 1));
          expect(server.log, ['2026-11-02', '2026-11-01', '2026-11-02']);
          expect(shown(container)?.date, nov1);

          async.elapse(step);
          expect(server.log, hasLength(4));

          // SGPC posts. The next ask finds it.
          server.posted.add(nov2);
          async.elapse(step);
          expect(server.log, hasLength(5));
          expect(shown(container)?.date, nov2);
          expect(shown(container)!.isFor(sgpcDayOf(beforeDawn)), isTrue);

          // It has today's text now, so it stops asking.
          async.elapse(const Duration(hours: 3));
          expect(server.log, hasLength(5));
        },
      );

      fakeTimeTest(
        'asks every 15 minutes after a failure left it with nothing, then '
        'stops once it has today\'s',
        morning,
        FakeSgpc({nov2})..offline = true,
        (async, container, server) {
          expect(container.read(hukamnamaProvider).hasError, isTrue);
          expect(server.log, hasLength(1));

          async.elapse(step);
          expect(server.log, hasLength(2));
          expect(container.read(hukamnamaProvider).hasError, isTrue);

          // The network comes back.
          server.offline = false;
          async.elapse(step);
          expect(server.log, hasLength(3));
          expect(container.read(hukamnamaProvider).hasError, isFalse);
          expect(shown(container)?.date, nov2);

          async.elapse(const Duration(hours: 3));
          expect(server.log, hasLength(3));
        },
      );

      fakeTimeTest(
        'keeps asking while a failure leaves yesterday\'s stored text on '
        'screen, then stops once it has today\'s',
        morning,
        FakeSgpc({nov2})..offline = true,
        stored: textFor(nov1),
        (async, container, server) {
          // It opens on the stored text, and its background ask fails.
          async.elapse(Duration.zero);
          expect(shown(container)?.date, nov1);
          expect(container.read(hukamnamaProvider).hasError, isFalse);
          expect(server.log, ['2026-11-02']);

          async.elapse(step);
          async.elapse(step);
          expect(server.log, hasLength(3));
          expect(shown(container)?.date, nov1);

          server.offline = false;
          async.elapse(step);
          expect(server.log, hasLength(4));
          expect(shown(container)?.date, nov2);

          async.elapse(const Duration(hours: 3));
          expect(server.log, hasLength(4));
        },
      );

      fakeTimeTest(
        'does not ask again while it holds today\'s text',
        morning,
        FakeSgpc({nov2}),
        (async, container, server) {
          expect(shown(container)?.date, nov2);
          expect(server.log, hasLength(1));

          async.elapse(const Duration(hours: 6));
          expect(server.log, hasLength(1));
        },
      );

      fakeTimeTest(
        'a retry that falls due during a refresh does nothing, and the gap '
        'restarts when that refresh ends',
        beforeDawn,
        FakeSgpc({nov1}),
        (async, container, server) {
          final notifier = container.read(hukamnamaProvider.notifier);
          expect(server.log, hasLength(2));

          // A refresh from a screen starts 2 seconds before the retry falls
          // due, and SGPC is slow to answer it.
          async.elapse(step - const Duration(seconds: 2));
          server.gates[nov2] = Completer<void>();
          unawaited(notifier.refresh());
          async.flushMicrotasks();
          expect(server.log, hasLength(3));

          // The retry falls due mid-refresh. It does not pile on.
          async.elapse(const Duration(seconds: 2));
          expect(server.log, hasLength(3));

          // The refresh ends 5 seconds later with nothing new.
          async.elapse(const Duration(seconds: 5));
          server.gates[nov2]!.complete();
          async.flushMicrotasks();
          expect(server.log, hasLength(3));
          expect(shown(container)?.date, nov1);
          expect(container.read(hukamnamaProvider).isLoading, isFalse);

          // The next ask is 15 minutes after that refresh ended.
          async.elapse(step - const Duration(seconds: 1));
          expect(server.log, hasLength(3));
          async.elapse(const Duration(seconds: 1));
          expect(server.log, hasLength(4));
        },
      );

      fakeTimeTest(
        'stops asking once the controller is gone',
        beforeDawn,
        FakeSgpc({nov1}),
        disposeAtEnd: false,
        (async, container, server) {
          expect(server.log, hasLength(2));

          container.dispose();
          async.elapse(const Duration(hours: 2));
          expect(server.log, hasLength(2));
        },
      );

      fakeTimeTest(
        'never asks on web, where it cannot fetch',
        morning,
        FakeSgpc({nov2}),
        isWeb: true,
        (async, container, server) {
          final state = container.read(hukamnamaProvider);
          expect(state.hasError, isTrue);
          expect(state.error, isA<HukamnamaWebUnsupportedException>());

          async.elapse(const Duration(hours: 3));
          expect(server.log, isEmpty);
          expect(container.read(hukamnamaProvider).error,
              isA<HukamnamaWebUnsupportedException>());
          // Only the midnight timer is left. No 15-minute retry.
          expect(async.pendingTimers, hasLength(1));
        },
      );
    });

    group('at SGPC midnight', () {
      fakeTimeTest(
        'asks for the new day by itself',
        // One second before the 3rd begins at Amritsar.
        DateTime.utc(2026, 11, 2, 18, 29, 59),
        FakeSgpc({nov2, nov3}),
        (async, container, server) {
          expect(shown(container)?.date, nov2);
          expect(server.log, ['2026-11-02']);

          async.elapse(const Duration(seconds: 1));
          expect(shown(container)?.date, nov2,
              reason: 'the timer waits one second past midnight');
          async.elapse(const Duration(seconds: 1));

          expect(shown(container)?.date, nov3);
          expect(server.log.last, '2026-11-03');
        },
      );

      fakeTimeTest(
        'keeps the old day\'s text after midnight, then retries until the new '
        'day is posted',
        // A minute before the 3rd begins at Amritsar. It holds today's text.
        DateTime.utc(2026, 11, 2, 18, 29),
        FakeSgpc({nov2}),
        (async, container, server) {
          expect(shown(container)?.isFor(nov2), isTrue);

          // Midnight passes. The 3rd is not posted, so the 2nd stays on
          // screen, and it is no longer today's.
          async.elapse(const Duration(seconds: 61));
          expect(server.log, ['2026-11-02', '2026-11-03']);
          expect(shown(container)?.date, nov2);

          // It asks every 15 minutes through the night.
          async.elapse(step);
          async.elapse(step);
          expect(server.log,
              ['2026-11-02', '2026-11-03', '2026-11-03', '2026-11-03']);

          // SGPC posts the 3rd. The next ask finds it, and the asking stops.
          server.posted.add(nov3);
          async.elapse(step);
          expect(shown(container)?.date, nov3);
          expect(server.log, hasLength(5));

          async.elapse(const Duration(hours: 3));
          expect(server.log, hasLength(5));
        },
      );
    });
  });
}
