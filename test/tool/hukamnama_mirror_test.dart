import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/models/hukamnama.dart';
import 'package:live_darbar/src/models/sgpc_day.dart' as app;

import '../../tool/hukamnama_mirror.dart';
import '../../tool/shabad_os.dart';
import '../support/shabad_os_fixture.dart';

/// SGPC's real answer for 2 November 2026, as received and not edited.
final _recorded =
    File('test/fixtures/sgpc_hukamnama_2026_11_02.json').readAsBytesSync();

/// SGPC's real answer for a day it has no Hukamnama for.
final _notPublished = utf8.encode(
  '{"supported":false,"hukamnama":{"date":"2026-11-03","message":'
  '"No Hukamnama Available for this date."},"pdfFiles":[]}',
);

SgpcReply ok(List<int> body) => SgpcReply(200, body);

/// The recorded body after [change] edits the decoded JSON.
List<int> recordedWith(void Function(Map<String, dynamic> json) change) {
  final json = jsonDecode(utf8.decode(_recorded)) as Map<String, dynamic>;
  change(json);
  return utf8.encode(jsonEncode(json));
}

Map<String, dynamic> hukamnamaOf(Map<String, dynamic> json) =>
    json['hukamnama'] as Map<String, dynamic>;

/// A good answer for any [day]: the recorded text, with the date replaced.
List<int> goodFor(String day) =>
    recordedWith((json) => hukamnamaOf(json)['date'] = day);

void main() {
  group('checkSgpcReply', () {
    test('accepts the recorded answer for its own day', () {
      expect(checkSgpcReply(ok(_recorded), '2026-11-02'), isA<Accepted>());
    });

    test('reads "supported": false as not published yet', () {
      expect(
        checkSgpcReply(ok(_notPublished), '2026-11-03'),
        isA<NotPublished>(),
      );
    });

    group('rejects', () {
      void rejects(String name, SgpcReply reply, {String day = '2026-11-02'}) {
        test(name, () {
          final verdict = checkSgpcReply(reply, day);
          expect(verdict, isA<Rejected>(), reason: '$verdict');
        });
      }

      rejects('the answer for a different day', ok(_recorded),
          day: '2026-11-03');
      rejects(
        'a date that only looks like the day',
        ok(recordedWith((j) => hukamnamaOf(j)['date'] = '2026-11-02x')),
      );
      rejects(
        'a missing date',
        ok(recordedWith((j) => hukamnamaOf(j).remove('date'))),
      );
      rejects(
        'a date that is not a string',
        ok(recordedWith((j) => hukamnamaOf(j)['date'] = 20261102)),
      );
      rejects(
        'a missing Gurmukhi text',
        ok(recordedWith((j) => hukamnamaOf(j).remove('ghukamnama'))),
      );
      rejects(
        'a blank Gurmukhi text',
        ok(recordedWith((j) => hukamnamaOf(j)['ghukamnama'] = ' \n ')),
      );
      rejects(
        'a Gurmukhi text that is not a string',
        ok(recordedWith((j) => hukamnamaOf(j)['ghukamnama'] = ['ਹਰਿ'])),
      );
      rejects(
        'a missing "hukamnama" object',
        ok(recordedWith((j) => j.remove('hukamnama'))),
      );
      rejects(
        'a "hukamnama" that is not an object',
        ok(recordedWith((j) => j['hukamnama'] = 'text')),
      );
      rejects(
        'a missing "supported"',
        ok(recordedWith((j) => j.remove('supported'))),
      );
      rejects(
        'a "supported" that is not a boolean',
        ok(recordedWith((j) => j['supported'] = 'true')),
      );
      rejects('HTML instead of JSON', ok(utf8.encode('<html><body>Hi')));
      rejects(
        'an HTML error page with a 200 status',
        ok(utf8.encode('<!DOCTYPE html><title>Just a moment...</title>')),
      );
      rejects('an empty body, which SGPC sends without its header', ok([]));
      rejects('a JSON array', ok(utf8.encode('[1, 2]')));
      rejects('a JSON string', ok(utf8.encode('"supported"')));
      rejects('bytes that are not UTF-8', ok([0xff, 0xfe, 0x7b, 0x7d]));
      rejects('a good body with a 500 status', SgpcReply(500, _recorded));
      rejects('a good body with a 403 status', SgpcReply(403, _recorded));
      rejects('a good body with a 304 status', SgpcReply(304, _recorded));
    });

    test('does not need the optional fields, as the app does not', () {
      final body = recordedWith((j) {
        final h = hukamnamaOf(j);
        for (final key in [
          'ang',
          'gheading1',
          'eheading1',
          'ghukamnamadesc',
          'ehukamnamadesc',
          'gfooter1',
          'efooter1',
        ]) {
          h.remove(key);
        }
      });
      expect(checkSgpcReply(ok(body), '2026-11-02'), isA<Accepted>());
      expect(Hukamnama.fromSgpc(jsonDecode(utf8.decode(body))), isNotNull);
    });

    test('agrees with the app: accepted exactly when the app can parse it', () {
      final bodies = <List<int>>[
        _recorded,
        _notPublished,
        recordedWith((j) => hukamnamaOf(j).remove('date')),
        recordedWith((j) => hukamnamaOf(j)['date'] = '2026-13-45'),
        recordedWith((j) => hukamnamaOf(j)['date'] = '2026-11-03'),
        recordedWith((j) => hukamnamaOf(j).remove('ghukamnama')),
        recordedWith((j) => hukamnamaOf(j)['ghukamnama'] = '  '),
        recordedWith((j) => j['supported'] = false),
        recordedWith((j) => j.remove('hukamnama')),
        utf8.encode('<html>'),
        utf8.encode('{}'),
      ];
      for (final body in bodies) {
        final verdict = checkSgpcReply(ok(body), '2026-11-02');
        final json = _tryDecode(body);
        Hukamnama? parsed;
        try {
          parsed = Hukamnama.fromSgpc(json!);
        } on Object {
          parsed = null;
        }
        final appAccepts =
            parsed != null && parsed.date == DateTime.utc(2026, 11, 2);
        expect(verdict is Accepted, appAccepts, reason: utf8.decode(body));
      }
    });
  });

  group('SGPC day', () {
    test('matches the app for instants around the change of day', () {
      final instants = [
        DateTime.utc(2026, 11, 2, 18, 29, 59), // 23:59:59 IST on the 2nd
        DateTime.utc(2026, 11, 2, 18, 30), // 00:00 IST on the 3rd
        DateTime.utc(2026, 11, 2, 23, 30), // 05:00 IST on the 3rd
        DateTime.utc(2026, 12, 31, 18, 30),
        DateTime.utc(2028, 2, 28, 18, 30), // the day before a leap day
        DateTime.utc(2026, 3, 1),
      ];
      for (final instant in instants) {
        expect(
          dayIso(sgpcDayOf(instant)),
          app.sgpcDayIso(app.sgpcDayOf(instant)),
          reason: '$instant',
        );
        expect(
          dayIso(previousDay(sgpcDayOf(instant))),
          app.sgpcDayIso(app.previousSgpcDay(app.sgpcDayOf(instant))),
          reason: '$instant',
        );
      }
    });

    test('uses the same offset as the app', () {
      expect(kIndiaOffset, app.kIndiaOffset);
    });

    test('asks the same endpoint as the app', () {
      expect(kSgpcArchiveUrl, app.kHukamnamaArchiveUrl);
    });
  });

  group('namesToPrune', () {
    test('keeps 31 days, today included, and lists only older day files', () {
      final today = DateTime.utc(2026, 11, 3);
      final names = [
        '2026-11-03.json',
        '2026-10-04.json', // 30 days before: the 31st day, kept
        '2026-10-03.json', // 31 days before: pruned
        '2025-01-01.json',
        'latest.json',
        'README.md',
        '2026-13-45.json',
      ];
      expect(
        namesToPrune(names, today),
        ['2026-10-03.json', '2025-01-01.json'],
      );
    });

    test('keeps a day file dated in the future', () {
      expect(
        namesToPrune(['2027-01-01.json'], DateTime.utc(2026, 11, 3)),
        isEmpty,
      );
    });
  });

  group('mirror', () {
    // 17:30 IST on 2 November 2026: today is the 2nd, yesterday the 1st.
    final now = DateTime.utc(2026, 11, 2, 12);

    late Directory root;
    late List<String> asked;

    setUp(() {
      root = Directory.systemTemp.createTempSync('hukamnama_mirror_test');
      asked = [];
      addTearDown(() => root.deleteSync(recursive: true));
    });

    File file(String name) => File('${root.path}/hukamnama/$name');

    Future<MirrorReport> run(
      Future<SgpcReply> Function(String day) answer, {
      DateTime? at,
    }) =>
        mirror(
          root: root,
          now: at ?? now,
          fetch: (day) {
            asked.add(day);
            return answer(day);
          },
          pause: Duration.zero,
        );

    test('writes both days verbatim, and latest.json as the newest', () async {
      final report = await run(
        (day) async => ok(day == '2026-11-02' ? _recorded : goodFor(day)),
      );

      expect(report.exitCode, 0);
      expect(report.outcomes, {
        '2026-11-01': DayOutcome.written,
        '2026-11-02': DayOutcome.written,
      });
      expect(file('2026-11-02.json').readAsBytesSync(), _recorded);
      expect(file('2026-11-01.json').readAsBytesSync(), goodFor('2026-11-01'));
      expect(file('latest.json').readAsBytesSync(), _recorded);
      expect(asked, unorderedEquals(['2026-11-01', '2026-11-02']));
    });

    test('a second run with the same answers changes nothing', () async {
      Future<SgpcReply> answer(String day) async => ok(goodFor(day));
      await run(answer);
      final report = await run(answer);

      expect(report.outcomes.values, everyElement(DayOutcome.unchanged));
      expect(report.exitCode, 0);
    });

    test('exits 0 and uses yesterday while today is not published', () async {
      final report = await run(
        (day) async => ok(day == '2026-11-02' ? _notPublished : goodFor(day)),
      );

      expect(report.exitCode, 0);
      expect(report.outcomes['2026-11-02'], DayOutcome.notPublished);
      expect(report.warnings, isEmpty);
      expect(file('2026-11-02.json').existsSync(), isFalse);
      expect(file('latest.json').readAsBytesSync(), goodFor('2026-11-01'));
    });

    test('warns, and still exits 0, when yesterday is not published', () async {
      final report = await run(
        (day) async => ok(day == '2026-11-01' ? _notPublished : goodFor(day)),
      );

      expect(report.exitCode, 0);
      expect(report.outcomes['2026-11-01'], DayOutcome.notPublished);
      expect(report.warnings, hasLength(1));
      expect(file('latest.json').readAsBytesSync(), goodFor('2026-11-02'));
    });

    test('a bad answer never replaces a good file', () async {
      await run((day) async => ok(goodFor(day)));
      final before = file('2026-11-02.json').readAsBytesSync();
      final latestBefore = file('latest.json').readAsBytesSync();

      final report = await run((day) async {
        if (day == '2026-11-02') return ok(utf8.encode('<html>Maintenance'));
        return ok(goodFor(day));
      });

      expect(report.exitCode, 1);
      expect(report.outcomes['2026-11-02'], DayOutcome.failed);
      expect(report.outcomes['2026-11-01'], DayOutcome.unchanged);
      expect(report.errors.single, contains('2026-11-02'));
      expect(file('2026-11-02.json').readAsBytesSync(), before);
      expect(file('latest.json').readAsBytesSync(), latestBefore);
    });

    test('a failed day does not stop the other day', () async {
      final report = await run((day) async {
        if (day == '2026-11-01') return SgpcReply(500, const []);
        return ok(goodFor(day));
      });

      expect(report.exitCode, 1);
      expect(report.outcomes['2026-11-01'], DayOutcome.failed);
      expect(report.outcomes['2026-11-02'], DayOutcome.written);
      expect(file('2026-11-01.json').existsSync(), isFalse);
    });

    test('leaves no files behind when SGPC cannot be reached', () async {
      final report = await run(
        (day) async => throw const SocketException('Failed host lookup'),
      );

      expect(report.exitCode, 1);
      expect(report.errors, hasLength(2));
      expect(report.errors.first, contains('Failed host lookup'));
      expect(file('latest.json').existsSync(), isFalse);
      expect(
        Directory('${root.path}/hukamnama').listSync(),
        isEmpty,
      );
    });

    test('tries again before it gives up', () async {
      var calls = 0;
      final report = await run((day) async {
        calls++;
        // The first answer for each day is bad. The retry is good.
        return calls.isOdd ? SgpcReply(503, const []) : ok(goodFor(day));
      });

      expect(report.exitCode, 0);
      expect(report.outcomes.values, everyElement(DayOutcome.written));
      expect(asked, hasLength(4));
    });

    test('gives up after 3 tries for a day', () async {
      await run((day) async => SgpcReply(500, const []));
      expect(asked.where((d) => d == '2026-11-02'), hasLength(3));
    });

    test('latest.json never goes back to an older day', () async {
      await run((day) async => ok(goodFor(day)));
      // Today is unreachable on the next run, but yesterday still answers.
      await run((day) async {
        if (day == '2026-11-02') return SgpcReply(500, const []);
        return ok(goodFor(day));
      });

      expect(file('latest.json').readAsBytesSync(), goodFor('2026-11-02'));
    });

    test('deletes day files older than 31 days and nothing else', () async {
      Directory('${root.path}/hukamnama').createSync(recursive: true);
      // Today is 2 November, so 3 October is the 31st day.
      file('2026-10-03.json').writeAsStringSync('oldest kept');
      file('2026-10-02.json').writeAsStringSync('old');
      file('2026-09-01.json').writeAsStringSync('older');
      file('notes.txt').writeAsStringSync('mine');

      await run((day) async => ok(goodFor(day)));

      expect(file('2026-10-03.json').existsSync(), isTrue);
      expect(file('2026-10-02.json').existsSync(), isFalse);
      expect(file('2026-09-01.json').existsSync(), isFalse);
      expect(file('notes.txt').existsSync(), isTrue);
      expect(file('latest.json').existsSync(), isTrue);
    });

    test('names the SGPC day in India, not the UTC day', () async {
      // 23:30 UTC on the 2nd is 05:00 IST on the 3rd.
      await run(
        (day) async => ok(goodFor(day)),
        at: DateTime.utc(2026, 11, 2, 23, 30),
      );
      expect(asked, unorderedEquals(['2026-11-02', '2026-11-03']));
    });
  });

  group('mirror with lines', () {
    final now = DateTime.utc(2026, 11, 2, 12);

    late Directory root;
    setUp(() {
      root = Directory.systemTemp.createTempSync('hukamnama_lines_test');
      addTearDown(() => root.deleteSync(recursive: true));
    });

    File file(String name) => File('${root.path}/hukamnama/$name');

    Map<String, dynamic> read(String name) =>
        jsonDecode(file(name).readAsStringSync()) as Map<String, dynamic>;

    Future<MirrorReport> run(
      Future<SgpcReply> Function(String day) answer,
      LinesProvider? lines, {
      int days = 2,
    }) =>
        mirror(
          root: root,
          now: now,
          fetch: answer,
          pause: Duration.zero,
          days: days,
          lines: lines,
        );

    Future<SgpcReply> recorded(String day) async =>
        ok(day == '2026-11-02' ? _recorded : goodFor(day));

    test('adds shabad and lines beside what SGPC sent', () async {
      final provider = _FakeLines();
      final report = await run(recorded, provider);

      expect(report.exitCode, 0);
      expect(report.outcomes.values, everyElement(DayOutcome.written));
      final day = read('2026-11-02.json');
      final sgpc = jsonDecode(utf8.decode(_recorded)) as Map<String, dynamic>;
      // SGPC's keys come first, unchanged, and the new keys follow.
      expect(day.keys.toList(), [...sgpc.keys, 'shabad', 'lines']);
      for (final key in sgpc.keys) {
        expect(day[key], sgpc[key], reason: key);
      }
      expect(day['shabad'], containsPair('matched', true));
      expect(day['lines'], hasLength(2));
      expect(report.lineNotes['2026-11-02'], contains('matched, 2 lines'));
    });

    test('hands the provider the hukamnama object of the day', () async {
      final provider = _FakeLines();
      await run(recorded, provider);

      final asked = provider.asked.firstWhere((h) => h['date'] == '2026-11-02');
      expect(asked['ang'], '668');
      expect(asked['ghukamnama'], startsWith('ਹਰਿ ਹਰਿ ਬੂੰਦ'));
    });

    test('an old app and the new app both read the file', () async {
      await run(recorded, _FakeLines());
      final day = read('2026-11-02.json');

      // The parser of the app ignores keys it does not know.
      final parsed = Hukamnama.fromSgpc(day);
      expect(parsed.date, DateTime.utc(2026, 11, 2));
      expect(parsed.ang, 668);
      expect(parsed.lines, hasLength(10));
      expect(parsed.shabad, isNotNull);
      expect(parsed.shabad!.lines.first.english, 'First line.');
      expect(parsed.shabad!.ids, ['TEST']);
    });

    test('a second run does not ask the provider again', () async {
      final provider = _FakeLines();
      await run(recorded, provider);
      provider.asked.clear();
      final report = await run(recorded, provider);

      expect(provider.asked, isEmpty);
      expect(report.outcomes.values, everyElement(DayOutcome.unchanged));
      expect(report.lineNotes['2026-11-02'], startsWith('kept'));
    });

    test('a day that did not match is not asked again either', () async {
      final provider = _FakeLines(matched: false);
      await run(recorded, provider);
      final day = read('2026-11-02.json');

      expect(day['shabad'], containsPair('matched', false));
      expect(day['shabad'], containsPair('reason', 'No run matches.'));
      expect(day.containsKey('lines'), isFalse);
      expect(Hukamnama.fromSgpc(day).shabad, isNull);

      provider.asked.clear();
      await run(recorded, provider);
      expect(provider.asked, isEmpty);
    });

    test('looks again when SGPC changes the text of a day', () async {
      final provider = _FakeLines();
      await run(recorded, provider);
      provider.asked.clear();

      final changed = recordedWith((json) {
        hukamnamaOf(json)['ehukamnamadesc'] = 'A corrected meaning.';
      });
      final report = await run(
        (day) async => ok(day == '2026-11-02' ? changed : goodFor(day)),
        provider,
      );

      expect(provider.asked.map((h) => h['date']), ['2026-11-02']);
      expect(report.outcomes['2026-11-02'], DayOutcome.written);
      expect(report.outcomes['2026-11-01'], DayOutcome.unchanged);
    });

    test('looks again when the database or the matching rules change',
        () async {
      await run(recorded, _FakeLines());
      final newer = _FakeLines(stamp: {
        ..._FakeLines.defaultStamp,
        'matcher': 2,
      });
      final report = await run(recorded, newer);

      expect(newer.asked, hasLength(2));
      expect(report.outcomes.values, everyElement(DayOutcome.written));
      expect(read('2026-11-02.json')['shabad'], containsPair('matcher', 2));
    });

    test('adds lines to a day that an earlier run wrote without them',
        () async {
      await run(recorded, null);
      expect(file('2026-11-02.json').readAsBytesSync(), _recorded);

      final report = await run(recorded, _FakeLines());
      expect(report.outcomes['2026-11-02'], DayOutcome.written);
      expect(read('2026-11-02.json'), contains('lines'));
    });

    test('writes SGPC as it came, and warns, when the provider throws',
        () async {
      final report = await run(recorded, _FakeLines(failWith: 'no database'));

      expect(report.exitCode, 0);
      expect(report.errors, isEmpty);
      expect(report.warnings, hasLength(2));
      expect(report.warnings.first, contains('no database'));
      expect(report.outcomes.values, everyElement(DayOutcome.written));
      expect(file('2026-11-02.json').readAsBytesSync(), _recorded);
      expect(report.lineNotes['2026-11-02'], 'left out');
    });

    test('keeps the lines of the day when the provider then throws', () async {
      await run(recorded, _FakeLines());
      final before = file('2026-11-02.json').readAsBytesSync();

      final report = await run(
        recorded,
        _FakeLines(
          failWith: 'no database',
          stamp: {..._FakeLines.defaultStamp, 'matcher': 2},
        ),
      );

      expect(report.exitCode, 0);
      expect(file('2026-11-02.json').readAsBytesSync(), before);
      expect(report.outcomes['2026-11-02'], DayOutcome.unchanged);
    });

    test('puts the same bytes in latest.json as in the newest day', () async {
      await run(recorded, _FakeLines());
      expect(
        file('latest.json').readAsBytesSync(),
        file('2026-11-02.json').readAsBytesSync(),
      );
    });

    test('gives a bad answer no lines and keeps the good file', () async {
      final provider = _FakeLines();
      await run(recorded, provider);
      final before = file('2026-11-02.json').readAsBytesSync();
      provider.asked.clear();

      final report = await run(
        (day) async => day == '2026-11-02'
            ? ok(utf8.encode('<html>Maintenance'))
            : recorded(day),
        provider,
      );

      expect(report.exitCode, 1);
      expect(provider.asked, isEmpty);
      expect(file('2026-11-02.json').readAsBytesSync(), before);
    });

    test('mirrors the days asked for, the oldest first', () async {
      final asked = <String>[];
      await run((day) async {
        asked.add(day);
        return ok(goodFor(day));
      }, null, days: 4);

      expect(asked, ['2026-10-30', '2026-10-31', '2026-11-01', '2026-11-02']);
    });

    test('mirrors at most 31 days and at least 1', () async {
      final asked = <String>[];
      Future<SgpcReply> answer(String day) async {
        asked.add(day);
        return ok(goodFor(day));
      }

      await run(answer, null, days: 99);
      expect(asked, hasLength(kKeepDays));
      asked.clear();
      await run(answer, null, days: 0);
      expect(asked, ['2026-11-02']);
    });

    test(
        'writes what the real provider finds, and that is the file that the '
        'app tests read', () async {
      final dir = Directory('${root.path}/db')..createSync();
      final database = buildShabadOsDatabase(dir);
      final provider = ShabadOsLines(
        ShabadOsDatabase(
          database,
          expectedBytes: database.lengthSync(),
          download: (_) async => fail('It must not download.'),
        ),
      );
      await run(recorded, provider);

      final golden = jsonDecode(
        File('test/fixtures/mirror_hukamnama_2026_11_02.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(read('2026-11-02.json'), golden);
    }, skip: hasSqlite ? false : 'sqlite3 is not installed');
  });
}

Map<String, dynamic>? _tryDecode(List<int> body) {
  try {
    final json = jsonDecode(utf8.decode(body));
    return json is Map<String, dynamic> ? json : null;
  } on FormatException {
    return null;
  }
}

/// A [LinesProvider] that gives 2 fixed lines, and remembers what it was asked.
class _FakeLines implements LinesProvider {
  _FakeLines({
    this.matched = true,
    this.failWith,
    Map<String, Object?>? stamp,
  }) : stamp = stamp ?? defaultStamp;

  static const defaultStamp = <String, Object?>{
    'source': 'Test',
    'version': '1',
    'matcher': 1,
  };

  final bool matched;
  final String? failWith;
  final asked = <Map<String, dynamic>>[];

  @override
  final Map<String, Object?> stamp;

  @override
  Future<LinesResult> linesFor(Map<String, dynamic> hukamnama) async {
    asked.add(hukamnama);
    if (failWith != null) throw StateError(failWith!);
    if (!matched) {
      return LinesResult(
          {...stamp, 'matched': false, 'reason': 'No run matches.'});
    }
    return LinesResult(
      {
        ...stamp,
        'matched': true,
        'ids': ['TEST'],
        'ang': 668,
        'angEnd': 668,
      },
      [
        {
          'id': 'AAAA',
          'ang': 668,
          'gurmukhi': 'ਇੱਕ ॥',
          'english': 'First line.'
        },
        {'id': 'BBBB', 'ang': 668, 'gurmukhi': 'ਦੋ ॥'},
      ],
    );
  }
}
