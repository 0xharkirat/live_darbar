import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:live_darbar/src/controllers/hukamnama_controller.dart';
import 'package:live_darbar/src/controllers/sangrand_controller.dart';
import 'package:live_darbar/src/controllers/sikh_date_controller.dart';
import 'package:live_darbar/src/models/barah_maha.dart';
import 'package:live_darbar/src/models/sgpc_day.dart';
import 'package:live_darbar/src/models/sikh_date.dart';
import 'package:live_darbar/src/services/hukamnama_cache.dart';
import 'package:live_darbar/src/services/hukamnama_service.dart';

final _recorded = jsonDecode(
  File('test/fixtures/sgpc_hukamnama_2026_11_02.json').readAsStringSync(),
) as Map<String, dynamic>;

/// The recorded answer re-dated to [day], with the Ang set to 600 plus the day
/// of the month so a test can tell one day's text from another's.
List<int> _bodyFor(DateTime day) {
  final json = jsonDecode(jsonEncode(_recorded)) as Map<String, dynamic>;
  final text = json['hukamnama'] as Map<String, dynamic>;
  text['date'] = sgpcDayIso(day);
  text['ang'] = '${600 + day.day}';
  return utf8.encode(jsonEncode(json));
}

/// SGPC's answer for a day it has no Hukamnama for: HTTP 200, `supported: false`.
List<int> _notPostedBody(DateTime day) => utf8.encode(
      '{"supported":false,"hukamnama":{"date":"${sgpcDayIso(day)}",'
      '"message":"No Hukamnama Available for this date."},"pdfFiles":[]}',
    );

/// A stand-in for SGPC that has the listed days, can go offline, and records
/// the day of each POST. The mirror (GET) has nothing, as for an old day.
class _Sgpc {
  _Sgpc(this.posted);

  final Set<DateTime> posted;
  bool offline = false;
  final List<String> asked = [];

  late final http.Client client = MockClient((request) async {
    if (request.method == 'GET') return http.Response('404: Not Found', 404);
    final iso = request.bodyFields['selected_date']!;
    asked.add(iso);
    final day = DateTime.parse('${iso}T00:00:00Z');
    if (offline) throw const SocketException('Failed host lookup');
    return http.Response.bytes(
      posted.contains(day) ? _bodyFor(day) : _notPostedBody(day),
      200,
    );
  });
}

void main() {
  final nov1 = DateTime.utc(2026, 11, 1);
  final nov3 = DateTime.utc(2026, 11, 3);

  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('hukamnama_archive_test');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  ProviderContainer launch(_Sgpc server) {
    final service = HukamnamaService(client: server.client, isWeb: false);
    final container = ProviderContainer(overrides: [
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

  group('hukamnamaForDayProvider', () {
    test('asks for the day it is keyed by, and gives that day\'s text',
        () async {
      final server = _Sgpc({nov1, nov3});
      final container = launch(server);

      final sub = container.listen(hukamnamaForDayProvider(nov1), (_, __) {});
      final h = await container.read(hukamnamaForDayProvider(nov1).future);
      sub.close();

      expect(h.date, nov1);
      expect(h.ang, 601);
      expect(server.asked, ['2026-11-01']);
    });

    test('keeps each day apart', () async {
      final server = _Sgpc({nov1, nov3});
      final container = launch(server);

      final a = container.listen(hukamnamaForDayProvider(nov1), (_, __) {});
      final b = container.listen(hukamnamaForDayProvider(nov3), (_, __) {});
      final first = await container.read(hukamnamaForDayProvider(nov1).future);
      final second = await container.read(hukamnamaForDayProvider(nov3).future);
      a.close();
      b.close();

      expect(first.ang, 601);
      expect(second.ang, 603);
    });

    test('leaves the stored text of today alone', () async {
      final server = _Sgpc({nov1});
      final container = launch(server);

      final sub = container.listen(hukamnamaForDayProvider(nov1), (_, __) {});
      await container.read(hukamnamaForDayProvider(nov1).future);
      sub.close();

      expect(dir.listSync(), isEmpty,
          reason: 'an earlier day is read, not stored');
      expect(
        await HukamnamaCache(directory: () async => dir).readLatest(),
        isNull,
      );
    });

    test('a day that was read is not asked for again', () async {
      final server = _Sgpc({nov1});
      final container = launch(server);

      final first = container.listen(hukamnamaForDayProvider(nov1), (_, __) {});
      await container.read(hukamnamaForDayProvider(nov1).future);
      first.close();
      // The reader was closed and is opened again on the same day.
      final again = container.listen(hukamnamaForDayProvider(nov1), (_, __) {});
      final h = await container.read(hukamnamaForDayProvider(nov1).future);
      again.close();

      expect(h.date, nov1);
      expect(server.asked, hasLength(1));
    });

    test('a day with no text is "not published", and says nothing more',
        () async {
      final server = _Sgpc({});
      final container = launch(server);

      final sub = container.listen(hukamnamaForDayProvider(nov1), (_, __) {});
      await expectLater(
        container.read(hukamnamaForDayProvider(nov1).future),
        throwsA(isA<HukamnamaNotPublishedException>()),
      );
      sub.close();
      // One ask: a failed build is not retried behind the listener's back.
      expect(server.asked, hasLength(1));
    });

    test('a failure is not kept: opening the day again asks again', () async {
      final server = _Sgpc({nov1})..offline = true;
      final container = launch(server);

      final first = container.listen(hukamnamaForDayProvider(nov1), (_, __) {});
      await expectLater(
        container.read(hukamnamaForDayProvider(nov1).future),
        throwsA(isA<Exception>()),
      );
      first.close();
      // The phone is back online and the reader is opened again.
      server.offline = false;
      await Future<void>.delayed(Duration.zero);
      final again = container.listen(hukamnamaForDayProvider(nov1), (_, __) {});
      final h = await container.read(hukamnamaForDayProvider(nov1).future);
      again.close();

      expect(h.date, nov1);
      expect(server.asked, hasLength(2));
    });
  });

  group('sangrandForDayProvider', () {
    final table = SangrandTable.fromJsonString(
      File('assets/data/sgpc_sangrands.json').readAsStringSync(),
    );

    ProviderContainer withTable() {
      final container = ProviderContainer(overrides: [
        sangrandTableProvider.overrideWith((ref) async => table),
        barahMahaProvider.overrideWith(
          (ref) async => BarahMaha.fromJson(
            jsonDecode(File(kBarahMahaAsset).readAsStringSync())
                as Map<String, dynamic>,
          ),
        ),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    test('on a Sangrand: the pauri of the month that began that day', () async {
      final container = withTable();
      // 16 November 2026 is 1 Maghar 558.
      final day = DateTime.utc(2026, 11, 16);
      final s = (await container.read(sangrandForDayProvider(day).future))!;

      expect(s.isSangrandDay, isTrue);
      expect(s.date.monthEnglish, 'Maghar');
      expect(s.lines.first.gurmukhi, startsWith('ਮੰਘਿਰਿ ਮਾਹਿ ਸੋਹੰਦੀਆ'));
    });

    test('on any other day: it is not a Sangrand', () async {
      final container = withTable();
      final s = (await container.read(
        sangrandForDayProvider(DateTime.utc(2026, 11, 15)).future,
      ))!;

      expect(s.isSangrandDay, isFalse);
    });

    test('for a day the table does not reach: nothing', () async {
      final container = withTable();
      final s = await container.read(
        sangrandForDayProvider(DateTime.utc(2019, 4, 14)).future,
      );

      expect(s, isNull);
    });
  });
}
