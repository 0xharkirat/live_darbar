// Writes assets/data/barah_maha.json: Barah Maha Maajh, Mahala 5 (Guru Arjan
// Dev Ji, Ang 133 to 136), line by line, from the Shabad OS database.
//
// Why: on each Sangrand, the 1st day of a Sikh month, the sangat reads the
// pauri of Barah Maha for the new month. The app shows it as the Sangrand
// Hukamnama (Hark, 7 November 2026). The text never changes, so the app
// ships it, and it needs no network.
//
// The file holds the title lines and the 14 pauris: pauri 1 opens the bani,
// pauris 2 to 13 are the months from Chet to Phagun, and pauri 14 closes it.
// Each line has the shape of a line in the Hukamnama mirror
// (tool/hukamnama_data_README.md): the Gurmukhi with the pause marks taken out
// and written beside it, Dr. Sant Singh Khalsa's English, and Prof. Sahib
// Singh's Punjabi. The licence notes are at the top of tool/shabad_os.dart.
//
// Run it once, and again only when the pinned database release changes:
//
//   dart tool/barah_maha.dart --shabados-db /path/to/master.sqlite
//
// The tool downloads and checks the pinned database when the file is not
// there. `--out FILE` writes elsewhere. It imports only `dart:` libraries and
// tool/shabad_os.dart, so it runs with plain `dart`.

import 'dart:convert';
import 'dart:io';

import 'shabad_os.dart';

/// The Shabad OS bani id of Barah Maha Maajh.
const kBarahMahaBani = 'BRMH';

/// Barah Maha Maajh has 14 pauris: the opening, 12 months, and the closing.
const kBarahMahaPauris = 14;

const _gurmukhiDigits = '੦੧੨੩੪੫੬੭੮੯';

int _number(String gurmukhi) => int.parse(
    [for (final c in gurmukhi.split('')) _gurmukhiDigits.indexOf(c)].join());

/// Cuts [lines], Gurmukhi as the database writes it, into pauris. A pauri
/// ends at the line that carries its number: `॥੧॥` for the 1st. The last
/// line also carries the shabad's number, `॥੧੪॥੧॥`, and the first number is
/// the pauri's.
///
/// Throws [FormatException] when a pauri is missing or lines follow the last
/// number: a pauri that is cut wrong would show the wrong month.
List<List<String>> splitPauris(List<String> lines) {
  final number = RegExp(r'॥\s*([੦-੯]+)\s*॥');
  final pauris = <List<String>>[];
  var current = <String>[];
  for (final line in lines) {
    current.add(line);
    final match = number.firstMatch(line);
    if (match == null) continue;
    final want = pauris.length + 1;
    final found = _number(match.group(1)!);
    if (found != want) {
      throw FormatException(
          'Pauri $want is missing: the next number is $found.');
    }
    pauris.add(current);
    current = [];
  }
  if (current.isNotEmpty) {
    throw FormatException('${current.length} lines follow the last pauri.');
  }
  return pauris;
}

Future<void> main(List<String> args) async {
  String? databasePath;
  var out = 'assets/data/barah_maha.json';
  for (var i = 0; i < args.length; i++) {
    final hasValue = i + 1 < args.length;
    if (args[i] == '--shabados-db' && hasValue) {
      databasePath = args[++i];
    } else if (args[i] == '--out' && hasValue) {
      out = args[++i];
    } else {
      stderr.writeln('usage: dart tool/barah_maha.dart '
          '--shabados-db FILE [--out FILE]');
      exitCode = 64;
      return;
    }
  }
  if (databasePath == null) {
    stderr.writeln('--shabados-db is required.');
    exitCode = 64;
    return;
  }
  final database = ShabadOsDatabase(File(databasePath));

  final rows = await database.query('''
SELECT b.line_id AS id,
       CAST(json_extract(a.additional, '\$.page') AS INTEGER) AS page,
       a.data AS text
FROM bani_lines b
JOIN asset_lines a ON a.line_id = b.line_id
WHERE b.bani_id = '$kBarahMahaBani'
  AND a.asset_id = '$kGurmukhiAsset' AND a.type = 'primary'
ORDER BY b.section_order, b.line_order
''');
  final meanings = await database.query('''
SELECT a.line_id AS line, a.asset_id AS asset, a.data AS text
FROM asset_lines a
JOIN bani_lines b ON b.line_id = a.line_id AND b.bani_id = '$kBarahMahaBani'
WHERE a.type = 'translation' AND a.asset_id IN ('$kEnglishAsset', '$kPunjabiAsset')
ORDER BY a.line_id, a.priority
''');
  final english = <String, String>{};
  final punjabi = <String, String>{};
  for (final row in meanings) {
    final text = (row['text'] as String).replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) continue;
    final into = row['asset'] == kEnglishAsset ? english : punjabi;
    into.putIfAbsent(row['line'] as String, () => text);
  }

  Map<String, Object?> lineJson(Map<String, Object?> row) {
    final id = row['id'] as String;
    final marked = splitVishraam(row['text'] as String);
    return {
      'id': id,
      'ang': row['page'],
      'gurmukhi': marked.text,
      if (marked.vishraam.isNotEmpty)
        'vishraam': [for (final v in marked.vishraam) v.toJson()],
      if (english[id] != null) 'english': english[id],
      if (punjabi[id] != null) 'punjabi': punjabi[id],
    };
  }

  // The title lines open the bani: the raag line and ੴ.
  var start = 0;
  while (start < rows.length && isTitleLine(rows[start]['text'] as String)) {
    start++;
  }
  final verses = rows.sublist(start);
  final pauris = splitPauris([for (final r in verses) r['text'] as String]);
  if (start == 0 || pauris.length != kBarahMahaPauris) {
    throw StateError('Barah Maha read as $start title lines and '
        '${pauris.length} pauris, not $kBarahMahaPauris.');
  }

  var next = 0;
  final pauriJson = [
    for (final pauri in pauris)
      [for (var i = 0; i < pauri.length; i++) lineJson(verses[next++])],
  ];
  final json = {
    'source': 'Shabad OS',
    'version': kShabadOsVersion,
    'bani': kBarahMahaBani,
    'ang': rows.first['page'],
    'angEnd': rows.last['page'],
    'credits': kCredits,
    'heading': [for (final row in rows.sublist(0, start)) lineJson(row)],
    'pauris': pauriJson,
  };
  File(out).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(json)}\n',
  );
  stdout.writeln('Wrote $out: $start title lines, ${pauris.length} pauris, '
      '${verses.length} lines.');
}
