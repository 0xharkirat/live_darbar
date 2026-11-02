import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:live_darbar/src/home_screen_widget/widget_background.dart';
import 'package:live_darbar/src/home_screen_widget/widget_data.dart';
import 'package:live_darbar/src/models/hukamnama.dart';
import 'package:live_darbar/src/models/sgpc_day.dart';
import 'package:live_darbar/src/services/hukamnama_cache.dart';
import 'package:live_darbar/src/services/hukamnama_service.dart';

final _recorded = jsonDecode(
  File('test/fixtures/sgpc_hukamnama_2026_11_02.json').readAsStringSync(),
) as Map<String, dynamic>;

/// The recorded response re-dated to [day].
List<int> _bodyFor(DateTime day) {
  final json = jsonDecode(jsonEncode(_recorded)) as Map<String, dynamic>;
  (json['hukamnama'] as Map<String, dynamic>)['date'] = sgpcDayIso(day);
  return utf8.encode(jsonEncode(json));
}

List<int> _notPosted(DateTime day) => utf8.encode(
      '{"supported":false,"hukamnama":{"date":"${sgpcDayIso(day)}",'
      '"message":"No Hukamnama Available for this date."},"pdfFiles":[]}',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final nov1 = DateTime.utc(2026, 11, 1);
  final nov2 = DateTime.utc(2026, 11, 2);
  // 09:00 IST on 2 November, and 00:10 IST on 2 November.
  final morning = DateTime.utc(2026, 11, 2, 3, 30);
  final justAfterMidnight = DateTime.utc(2026, 11, 1, 18, 40);

  late Directory dir;
  late HukamnamaCache cache;
  late List<String> asked;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('widget_background_test');
    cache = HukamnamaCache(directory: () async => dir);
    asked = [];
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  Future<WidgetRefresh> run({
    required DateTime now,
    required Set<DateTime> posted,
    bool offline = false,
    String language = 'en',
  }) {
    final service = HukamnamaService(
      client: MockClient((request) async {
        final day = request.bodyFields['selected_date']!;
        asked.add(day);
        if (offline) throw const SocketException('Failed host lookup');
        final date = DateTime.parse('${day}T00:00:00Z');
        return http.Response.bytes(
          posted.contains(date) ? _bodyFor(date) : _notPosted(date),
          200,
        );
      }),
    );
    addTearDown(service.close);
    return prepareWidgetRefresh(
      language: language,
      now: now,
      service: service,
      cache: cache,
    );
  }

  test('fetches today\'s Hukamnama in the morning and stores it', () async {
    final refresh = await run(now: morning, posted: {nov1, nov2});

    expect(refresh.current, isTrue);
    expect(refresh.data[WidgetKeys.hukamnamaMeta], startsWith('2 Nov'));
    expect(refresh.data[WidgetKeys.line], contains('ਰਹਾਉ'));
    // The app finds the same text on disk when it next opens.
    expect((await cache.readLatest())!.date, nov2);
    expect(asked, ['2026-11-02']);
  });

  test('asks for nothing when today\'s text is already on disk', () async {
    await cache.write(Hukamnama.fromSgpc(
      jsonDecode(utf8.decode(_bodyFor(nov2))) as Map<String, dynamic>,
    ));

    final refresh = await run(now: morning, posted: {nov2});

    expect(refresh.current, isTrue);
    expect(asked, isEmpty);
  });

  test('just after midnight it keeps yesterday\'s text and says it is not '
      'today\'s', () async {
    final refresh = await run(now: justAfterMidnight, posted: {nov1});

    expect(refresh.current, isFalse);
    expect(refresh.data[WidgetKeys.hukamnamaMeta], startsWith('1 Nov'));
    // The date has moved on, which is the point of this run.
    expect(refresh.data[WidgetKeys.dates], contains('"2026-11-02"'));
    // Today's was asked for, then yesterday's. Both once.
    expect(asked, ['2026-11-02', '2026-11-01']);
  });

  test('offline, it falls back to the text on disk', () async {
    await cache.write(Hukamnama.fromSgpc(
      jsonDecode(utf8.decode(_bodyFor(nov1))) as Map<String, dynamic>,
    ));

    final refresh = await run(now: morning, posted: {}, offline: true);

    expect(refresh.current, isFalse);
    expect(refresh.data[WidgetKeys.hukamnamaMeta], startsWith('1 Nov'));
  });

  test('offline with nothing on disk, it still writes the dates', () async {
    final refresh = await run(now: morning, posted: {}, offline: true);

    expect(refresh.current, isFalse);
    expect(refresh.data.containsKey(WidgetKeys.line), isFalse);
    expect(refresh.data[WidgetKeys.dates], contains('2026-11-02'));
  });

  test('writes in the language it is given', () async {
    final refresh = await run(
      now: morning,
      posted: {nov2},
      language: 'pa',
    );

    expect(refresh.data[WidgetKeys.language], 'pa');
    final labels = jsonDecode(refresh.data[WidgetKeys.labels]!) as Map;
    expect((labels['live'] as Map)['idle'], 'ਲਾਈਵ ਕੀਰਤਨ ਚਲਾਓ');
  });

  test('uses the SGPC day, not the phone\'s', () async {
    // 20:00 UTC on 1 November is 01:30 IST on 2 November.
    final refresh = await run(
      now: DateTime.utc(2026, 11, 1, 20),
      posted: {nov1, nov2},
    );

    expect(asked.first, '2026-11-02');
    expect(refresh.data[WidgetKeys.dates], startsWith('{"2026-11-02"'));
  });
}
