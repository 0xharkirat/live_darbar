import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/controllers/sgpc_events_controller.dart';
import 'package:live_darbar/src/controllers/sikh_date_controller.dart';
import 'package:live_darbar/src/core/clock.dart';
import 'package:live_darbar/src/models/sgpc_event.dart';
import 'package:live_darbar/src/models/sikh_date.dart';

/// An asset bundle with the files given, and the list of them that the real
/// one builds. Nothing is read from disk.
class _Bundle extends CachingAssetBundle {
  _Bundle(this.files, {this.listBroken = false});

  final Map<String, String> files;
  final bool listBroken;

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      if (listBroken) throw FlutterError('no manifest');
      return const StandardMessageCodec().encodeMessage({
        for (final path in files.keys) path: <Object?>[],
      })!;
    }
    final text = files[key];
    if (text == null) throw FlutterError('Unable to load asset: $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(text)));
  }
}

String _file(String id, String date) => jsonEncode({
      'version': 1,
      'events': [
        {
          'id': id,
          'gregorian': date,
          'titlePa': 'ਸਿਰਲੇਖ $id',
          'titleEn': 'Title $id',
        },
      ],
    });

SgpcEventTable _shipped() => SgpcEventTable.fromJsonString(
      File('assets/data/sgpc_events_558.json').readAsStringSync(),
    );

/// How the app finds the calendar files, and which day's events home shows.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('finding the files', () {
    test('reads every sgpc_events_<year>.json and joins them oldest first',
        () async {
      // Next March, the file for 559 is dropped in and nothing else changes.
      final table = await loadSgpcEvents(
        _Bundle({
          'assets/data/sgpc_events_559.json': _file('ns559-001', '2027-03-15'),
          'assets/data/sgpc_events_558.json': _file('ns558-001', '2027-03-14'),
          'assets/data/sgpc_sangrands.json': '{"months": []}',
          'assets/images/painting.png': 'not a file we read',
          'assets/data/sgpc_events_next.json': _file('x', '2027-03-16'),
        }),
      );

      expect(table.events.map((e) => e.id), ['ns558-001', 'ns559-001']);
      expect(table.on(DateTime.utc(2027, 3, 14)).single.id, 'ns558-001');
      expect(table.on(DateTime.utc(2027, 3, 15)).single.id, 'ns559-001');
      expect(table.on(DateTime.utc(2027, 3, 16)), isEmpty);
    });

    test('puts year 1000 after year 999, not before', () async {
      final table = await loadSgpcEvents(
        _Bundle({
          'assets/data/sgpc_events_1000.json': _file('later', '2027-03-15'),
          'assets/data/sgpc_events_999.json': _file('earlier', '2027-03-14'),
        }),
      );

      expect(table.events.map((e) => e.id), ['earlier', 'later']);
    });

    test('leaves out a file that is broken and keeps the others', () async {
      final table = await loadSgpcEvents(
        _Bundle({
          'assets/data/sgpc_events_558.json': _file('ns558-001', '2027-03-14'),
          'assets/data/sgpc_events_559.json': 'this is not json',
        }),
      );

      expect(table.events.map((e) => e.id), ['ns558-001']);
    });

    test('is empty with no files, and when the list cannot be read', () async {
      expect((await loadSgpcEvents(_Bundle({}))).isEmpty, isTrue);
      expect(
        (await loadSgpcEvents(
          _Bundle({
            'assets/data/sgpc_events_558.json': _file('a', '2027-03-14'),
          }, listBroken: true),
        ))
            .isEmpty,
        isTrue,
      );
    });

    test('reads the real bundle, where the shipped file is declared', () async {
      final table = await loadSgpcEvents(rootBundle);

      expect(table.events, hasLength(120));
      expect(table.on(DateTime.utc(2026, 11, 3)), hasLength(3));
    });
  });

  group('todaysEventsProvider', () {
    ProviderContainer containerAt(DateTime instant, {SikhDate? sikh}) {
      final container = ProviderContainer(
        retry: (_, __) => null,
        overrides: [
          clockProvider.overrideWithValue(() => instant),
          sgpcEventsProvider.overrideWith((ref) async => _shipped()),
          sikhDateProvider.overrideWith((ref) async => sikh),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('lists the events of the SGPC day, not the phone\'s', () async {
      // 19:00 UTC on 2 November is 00:30 IST on 3 November at Amritsar, and
      // still 2 November in Vancouver. The events are the Amritsar ones.
      final container = containerAt(DateTime.utc(2026, 11, 2, 19));

      final events = await container.read(todaysEventsProvider.future);

      expect(events, hasLength(3));
      expect(events.first.id, 'ns558-082');
    });

    test('is empty on a day with no event', () async {
      final container = containerAt(DateTime.utc(2026, 11, 2, 6));

      expect(await container.read(todaysEventsProvider.future), isEmpty);
    });

    test('names the same day as the Sikh date it sits under', () async {
      final container = containerAt(
        DateTime.utc(2026, 11, 3, 6),
        sikh: SikhDate(
          day: 18,
          monthIndex: 7,
          year: 558,
          gregorian: DateTime.utc(2026, 11, 3),
        ),
      );

      expect(await container.read(todaysEventsProvider.future), hasLength(3));
    });
  });
}
