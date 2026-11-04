// Finds a day's Hukamnama in the Shabad OS database, and reads it line by line.
//
// Shabad OS (shabados.com) is an open database of Gurbani. The mirror job
// (tool/hukamnama_mirror.dart) uses this file to add per-line data to each
// day: the Gurmukhi, the pause marks (vishraam), an English and a Punjabi
// meaning, and facts about the shabad.
//
// The data comes from the database release `@shabados/database` 5.0.0-next.0
// (one SQLite file, `master.sqlite`). Its code is MIT licensed, and its README
// puts the Gurbani texts in the public domain
// (Creative Commons Public Domain Mark 1.0) on the condition that the words
// are never altered. So the Gurmukhi that this file writes is copied as the
// database has it. Only the pause marks are taken out of the text and written
// beside it. The credits are in tool/hukamnama_data_README.md.
//
// How a day is matched:
// 1. SGPC gives the Ang (page) where the shabad starts and the Gurmukhi text.
// 2. The database gives every line on that Ang and the pages after it, in
//    the order of Sri Guru Granth Sahib Ji.
// 3. A run of whole database lines is a match when its text is, letter for
//    letter, the text that SGPC gave. Spaces, pause marks, verse numbers and
//    the `॥` sign do not count, because the two sources write them
//    differently. A few letters of difference are allowed (see
//    [kMinSimilarity]), because the two sources are typed apart.
// 4. The run must start on SGPC's Ang, and no other run may match as well.
//    If any of this fails, the day is published with no lines. The mirror
//    never publishes lines that it is not sure about.
//
// This file imports only `dart:` libraries, as the mirror does, so CI runs it
// with plain `dart` and no `pub get`. The queries run through the `sqlite3`
// command line tool, which is on GitHub's Ubuntu runners.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// The version of the database release that the lines come from.
const kShabadOsVersion = '5.0.0-next.0';

/// The release file. It is the same file as `dist/master.sqlite` in the npm
/// package `@shabados/database@5.0.0-next.0`.
const kShabadOsDatabaseUrl =
    'https://github.com/shabados/database/releases/download/v5.0.0-next.0/master.sqlite';

/// SHA-256 of [kShabadOsDatabaseUrl], so a changed or damaged file is never
/// used.
const kShabadOsDatabaseSha256 =
    '517890c7e7c2f3dcef7f21b51d074a581b8eded4ebe14c504b84ea075ff16aeb';

/// The size of [kShabadOsDatabaseUrl] in bytes.
const kShabadOsDatabaseBytes = 151965696;

/// Changes whenever the matching rules or the shape of the lines change, so
/// the mirror looks at every day again once.
const kMatcherVersion = 1;

/// Shabad OS asset id of the Gurmukhi text that all lines come from:
/// "Shabadaarth", SGPC, Sri Amritsar, 2009 to 2012. It also carries the pause
/// marks, which Shabad OS took from the Damdami Taksaal vishraam book (asset
/// `JSDS`).
const kGurmukhiAsset = 'SSA2';

/// Shabad OS asset id of the English meaning: Dr. Sant Singh Khalsa,
/// "Siri Guru Granth Sahib Ji". It is the English that SGPC prints as the
/// meaning of the Hukamnama.
const kEnglishAsset = 'DSSK';

/// Shabad OS asset id of the Punjabi meaning: Prof. Sahib Singh,
/// "Sri Guru Granth Darpan". It is the Punjabi that SGPC prints as the meaning
/// of the Hukamnama.
const kPunjabiAsset = 'PSST';

/// Who made each kind of data, for the credit under the lines in the app. The
/// full citations are in tool/hukamnama_data_README.md.
const kCredits = {
  'gurmukhi': 'Shabadaarth, SGPC, Sri Amritsar',
  'vishraam': 'Jaswant S. Dauder, Sri Damdami Taksaal',
  'english': 'Dr. Sant Singh Khalsa',
  'punjabi': 'Prof. Sahib Singh, Sri Guru Granth Darpan',
};

/// How much of the text must agree for a match: 98.5 percent of the letters.
/// The text of a shabad is 300 to 3,000 letters, so this allows 5 to 45 letters
/// of difference, and no other shabad is anywhere near it.
const kMinSimilarity = 0.985;

/// A second run counts as a rival when it scores within this much of the best.
const kRivalMargin = 0.05;

/// The most pages after the first one that a match may run over.
const kMaxExtraPages = 15;

/// The shortest SGPC text that is matched, in letters. A shorter text could
/// match many places.
const kMinLetters = 20;

// ---------------------------------------------------------------------------
// Letters
// ---------------------------------------------------------------------------

/// The letters of [text] that count for a match: Gurmukhi letters and vowel
/// signs, with nothing else.
///
/// Dropped, because the two sources differ in them, or because they are not
/// words:
/// - spaces, pause marks (`;`, `,` and `.`), the `॥` and `।` signs, and all
///   digits (verse numbers);
/// - the nukta (`਼`) and the zero width joiners, which one source has and
///   the other leaves out;
/// - variation selectors.
/// Changed: the single code points for letters with a nukta (`ਸ਼`) are split
/// to a letter and a nukta first, so that both spellings come out the same,
/// and the adak bindi `ਁ` and bindi `ਂ` count as the tippi `ੰ`.
String lettersOf(String text) {
  final out = StringBuffer();
  for (final rune in text.runes) {
    final split = _nuktaLetters[rune];
    if (split != null) {
      out.writeCharCode(split);
      continue;
    }
    if (rune == 0x0a01 || rune == 0x0a02) {
      out.writeCharCode(0x0a70);
      continue;
    }
    final isLetter = (rune >= 0x0a03 && rune <= 0x0a4d && rune != 0x0a3c) ||
        rune == 0x0a51 ||
        (rune >= 0x0a70 && rune <= 0x0a75);
    if (isLetter) out.writeCharCode(rune);
  }
  return out.toString();
}

/// The Gurmukhi letters that Unicode also gives as a letter plus a nukta, and
/// the letter without the nukta.
const _nuktaLetters = <int, int>{
  0x0a33: 0x0a32, // ਲ਼ -> ਲ
  0x0a36: 0x0a38, // ਸ਼ -> ਸ
  0x0a59: 0x0a16, // ਖ਼ -> ਖ
  0x0a5a: 0x0a17, // ਗ਼ -> ਗ
  0x0a5b: 0x0a1c, // ਜ਼ -> ਜ
  0x0a5e: 0x0a2b, // ਫ਼ -> ਫ
};

/// How alike [a] and [b] are, from 0 to 1: one minus the edit distance over
/// the length of the longer text. 1 is identical.
double similarity(String a, String b) {
  if (a.isEmpty && b.isEmpty) return 1;
  final longest = a.length > b.length ? a.length : b.length;
  return 1 - _editDistance(a, b) / longest;
}

int _editDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  // Two rows of the usual table are enough.
  var previous = Uint32List(b.length + 1);
  var current = Uint32List(b.length + 1);
  for (var j = 0; j <= b.length; j++) {
    previous[j] = j;
  }
  for (var i = 1; i <= a.length; i++) {
    current[0] = i;
    final ca = a.codeUnitAt(i - 1);
    for (var j = 1; j <= b.length; j++) {
      final cost = ca == b.codeUnitAt(j - 1) ? 0 : 1;
      var best = previous[j - 1] + cost;
      final deletion = previous[j] + 1;
      if (deletion < best) best = deletion;
      final insertion = current[j - 1] + 1;
      if (insertion < best) best = insertion;
      current[j] = best;
    }
    final swap = previous;
    previous = current;
    current = swap;
  }
  return previous[b.length];
}

// ---------------------------------------------------------------------------
// Pause marks
// ---------------------------------------------------------------------------

/// How long a pause is. Shabad OS writes them in the text: `;`, `,` and `.`.
enum VishraamWeight {
  /// `;`, the long pause.
  heavy(';'),

  /// `,`, the middle pause.
  medium(','),

  /// `.`, the short pause.
  light('.');

  const VishraamWeight(this.mark);

  /// The sign in the Shabad OS text.
  final String mark;
}

/// One pause: after the word at [after] (counting from 0).
class Vishraam {
  const Vishraam(this.after, this.weight);

  /// The index of the word that the pause follows, in the words of the line
  /// that [splitVishraam] gives.
  final int after;

  final VishraamWeight weight;

  Map<String, Object?> toJson() => {'after': after, 'weight': weight.name};

  @override
  bool operator ==(Object other) =>
      other is Vishraam && other.after == after && other.weight == weight;

  @override
  int get hashCode => Object.hash(after, weight);

  @override
  String toString() => 'Vishraam($after, ${weight.name})';
}

/// A line with its pause marks taken out.
class MarkedLine {
  const MarkedLine(this.text, this.vishraam);

  /// The line as Shabad OS has it, without the pause marks. White space is one
  /// space. No word is changed.
  final String text;

  final List<Vishraam> vishraam;
}

/// Takes the pause marks out of [raw], a line of the Shabad OS Gurmukhi text.
///
/// In that text a mark is the last sign of the word before the pause, for
/// example `ਸੁਆਮੀ;`. A sign that stands alone, or that is not at the end of a
/// word, is left in the text. The words are the white space separated parts of
/// the result.
MarkedLine splitVishraam(String raw) {
  final words = raw.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  final kept = <String>[];
  final marks = <Vishraam>[];
  for (final word in words) {
    final last = word.substring(word.length - 1);
    final weight = VishraamWeight.values.where((w) => w.mark == last);
    if (word.length > 1 && weight.isNotEmpty) {
      marks.add(Vishraam(kept.length, weight.first));
      kept.add(word.substring(0, word.length - 1));
    } else {
      kept.add(word);
    }
  }
  return MarkedLine(kept.join(' '), List.unmodifiable(marks));
}

// ---------------------------------------------------------------------------
// Matching
// ---------------------------------------------------------------------------

/// One line of Sri Guru Granth Sahib Ji, as the database has it.
class ShabadLine {
  const ShabadLine({
    required this.id,
    required this.groupId,
    required this.page,
    required this.text,
  });

  /// The Shabad OS line id, for example `015H`.
  final String id;

  /// The Shabad OS line group (shabad) id, for example `R5B`.
  final String groupId;

  /// The Ang.
  final int page;

  /// The Gurmukhi with the pause marks in it.
  final String text;
}

/// How [matchShabad] came out.
sealed class ShabadMatch {
  const ShabadMatch();
}

/// The lines `candidates[start]` up to, not including, `candidates[end]`.
final class Matched extends ShabadMatch {
  const Matched(this.start, this.end, this.similarity);

  final int start;
  final int end;

  /// From [kMinSimilarity] to 1.
  final double similarity;
}

/// No match, or none that is sure. [reason] is for the people who read the log
/// and the day file.
final class NoMatch extends ShabadMatch {
  const NoMatch(this.reason);

  final String reason;
}

/// Finds the run of [candidates] that is [sgpcText], which starts on [ang].
///
/// [candidates] are in the order of Sri Guru Granth Sahib Ji. See the top of
/// this file for the rules.
ShabadMatch matchShabad({
  required List<ShabadLine> candidates,
  required String sgpcText,
  required int ang,
}) {
  final wanted = lettersOf(sgpcText);
  if (wanted.length < kMinLetters) {
    return NoMatch('The SGPC text has only ${wanted.length} letters.');
  }
  final letters = [for (final line in candidates) lettersOf(line.text)];

  // Every run that starts on the Ang and begins like the SGPC text is tried.
  final scored = <Matched>[];
  var startedHere = 0;
  for (var start = 0; start < candidates.length; start++) {
    if (candidates[start].page != ang || letters[start].isEmpty) continue;
    final head = letters[start];
    final take = head.length < wanted.length ? head.length : wanted.length;
    if (similarity(head.substring(0, take), wanted.substring(0, take)) < 0.7) {
      continue;
    }
    startedHere++;

    // Add lines until the run is as long as the SGPC text, and score each
    // length that is close to it.
    var length = 0;
    Matched? best;
    for (var end = start; end < candidates.length; end++) {
      length += letters[end].length;
      if (length < wanted.length * 0.95) continue;
      final run = letters.sublist(start, end + 1).join();
      final score = similarity(run, wanted);
      if (best == null || score > best.similarity) {
        best = Matched(start, end + 1, score);
      }
      if (length > wanted.length * 1.05) break;
    }
    if (best != null) scored.add(best);
  }

  if (scored.isEmpty) {
    return NoMatch(
      startedHere == 0
          ? 'No line on Ang $ang starts like the SGPC text.'
          : 'The lines after Ang $ang are shorter than the SGPC text.',
    );
  }
  scored.sort((a, b) => b.similarity.compareTo(a.similarity));
  final best = scored.first;
  if (best.similarity < kMinSimilarity) {
    return NoMatch(
      'The best run matches ${(best.similarity * 100).toStringAsFixed(1)} '
      'percent of the letters, and ${(kMinSimilarity * 100).toStringAsFixed(1)} '
      'is needed.',
    );
  }
  for (final other in scored.skip(1)) {
    if (best.similarity - other.similarity < kRivalMargin) {
      return const NoMatch('Two runs of lines match the SGPC text.');
    }
  }

  // Every line of the run must be in the SGPC text. This catches a run that
  // has one more line than SGPC has: the whole text can still be 98.5 percent
  // alike when that line is short.
  for (var i = best.start; i < best.end; i++) {
    final line = letters[i];
    if (line.length < 4) continue;
    if (_distanceInside(line, wanted) > line.length * kMaxLineMisses) {
      return NoMatch('Line ${candidates[i].id} is not in the SGPC text.');
    }
  }
  return best;
}

/// How much of one line may be missing from the SGPC text: 10 percent of its
/// letters.
const kMaxLineMisses = 0.1;

/// The fewest edits that turn [pattern] into some part of [text]. The part
/// may start and end anywhere in [text].
int _distanceInside(String pattern, String text) {
  var previous = Uint32List(text.length + 1); // all 0: any start is free
  var current = Uint32List(text.length + 1);
  for (var i = 1; i <= pattern.length; i++) {
    current[0] = i;
    final cp = pattern.codeUnitAt(i - 1);
    for (var j = 1; j <= text.length; j++) {
      final cost = cp == text.codeUnitAt(j - 1) ? 0 : 1;
      var best = previous[j - 1] + cost;
      final deletion = previous[j] + 1;
      if (deletion < best) best = deletion;
      final insertion = current[j - 1] + 1;
      if (insertion < best) best = insertion;
      current[j] = best;
    }
    final swap = previous;
    previous = current;
    current = swap;
  }
  var least = previous[0];
  for (var j = 1; j <= text.length; j++) {
    if (previous[j] < least) least = previous[j];
  }
  return least;
}

// ---------------------------------------------------------------------------
// The answer that the mirror writes
// ---------------------------------------------------------------------------

/// What the mirror adds to a day: `shabad` always, and `lines` only when the
/// day matched.
class LinesResult {
  const LinesResult(this.shabad, [this.lines = const []]);

  /// The `shabad` object. `matched` says whether `lines` is filled.
  final Map<String, Object?> shabad;

  /// The `lines` array. Empty when `shabad['matched']` is not true.
  final List<Map<String, Object?>> lines;
}

/// Where the mirror gets the lines of a day.
abstract interface class LinesProvider {
  /// The part of the `shabad` object that says where the lines came from:
  /// `source`, `version` and `matcher`. A day that already holds this stamp
  /// and the same SGPC text is not looked up again.
  Map<String, Object?> get stamp;

  /// The lines for [hukamnama], the `hukamnama` object of SGPC's answer.
  /// Never throws for a day that does not match. It throws when the database
  /// cannot be read.
  Future<LinesResult> linesFor(Map<String, dynamic> hukamnama);
}

/// Reads the database by the `sqlite3` command line tool, and fetches the
/// database file first when it is not there.
class ShabadOsDatabase {
  /// [expectedBytes] and [expectedSha256] are the pinned release. Only a test
  /// changes them. [download] and [checksum] are for tests too.
  ShabadOsDatabase(
    this.file, {
    Future<void> Function(File target)? download,
    Future<String> Function(File file)? checksum,
    this.sqlite = 'sqlite3',
    this.expectedBytes = kShabadOsDatabaseBytes,
    this.expectedSha256 = kShabadOsDatabaseSha256,
  })  : _download = download ?? downloadShabadOsDatabase,
        _checksum = checksum ?? sha256OfFile;

  /// Where the database file is, or goes.
  final File file;

  /// The name of the `sqlite3` tool.
  final String sqlite;

  /// The size of the pinned file.
  final int expectedBytes;

  /// The SHA-256 of the pinned file, as lower case hex.
  final String expectedSha256;

  final Future<void> Function(File target) _download;
  final Future<String> Function(File file) _checksum;
  Future<void>? _ready;

  /// Makes sure [file] is the pinned database. It downloads it when the file is
  /// missing or is not the right size, and checks its SHA-256 after the
  /// download. A file of the right size is trusted, because only this method
  /// writes it, and only after the check.
  Future<void> ensure() => _ready ??= _ensure();

  Future<void> _ensure() async {
    if (file.existsSync() && file.lengthSync() == expectedBytes) return;
    file.parent.createSync(recursive: true);
    final part = File('${file.path}.part');
    if (part.existsSync()) part.deleteSync();
    await _download(part);
    final sum = await _checksum(part);
    if (sum != expectedSha256) {
      part.deleteSync();
      throw StateError(
        'The Shabad OS database has SHA-256 $sum, not $expectedSha256.',
      );
    }
    part.renameSync(file.path);
  }

  /// Runs [sql] and returns its rows. A column is a string, a number or null.
  Future<List<Map<String, Object?>>> query(String sql) async {
    await ensure();
    final result = await Process.run(
      sqlite,
      ['-readonly', '-json', file.path, sql],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    ).timeout(const Duration(minutes: 2));
    if (result.exitCode != 0) {
      throw StateError('sqlite3 failed (${result.exitCode}): ${result.stderr}');
    }
    final out = (result.stdout as String).trim();
    if (out.isEmpty) return const [];
    final rows = jsonDecode(out) as List<dynamic>;
    return [for (final row in rows) (row as Map).cast<String, Object?>()];
  }
}

/// Downloads [kShabadOsDatabaseUrl] to [target]. Redirects are followed.
Future<void> downloadShabadOsDatabase(File target) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  try {
    final request = await client
        .getUrl(Uri.parse(kShabadOsDatabaseUrl))
        .timeout(const Duration(seconds: 30));
    final response = await request.close().timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      throw HttpException(
        'HTTP ${response.statusCode} for the Shabad OS database.',
        uri: Uri.parse(kShabadOsDatabaseUrl),
      );
    }
    final sink = target.openWrite();
    try {
      await response.timeout(const Duration(minutes: 3)).pipe(sink);
    } finally {
      await sink.close();
    }
  } finally {
    client.close(force: true);
  }
}

/// The SHA-256 of [file] as lower case hex, by the system tool: `sha256sum` on
/// Linux and `shasum -a 256` on macOS.
Future<String> sha256OfFile(File file) async {
  for (final command in [
    ['sha256sum', file.path],
    ['shasum', '-a', '256', file.path],
  ]) {
    try {
      final result = await Process.run(command.first, command.sublist(1));
      if (result.exitCode == 0) {
        return (result.stdout as String).trim().split(RegExp(r'\s+')).first;
      }
    } on ProcessException {
      // Try the next tool.
    }
  }
  throw StateError('Neither sha256sum nor shasum can run.');
}

/// The real [LinesProvider]: the Shabad OS database.
class ShabadOsLines implements LinesProvider {
  ShabadOsLines(this.database);

  final ShabadOsDatabase database;

  @override
  Map<String, Object?> get stamp => const {
        'source': 'Shabad OS',
        'version': kShabadOsVersion,
        'matcher': kMatcherVersion,
      };

  @override
  Future<LinesResult> linesFor(Map<String, dynamic> hukamnama) async {
    LinesResult none(String reason) => LinesResult({
          ...stamp,
          'matched': false,
          'reason': reason,
        });

    final ang = int.tryParse('${hukamnama['ang']}'.trim());
    if (ang == null || ang < 1 || ang > 1430) {
      return none('SGPC gave no Ang from 1 to 1430.');
    }
    final text = hukamnama['ghukamnama'];
    if (text is! String) return none('SGPC gave no Gurmukhi text.');

    final candidates = await linesOnPages(ang, ang + kMaxExtraPages);
    final match = matchShabad(candidates: candidates, sgpcText: text, ang: ang);
    switch (match) {
      case NoMatch(:final reason):
        return none(reason);
      case Matched(:final start, :final end, :final similarity):
        return buildResult(candidates.sublist(start, end), similarity);
    }
  }

  /// The lines on the Angs [from] to [to], in the order of the Granth.
  Future<List<ShabadLine>> linesOnPages(int from, int to) async {
    final rows = await database.query('''
SELECT l.id AS id, l.line_group_id AS grp,
       CAST(json_extract(a.additional, '\$.page') AS INTEGER) AS page,
       a.data AS text
FROM asset_lines a
JOIN lines l ON l.id = a.line_id
JOIN line_groups g ON g.id = l.line_group_id
JOIN sections s ON s.id = g.section_id
WHERE a.asset_id = '$kGurmukhiAsset' AND a.type = 'primary'
  AND CAST(json_extract(a.additional, '\$.page') AS INTEGER)
      BETWEEN $from AND $to
ORDER BY page, s.source_order, g.section_order, l.line_group_order
''');
    return [
      for (final row in rows)
        ShabadLine(
          id: _id(row['id']),
          groupId: _id(row['grp']),
          page: row['page'] as int,
          text: row['text'] as String,
        ),
    ];
  }

  /// Adds the meanings and the facts to the matched [run].
  Future<LinesResult> buildResult(List<ShabadLine> run, double score) async {
    final lineIds = [for (final line in run) _id(line.id)];
    final groupIds = {for (final line in run) _id(line.groupId)}.toList();

    final meanings = await database.query('''
SELECT a.line_id AS line, a.asset_id AS asset, a.data AS text
FROM asset_lines a
WHERE a.type = 'translation' AND a.asset_id IN ('$kEnglishAsset', '$kPunjabiAsset')
  AND a.line_id IN (${_quoted(lineIds)})
ORDER BY a.line_id, a.priority
''');
    final english = <String, String>{};
    final punjabi = <String, String>{};
    for (final row in meanings) {
      final text = _clean(row['text']);
      if (text == null) continue;
      final into = row['asset'] == kEnglishAsset ? english : punjabi;
      into.putIfAbsent(row['line'] as String, () => text);
    }

    final groups = await database.query('''
SELECT g.id AS grp, au.name AS author, s.name AS section
FROM line_groups g
LEFT JOIN authors au ON au.id = g.author_id
LEFT JOIN sections s ON s.id = g.section_id
WHERE g.id IN (${_quoted(groupIds)})
''');
    final byGroup = {for (final g in groups) g['grp'] as String: g};
    final writers = <Map<String, String>>[];
    final sections = <Map<String, String>>[];
    for (final id in groupIds) {
      final row = byGroup[id];
      if (row == null) continue;
      final writer = _names(row['author']);
      if (writer != null && !writers.any((w) => _sameMap(w, writer))) {
        writers.add(writer);
      }
      final section = _names(row['section']);
      if (section != null && !sections.any((w) => _sameMap(w, section))) {
        sections.add(section);
      }
    }

    final lines = <Map<String, Object?>>[];
    for (final line in run) {
      final marked = splitVishraam(line.text);
      lines.add({
        'id': line.id,
        'ang': line.page,
        'gurmukhi': marked.text,
        if (marked.vishraam.isNotEmpty)
          'vishraam': [for (final v in marked.vishraam) v.toJson()],
        if (english[line.id] != null) 'english': english[line.id],
        if (punjabi[line.id] != null) 'punjabi': punjabi[line.id],
      });
    }

    return LinesResult({
      ...stamp,
      'matched': true,
      'similarity': double.parse(score.toStringAsFixed(4)),
      'ids': groupIds,
      'ang': run.first.page,
      'angEnd': run.last.page,
      'sections': sections,
      'writers': writers,
      'assets': {
        'gurmukhi': kGurmukhiAsset,
        'english': kEnglishAsset,
        'punjabi': kPunjabiAsset,
      },
      'credits': kCredits,
    }, lines);
  }
}

/// A Shabad OS id: letters and digits only, so that it is safe in a query.
String _id(Object? value) {
  final id = '$value';
  if (!RegExp(r'^[A-Za-z0-9]{1,16}$').hasMatch(id)) {
    throw FormatException('Not a Shabad OS id: $id');
  }
  return id;
}

String _quoted(List<String> ids) =>
    [for (final id in ids) "'${_id(id)}'"].join(',');

/// [value] with its white space made single, or null when it is blank.
String? _clean(Object? value) {
  if (value is! String) return null;
  final text = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  return text.isEmpty ? null : text;
}

/// Shabad OS names are a JSON text like `{"Guru":"ਗੁਰੂ ਰਾਮਦਾਸ","Latn":"Guru
/// Ramdas"}`. Gives `{gurmukhi: ..., roman: ...}` with the parts that exist.
Map<String, String>? _names(Object? value) {
  if (value is! String) return null;
  try {
    final json = jsonDecode(value);
    if (json is! Map) return null;
    final names = <String, String>{
      if (_clean(json['Guru']) case final name?) 'gurmukhi': name,
      if (_clean(json['Latn']) case final name?) 'roman': name,
    };
    return names.isEmpty ? null : names;
  } on FormatException {
    return null;
  }
}

bool _sameMap(Map<String, String> a, Map<String, String> b) =>
    a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
