import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/models/hukamnama.dart';
import 'package:live_darbar/src/services/hukamnama_cache.dart';

Hukamnama textFor(DateTime day, {String line = 'ਸਲੋਕੁ ॥'}) => Hukamnama(
      date: day,
      ang: 668,
      headingGurmukhi: 'ਧਨਾਸਰੀ ਮਹਲਾ ੪॥',
      headingEnglish: 'DHANAASAREE, FOURTH MEHL:',
      lines: [HukamnamaLine(gurmukhi: line)],
      punjabiMeaning: 'ਸਲੋਕ।',
      englishMeaning: 'Shalok.',
      footerGurmukhi: 'ਸੋਮਵਾਰ, ੧੭ ਕੱਤਕ',
      footerEnglish: 'Monday, 17th Katak',
    );

void main() {
  final nov1 = DateTime.utc(2026, 11, 1);
  final nov2 = DateTime.utc(2026, 11, 2);
  late Directory dir;
  late HukamnamaCache cache;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('hukamnama_cache_test');
    cache = HukamnamaCache(directory: () async => dir);
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  List<String> filesOnDisk() =>
      dir.listSync().map((e) => e.uri.pathSegments.last).toList()..sort();

  group('HukamnamaCache', () {
    test('misses when nothing is stored', () async {
      expect(await cache.read(nov2), isNull);
      expect(await cache.readLatest(), isNull);
    });

    test('returns what was written, keyed by the day of the text', () async {
      await cache.write(textFor(nov2));

      final read = await cache.read(nov2);
      expect(read, isNotNull);
      expect(read!.date, nov2);
      expect(read.ang, 668);
      expect(read.headingGurmukhi, 'ਧਨਾਸਰੀ ਮਹਲਾ ੪॥');
      expect(read.headingEnglish, 'DHANAASAREE, FOURTH MEHL:');
      expect(read.lines.single.gurmukhi, 'ਸਲੋਕੁ ॥');
      expect(read.punjabiMeaning, 'ਸਲੋਕ।');
      expect(read.englishMeaning, 'Shalok.');
      expect(read.footerGurmukhi, 'ਸੋਮਵਾਰ, ੧੭ ਕੱਤਕ');
      expect(read.footerEnglish, 'Monday, 17th Katak');
      expect(filesOnDisk(), ['hukamnama_2026_11_02.json']);
    });

    test('returns a parsed SGPC response whole', () async {
      final parsed = Hukamnama.fromSgpc(jsonDecode(
        File('test/fixtures/sgpc_hukamnama_2026_11_02.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>);
      await cache.write(parsed);

      final read = (await cache.read(nov2))!;
      expect(read.lines, parsed.lines);
      expect(read.lines, hasLength(10));
      expect(read.punjabiMeaning, parsed.punjabiMeaning);
      expect(read.englishMeaning, parsed.englishMeaning);
      expect(read.toJson(), parsed.toJson());
    });

    test('does not hand out yesterday\'s text for today', () async {
      await cache.write(textFor(nov1));
      expect(await cache.read(nov2), isNull);
      // It is still there to open on, with its own date on it.
      expect((await cache.readLatest())!.date, nov1);
    });

    test('keeps only the newest day', () async {
      await cache.write(textFor(nov1));
      await cache.write(textFor(nov2));
      expect(filesOnDisk(), ['hukamnama_2026_11_02.json']);
      expect(await cache.read(nov1), isNull);
      expect((await cache.readLatest())!.date, nov2);
    });

    test('does not let an older day push out a newer one', () async {
      await cache.write(textFor(nov2));
      await cache.write(textFor(nov1));
      expect(filesOnDisk(), ['hukamnama_2026_11_02.json']);
      expect((await cache.readLatest())!.date, nov2);
    });

    test('rejects a file whose date does not match its name', () async {
      // A copy or a rename must not be able to pass old text off as new.
      await File('${dir.path}/hukamnama_2026_11_02.json')
          .writeAsString(jsonEncode(textFor(nov1).toJson()));
      expect(await cache.read(nov2), isNull);
      expect(await cache.readLatest(), isNull);
    });

    test('treats a corrupt file as a miss and recovers on the next write',
        () async {
      await File('${dir.path}/hukamnama_2026_11_02.json')
          .writeAsString('{"version": 1, "date": "2026-11-0');
      expect(await cache.read(nov2), isNull);
      expect(await cache.readLatest(), isNull);

      await cache.write(textFor(nov2));
      expect((await cache.read(nov2))!.date, nov2);
    });

    test('falls through a corrupt newest file to the next one', () async {
      await cache.write(textFor(nov1));
      await File('${dir.path}/hukamnama_2026_11_02.json').writeAsString('nope');
      expect((await cache.readLatest())!.date, nov1);
    });

    test('ignores a file from a version it does not know', () async {
      final future = textFor(nov2).toJson()..['version'] = 99;
      await File('${dir.path}/hukamnama_2026_11_02.json')
          .writeAsString(jsonEncode(future));
      expect(await cache.read(nov2), isNull);
    });

    test('treats an early build\'s version 1 file as a miss and replaces it',
        () async {
      // Version 1 had a raag, a writer and a meaning on each line. Its shape
      // is not read, so a phone that updates fetches today again.
      await File('${dir.path}/hukamnama_2026_11_02.json').writeAsString(
        jsonEncode({
          'version': 1,
          'date': '2026-11-02',
          'ang': 668,
          'raag': 'Raag Dhanaasree',
          'writer': 'Guru Raam Daas Ji',
          'lines': [
            {'gurmukhi': 'ਧਨਾਸਰੀ ਮਹਲਾ ੪ ॥', 'english': 'Dhanaasaree.'},
          ],
        }),
      );
      expect(await cache.read(nov2), isNull);
      expect(await cache.readLatest(), isNull);

      await cache.write(textFor(nov2));
      expect((await cache.read(nov2))!.headingEnglish, isNotNull);
    });

    test('ignores files that are not its own', () async {
      await File('${dir.path}/mukhwak_2026_11_02.pdf').writeAsString('pdf');
      await cache.write(textFor(nov2));
      expect(filesOnDisk(), containsAll(['mukhwak_2026_11_02.pdf']));
      expect(filesOnDisk(), contains('hukamnama_2026_11_02.json'));
    });

    test('sweeps temp files a crash left behind', () async {
      final leftover = File('${dir.path}/hukamnama_2026_10_30.json.tmp');
      await leftover.writeAsString('{"half a wri');
      await leftover.setLastModified(
        DateTime.now().subtract(const Duration(hours: 3)),
      );

      await cache.write(textFor(nov2));

      expect(filesOnDisk(), ['hukamnama_2026_11_02.json']);
    });

    test('leaves a young temp file alone, it may be a write in progress',
        () async {
      final inProgress = File('${dir.path}/hukamnama_2026_11_03.json.tmp');
      await inProgress.writeAsString('{"being wri');

      await cache.write(textFor(nov2));

      expect(filesOnDisk(), [
        'hukamnama_2026_11_02.json',
        'hukamnama_2026_11_03.json.tmp',
      ]);
    });

    test('creates the directory when it does not exist yet', () async {
      final nested = Directory('${dir.path}/a/b');
      final c = HukamnamaCache(directory: () async => nested);
      await c.write(textFor(nov2));
      expect((await c.read(nov2))!.date, nov2);
    });

    test('is a quiet miss when the platform has no directory', () async {
      // The web build: path_provider has nothing to return.
      final broken = HukamnamaCache(
        directory: () async => throw UnsupportedError('no directory'),
      );
      expect(await broken.read(nov2), isNull);
      expect(await broken.readLatest(), isNull);
      await broken.write(textFor(nov2)); // must not throw
    });
  });
}
