import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/shabad_os.dart';
import '../support/shabad_os_fixture.dart';

/// SGPC's real answers for 2 and 3 November 2026, as received.
Map<String, dynamic> _sgpc(String name) => (jsonDecode(
      File('test/fixtures/sgpc_hukamnama_$name.json').readAsStringSync(),
    ) as Map<String, dynamic>)['hukamnama'] as Map<String, dynamic>;

/// The Gurmukhi lines of the fixture in the order of the Granth, the way the
/// query in [ShabadOsLines.linesOnPages] gives them.
List<ShabadLine> _allLines() {
  final byLine = {for (final r in shabadOsRows('lines')) r['id']: r};
  final byGroup = {for (final r in shabadOsRows('line_groups')) r['id']: r};
  final bySection = {for (final r in shabadOsRows('sections')) r['id']: r};
  final rows = [
    for (final r in shabadOsRows('asset_lines'))
      if (r['asset_id'] == kGurmukhiAsset) r,
  ];
  int key(Map<String, dynamic> r, int i) {
    final line = byLine[r['line_id']]!;
    final group = byGroup[line['line_group_id']]!;
    final section = bySection[group['section_id']]!;
    return [
      (section['source_order'] as int),
      (group['section_order'] as int),
      (line['line_group_order'] as int),
    ][i];
  }

  int page(Map<String, dynamic> r) =>
      (jsonDecode(r['additional'] as String) as Map)['page'] as int;

  rows.sort((a, b) {
    for (final compare in [
      page(a).compareTo(page(b)),
      key(a, 0).compareTo(key(b, 0)),
      key(a, 1).compareTo(key(b, 1)),
      key(a, 2).compareTo(key(b, 2)),
    ]) {
      if (compare != 0) return compare;
    }
    return 0;
  });
  return [
    for (final r in rows)
      ShabadLine(
        id: r['line_id'] as String,
        groupId: byLine[r['line_id']]!['line_group_id'] as String,
        page: page(r),
        text: r['data'] as String,
      ),
  ];
}

/// The lines [ShabadOsLines] would fetch for a shabad that starts on [ang].
List<ShabadLine> _window(int ang) => [
      for (final line in _allLines())
        if (line.page >= ang && line.page <= ang + kMaxExtraPages) line,
    ];

/// The ids of the 10 lines of the Hukamnama of 2 November (without the title
/// line `ਧਨਾਸਰੀ ਮਹਲਾ ੪ ॥`, which SGPC prints apart as the heading).
const _nov2Ids = [
  '015H',
  'J066',
  'T35Q',
  '8T6Y',
  'Q1E7',
  'LHMA',
  'E34W',
  'ZHAQ',
  'UY9H',
  'NEFV',
];

void main() {
  group('lettersOf', () {
    test('keeps the letters and drops everything that is not a word', () {
      // The pause marks, the spaces, the verse number and the ॥ signs.
      expect(
        lettersOf('ਹਰਿ ਬਿਨੁ. ਰਹਿ ਨ ਸਕਉ; ਇਕ ਰਾਤੀ ॥੧॥'),
        lettersOf('ਹਰਿ ਬਿਨੁ ਰਹਿ ਨ ਸਕਉ ਇਕ ਰਾਤੀ'),
      );
      expect(lettersOf('ਹਰਿ ਹਰਿ ॥੧॥ ਰਹਾਉ ॥'), 'ਹਰਿਹਰਿਰਹਾਉ');
      expect(lettersOf('1 2 3 ੧ ੨ ,;.|'), isEmpty);
    });

    test('reads a letter with a nukta the same in both spellings', () {
      // The code points are spelled out, so that no tool turns one spelling
      // into the other.
      String text(List<int> runes) => 'ਕ${String.fromCharCodes(runes)}ਰ';
      expect(lettersOf(text([0x0a36])), lettersOf(text([0x0a38, 0x0a3c])));
      expect(lettersOf(text([0x0a5b])), lettersOf(text([0x0a1c, 0x0a3c])));
      expect(lettersOf(text([0x0a5e])), lettersOf(text([0x0a2b, 0x0a3c])));
    });

    test('reads the bindi, the adak bindi and the tippi alike', () {
      String text(int sign) => 'ਸ${String.fromCharCode(sign)}';
      expect(lettersOf(text(0x0a02)), lettersOf(text(0x0a70)));
      expect(lettersOf(text(0x0a01)), lettersOf(text(0x0a70)));
    });

    test('drops a zero width joiner and a variation selector', () {
      final joiner = String.fromCharCode(0x200d);
      final selector = String.fromCharCode(0xfe00);
      expect(lettersOf('ਕ' '$joiner' 'ਰ$selector'), 'ਕਰ');
    });
  });

  group('similarity', () {
    test('is 1 for the same text and counts the edits', () {
      expect(similarity('ਹਰਿ', 'ਹਰਿ'), 1);
      expect(similarity('abcd', 'abxd'), 0.75);
      expect(similarity('abcd', 'abc'), 0.75);
      expect(similarity('', ''), 1);
      expect(similarity('abc', ''), 0);
    });
  });

  group('splitVishraam', () {
    test('takes each mark off its word and says where it was', () {
      final line = splitVishraam('ਹਰਿ ਬਿਨੁ. ਰਹਿ ਨ ਸਕਉ; ਇਕ ਰਾਤੀ ॥');
      expect(line.text, 'ਹਰਿ ਬਿਨੁ ਰਹਿ ਨ ਸਕਉ ਇਕ ਰਾਤੀ ॥');
      expect(line.vishraam, const [
        Vishraam(1, VishraamWeight.light),
        Vishraam(4, VishraamWeight.heavy),
      ]);
    });

    test('knows the 3 weights', () {
      final line = splitVishraam('ਛਾਡਿ ਮਨ; ਹਰਿ, ਬਿਮੁਖਨ. ਕੋ ਸੰਗੁ ॥');
      expect(line.text, 'ਛਾਡਿ ਮਨ ਹਰਿ ਬਿਮੁਖਨ ਕੋ ਸੰਗੁ ॥');
      expect(line.vishraam.map((v) => v.weight), [
        VishraamWeight.heavy,
        VishraamWeight.medium,
        VishraamWeight.light,
      ]);
    });

    test('leaves a line with no mark as it is, with single spaces', () {
      final line = splitVishraam('  ਧਨਾਸਰੀ   ਮਹਲਾ ੪ ॥ ');
      expect(line.text, 'ਧਨਾਸਰੀ ਮਹਲਾ ੪ ॥');
      expect(line.vishraam, isEmpty);
    });

    test('leaves a sign that is alone in the text', () {
      expect(splitVishraam('ਕ ; ਖ').text, 'ਕ ; ਖ');
      expect(splitVishraam('ਕ ; ਖ').vishraam, isEmpty);
    });

    test('changes no word and keeps a zero width joiner', () {
      final word = 'ਪ${String.fromCharCode(0x200d)}ਰ';
      final line = splitVishraam('$word ਨਾਮ;');
      expect(line.text, '$word ਨਾਮ');
    });

    test('writes a mark as JSON', () {
      expect(
        const Vishraam(5, VishraamWeight.heavy).toJson(),
        {'after': 5, 'weight': 'heavy'},
      );
    });
  });

  group('matchShabad', () {
    final nov2 = _sgpc('2026_11_02');
    final nov3 = _sgpc('2026_11_03');

    ShabadMatch match(
      Map<String, dynamic> day, {
      int? ang,
      String? text,
      List<ShabadLine>? candidates,
    }) {
      final a = ang ?? int.parse(day['ang'] as String);
      return matchShabad(
        candidates: candidates ?? _window(a),
        sgpcText: text ?? day['ghukamnama'] as String,
        ang: a,
      );
    }

    test('finds the 10 lines of 2 November on Ang 668', () {
      final result = match(nov2);
      expect(result, isA<Matched>());
      result as Matched;
      final run = _window(668).sublist(result.start, result.end);
      expect([for (final l in run) l.id], _nov2Ids);
      expect(result.similarity, 1);
    });

    test('finds the 10 lines of 3 November on Ang 877', () {
      final result = match(nov3);
      expect(result, isA<Matched>());
      result as Matched;
      final run = _window(877).sublist(result.start, result.end);
      expect(run, hasLength(10));
      expect({for (final l in run) l.groupId}, {'XQM'});
    });

    test('leaves out the title line, which SGPC prints apart', () {
      final all = _window(668);
      final result = match(nov2) as Matched;
      expect(all[result.start - 1].text, startsWith('ਧਨਾਸਰੀ ਮਹਲਾ'));
    });

    test('accepts a few letters of difference', () {
      // SGPC prints ਚਰਣੀ where Shabad OS has ਚਰਣ, so one letter can differ.
      final text = (nov2['ghukamnama'] as String).replaceFirst('ਹਰਿ', 'ਹਰ');
      final result = match(nov2, text: text);
      expect(result, isA<Matched>());
      expect((result as Matched).similarity, lessThan(1));
      expect(result.similarity, greaterThanOrEqualTo(kMinSimilarity));
    });

    test('ignores spaces, pause marks and verse numbers', () {
      final text = (nov2['ghukamnama'] as String)
          .replaceAll('॥', '')
          .replaceAll(RegExp(r'[੧-੯]'), '')
          .replaceAll(' ', '   ');
      expect(match(nov2, text: text), isA<Matched>());
    });

    test('refuses the right text on the wrong Ang', () {
      final result = match(nov2, ang: 669, candidates: _window(668));
      expect(result, isA<NoMatch>());
      expect((result as NoMatch).reason, contains('Ang 669'));
    });

    test('refuses a text that is not on the Ang', () {
      final result = match(nov3, ang: 668, candidates: _window(668));
      expect(result, isA<NoMatch>());
    });

    test('refuses a text that is mostly different', () {
      // The first half is right and the end is from another shabad.
      final others = _window(877).where((l) => l.groupId == 'XQM').toList();
      final text = (nov2['ghukamnama'] as String).substring(0, 240) +
          others.take(5).map((l) => l.text).join(' ');
      final result = match(nov2, text: text);
      expect(result, isA<NoMatch>(), reason: '$result');
    });

    test('refuses a run that has a line that SGPC does not have', () {
      final lines = splitHukamnamaLinesForTest(nov2['ghukamnama'] as String);
      lines.removeAt(3);
      final result = match(nov2, text: lines.join(' '));
      expect(result, isA<NoMatch>(), reason: '$result');
    });

    test('refuses a short extra line even when the rest matches', () {
      // 4 letters in 400 are 1 percent, which the whole text allows. The check
      // of each line does not.
      final run = _window(668).where((l) => _nov2Ids.contains(l.id)).toList();
      final withExtra = [
        ...run.take(4),
        const ShabadLine(
          id: 'EXTRA',
          groupId: 'R5B',
          page: 668,
          text: 'ਅਕਾਲ ॥',
        ),
        ...run.skip(4),
      ];
      final result = match(nov2, candidates: withExtra);
      expect(result, isA<NoMatch>(), reason: '$result');
      expect((result as NoMatch).reason, contains('EXTRA'));
    });

    test('refuses a text that is too short to be sure of', () {
      final result = match(nov2, text: 'ਹਰਿ ਹਰਿ ॥');
      expect(result, isA<NoMatch>());
      expect((result as NoMatch).reason, contains('letters'));
    });

    test('refuses when 2 runs match as well as each other', () {
      final run = _window(668)
          .where((l) => _nov2Ids.contains(l.id))
          .toList(growable: false);
      final copy = [
        for (final l in run)
          ShabadLine(
            id: 'Z${l.id.substring(1)}',
            groupId: 'COPY',
            page: l.page,
            text: l.text,
          ),
      ];
      final result = match(nov2, candidates: [...run, ...copy]);
      expect(result, isA<NoMatch>());
      expect((result as NoMatch).reason, contains('Two runs'));
    });

    test('refuses when the lines run out before the text does', () {
      final result = match(nov2, candidates: _window(668).take(6).toList());
      expect(result, isA<NoMatch>());
    });
  });

  group('ShabadOsDatabase.ensure', () {
    late Directory dir;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('shabad_os_test');
      addTearDown(() => dir.deleteSync(recursive: true));
    });

    test('downloads a missing file, checks it, and moves it into place',
        () async {
      var downloads = 0;
      final file = File('${dir.path}/deep/master.sqlite');
      final database = ShabadOsDatabase(
        file,
        download: (target) async {
          downloads++;
          target.writeAsStringSync('pretend database');
        },
        checksum: (_) async => kShabadOsDatabaseSha256,
      );
      await database.ensure();
      await database.ensure();

      expect(downloads, 1);
      expect(file.readAsStringSync(), 'pretend database');
      expect(File('${file.path}.part').existsSync(), isFalse);
    });

    test('throws and keeps nothing when the checksum is wrong', () async {
      final file = File('${dir.path}/master.sqlite');
      final database = ShabadOsDatabase(
        file,
        download: (target) async => target.writeAsStringSync('changed file'),
        checksum: (_) async => 'f' * 64,
      );
      await expectLater(database.ensure(), throwsStateError);
      expect(file.existsSync(), isFalse);
      expect(File('${file.path}.part').existsSync(), isFalse);
    });

    test('does not download a file of the pinned size', () async {
      final file = File('${dir.path}/master.sqlite');
      final handle = file.openSync(mode: FileMode.write)
        ..truncateSync(kShabadOsDatabaseBytes);
      handle.closeSync();
      final database = ShabadOsDatabase(
        file,
        download: (_) async => fail('It must not download.'),
        checksum: (_) async => fail('It must not check.'),
      );
      await database.ensure();
    });

    test('pins a release of the database that has a file size and a hash', () {
      expect(kShabadOsDatabaseUrl, contains(kShabadOsVersion));
      expect(kShabadOsDatabaseSha256, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(kShabadOsDatabaseBytes, greaterThan(100 * 1024 * 1024));
    });
  });

  group('ShabadOsLines on a database', () {
    late Directory dir;
    late ShabadOsLines lines;

    setUpAll(() {
      if (!hasSqlite) return;
      dir = Directory.systemTemp.createTempSync('shabad_os_db_test');
      final file = buildShabadOsDatabase(dir);
      lines = ShabadOsLines(
        ShabadOsDatabase(
          file,
          expectedBytes: file.lengthSync(),
          download: (_) async => fail('It must not download.'),
        ),
      );
    });
    tearDownAll(() {
      if (hasSqlite) dir.deleteSync(recursive: true);
    });

    test('gives the shabad of 2 November line by line', () async {
      final result = await lines.linesFor(_sgpc('2026_11_02'));

      expect(result.shabad['matched'], isTrue);
      expect(result.shabad['source'], 'Shabad OS');
      expect(result.shabad['version'], kShabadOsVersion);
      expect(result.shabad['matcher'], kMatcherVersion);
      expect(result.shabad['ids'], ['R5B']);
      expect(result.shabad['ang'], 668);
      expect(result.shabad['angEnd'], 668);
      expect(result.shabad['sections'], [
        {'roman': 'Raag Dhanaasree'},
      ]);
      expect(result.shabad['writers'], [
        {'gurmukhi': 'ਗੁਰੂ ਰਾਮਦਾਸ', 'roman': 'Guru Ramdas'},
      ]);
      expect(result.shabad['credits'], kCredits);
      expect([for (final l in result.lines) l['id']], _nov2Ids);
    }, skip: hasSqlite ? false : 'sqlite3 is not installed');

    test('writes the pauses apart from the Gurmukhi', () async {
      final result = await lines.linesFor(_sgpc('2026_11_02'));
      final first = result.lines.first;

      expect(
        first['gurmukhi'],
        'ਹਰਿ ਹਰਿ ਬੂੰਦ ਭਏ ਹਰਿ ਸੁਆਮੀ ਹਮ ਚਾਤ੍ਰਿਕ ਬਿਲਲ ਬਿਲਲਾਤੀ ॥',
      );
      expect(first['ang'], 668);
      expect(first['vishraam'], [
        {'after': 5, 'weight': 'heavy'},
      ]);
      // No line holds a pause sign any more.
      for (final line in result.lines) {
        expect(line['gurmukhi'], isNot(matches(RegExp(r'\S[;,.](\s|$)'))));
      }
    }, skip: hasSqlite ? false : 'sqlite3 is not installed');

    test(
        'gives the English of Dr. Sant Singh Khalsa and the Punjabi of '
        'Prof. Sahib Singh, and not the other meanings', () async {
      final result = await lines.linesFor(_sgpc('2026_11_02'));
      final first = result.lines.first;

      expect(
        first['english'],
        'The Lord, Har, Har, is the rain-drop; I am the song-bird, crying, '
        'crying out for it.',
      );
      expect(first['punjabi'], startsWith('ਹੇ ਹਰੀ! ਹੇ ਸੁਆਮੀ!'));
      expect(first.containsKey('transliteration'), isFalse);
      // SBMS also has an English and a Punjabi row for this line.
      expect(first['english'], isNot(startsWith('God, God')));
    }, skip: hasSqlite ? false : 'sqlite3 is not installed');

    test('gives a day that matches nothing a reason and no lines', () async {
      final day = _sgpc('2026_11_02');
      day['ghukamnama'] = 'ਵਾਹਿਗੁਰੂ ਜੀ ਕਾ ਖਾਲਸਾ ਵਾਹਿਗੁਰੂ ਜੀ ਕੀ ਫਤਹਿ ॥ ' * 5;
      final result = await lines.linesFor(day);

      expect(result.shabad['matched'], isFalse);
      expect(result.shabad['reason'], isA<String>());
      expect(result.shabad['source'], 'Shabad OS');
      expect(result.lines, isEmpty);
    }, skip: hasSqlite ? false : 'sqlite3 is not installed');

    test('gives a day with no usable Ang a reason and no lines', () async {
      for (final ang in [null, '', 'abc', '0', '1431']) {
        final day = _sgpc('2026_11_02')..['ang'] = ang;
        final result = await lines.linesFor(day);
        expect(result.shabad['matched'], isFalse, reason: '$ang');
        expect(result.lines, isEmpty);
      }
    }, skip: hasSqlite ? false : 'sqlite3 is not installed');

    test('throws, and does not call a day unmatched, when sqlite3 is missing',
        () async {
      final broken = ShabadOsLines(
        ShabadOsDatabase(
          File('${dir.path}/master.sqlite'),
          sqlite: 'sqlite3_that_does_not_exist',
          expectedBytes: File('${dir.path}/master.sqlite').lengthSync(),
        ),
      );
      await expectLater(
        broken.linesFor(_sgpc('2026_11_02')),
        throwsA(isA<ProcessException>()),
      );
    }, skip: hasSqlite ? false : 'sqlite3 is not installed');
  });
}

/// The verses of [text] as SGPC prints them, split at each `॥` that ends a
/// verse, for building a damaged text.
List<String> splitHukamnamaLinesForTest(String text) => [
      for (final m in RegExp(r'[^॥]*॥(?:\s*[੦-੯]+\s*॥)*').allMatches(text))
        m.group(0)!.trim(),
    ];
