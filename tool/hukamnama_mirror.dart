// Copies SGPC's Hukamnama answer for today and yesterday into a folder, so the
// web app can read it.
//
// Why this exists: SGPC's feed sends no CORS header, so a browser cannot read
// it. The native apps read SGPC directly and do not use this. A GitHub Actions
// job (.github/workflows/hukamnama-mirror.yml) runs this script and commits the
// files to the `hukamnama-data` branch. raw.githubusercontent.com sends
// `access-control-allow-origin: *`, so the web app reads them from there.
//
// Run it from anywhere:
//
//   dart tool/hukamnama_mirror.dart --out /path/to/folder
//
// It writes into `<out>/hukamnama/`:
// - `YYYY-MM-DD.json`: SGPC's answer for that day, byte for byte. The app
//   parses it with its own parser (`Hukamnama.fromSgpc`).
// - `latest.json`: a copy of the newest day on disk.
// The last 31 days stay and older files are deleted.
//
// Exit codes:
// - 0: every day is mirrored, or SGPC has not published it yet. Today is
//   unpublished from midnight until about 05:30 IST, and that is normal.
// - 1: SGPC gave an answer that cannot be used. Nothing bad is written.
// - 64: wrong command line.
//
// This file imports only `dart:` libraries, so CI runs it with plain `dart`
// and no `pub get`. The SGPC day rules are copied from
// lib/src/models/sgpc_day.dart for that reason, and a test keeps the two in
// step (test/tool/hukamnama_mirror_test.dart).

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// The undocumented endpoint behind SGPC's archive calendar. Same URL as
/// `kHukamnamaArchiveUrl` in the app.
const kSgpcArchiveUrl = 'https://hs.sgpc.net/hssearchhukmanamaTestCalender.php';

/// How many days stay in the folder, today included.
const kKeepDays = 31;

/// India Standard Time, which is when SGPC's day starts. Same value as
/// `kIndiaOffset` in the app.
const kIndiaOffset = Duration(hours: 5, minutes: 30);

/// The SGPC day containing [instant], as UTC midnight.
DateTime sgpcDayOf(DateTime instant) {
  final india = instant.toUtc().add(kIndiaOffset);
  return DateTime.utc(india.year, india.month, india.day);
}

/// The day before [day].
DateTime previousDay(DateTime day) =>
    DateTime.utc(day.year, day.month, day.day - 1);

/// `YYYY-MM-DD`.
String dayIso(DateTime day) {
  final d = day.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';
}

/// What SGPC sent for one request.
class SgpcReply {
  const SgpcReply(this.statusCode, this.body);

  final int statusCode;
  final List<int> body;
}

/// The verdict on one SGPC reply. See [checkSgpcReply].
sealed class SgpcVerdict {
  const SgpcVerdict();
}

/// A full Hukamnama for the day asked. Safe to write to the mirror.
final class Accepted extends SgpcVerdict {
  const Accepted();
}

/// SGPC answered correctly and has no Hukamnama for the day yet.
final class NotPublished extends SgpcVerdict {
  const NotPublished();
}

/// Not usable: an error, not JSON, the wrong day, or missing text.
final class Rejected extends SgpcVerdict {
  const Rejected(this.reason);

  final String reason;
}

/// Decides whether [reply] is a Hukamnama that the app can show for [day].
///
/// Accepted only when all of these hold. They are the checks that
/// `Hukamnama.fromSgpc` makes in the app, plus the day check that
/// `HukamnamaService` makes after it:
/// - the HTTP status is 200;
/// - the body is UTF-8 JSON and a JSON object;
/// - `supported` is `true`;
/// - `hukamnama` is an object;
/// - `hukamnama.date` is [day] (`YYYY-MM-DD`);
/// - `hukamnama.ghukamnama`, the Gurmukhi text, is a string with some text.
/// Every other field (`ang`, headings, meanings, footers) is optional in the
/// app, so it is copied as SGPC sent it and not checked.
///
/// `supported: false` is [NotPublished], the way the app reads it.
SgpcVerdict checkSgpcReply(SgpcReply reply, String day) {
  if (reply.statusCode != 200) {
    return Rejected('HTTP ${reply.statusCode}.');
  }

  final Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(reply.body));
  } on FormatException catch (e) {
    return Rejected('The body is not UTF-8 JSON (${e.message}).');
  }
  if (decoded is! Map<String, dynamic>) {
    return const Rejected('The body is not a JSON object.');
  }

  final supported = decoded['supported'];
  if (supported == false) return const NotPublished();
  if (supported != true) {
    return const Rejected('"supported" is missing or is not true or false.');
  }

  final hukamnama = decoded['hukamnama'];
  if (hukamnama is! Map<String, dynamic>) {
    return const Rejected('"hukamnama" is missing or is not an object.');
  }

  final date = hukamnama['date'];
  if (date is! String) return const Rejected('"hukamnama.date" is missing.');
  if (date.trim() != day) {
    return Rejected('Asked for $day but the answer is for ${date.trim()}.');
  }

  final text = hukamnama['ghukamnama'];
  if (text is! String || text.trim().isEmpty) {
    return const Rejected('"hukamnama.ghukamnama" is missing or empty.');
  }
  return const Accepted();
}

final _dayFile = RegExp(r'^(\d{4})-(\d{2})-(\d{2})\.json$');

/// The day a mirror file name stands for, or null for any other name
/// (`latest.json` included).
DateTime? dayOfFileName(String name) {
  final m = _dayFile.firstMatch(name);
  if (m == null) return null;
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  final day = DateTime.utc(y, mo, d);
  if (day.year != y || day.month != mo || day.day != d) return null;
  return day;
}

/// The names in [names] to delete: day files older than the [keepDays] days
/// that end at [today]. Other names are never listed.
List<String> namesToPrune(
  Iterable<String> names,
  DateTime today, {
  int keepDays = kKeepDays,
}) {
  final oldestKept = DateTime.utc(today.year, today.month, today.day)
      .subtract(Duration(days: keepDays - 1));
  return [
    for (final name in names)
      if (dayOfFileName(name) case final day? when day.isBefore(oldestKept))
        name,
  ];
}

/// What [mirror] did for one day.
enum DayOutcome { written, unchanged, notPublished, failed }

/// What [mirror] did in one run.
class MirrorReport {
  MirrorReport(this.outcomes, this.warnings, this.errors);

  /// Keyed by day, `YYYY-MM-DD`.
  final Map<String, DayOutcome> outcomes;

  /// Odd, but not a reason to fail the run.
  final List<String> warnings;

  /// One line for each day whose answer could not be used.
  final List<String> errors;

  /// 1 when SGPC sent an answer that cannot be used, else 0.
  int get exitCode => errors.isEmpty ? 0 : 1;
}

/// Mirrors SGPC's answer for today and yesterday into `<root>/hukamnama/`.
///
/// [fetch] asks SGPC for one day (`YYYY-MM-DD`). A request that throws, or an
/// answer that [checkSgpcReply] rejects, is tried up to [attempts] times in
/// all, with [pause] between tries. If it never improves, the day is
/// [DayOutcome.failed] and its file is left as it was: a good file is never
/// replaced by a bad answer.
Future<MirrorReport> mirror({
  required Directory root,
  required DateTime now,
  required Future<SgpcReply> Function(String day) fetch,
  int attempts = 3,
  Duration pause = const Duration(seconds: 5),
}) async {
  final today = sgpcDayOf(now);
  final dir = Directory('${root.path}/hukamnama')..createSync(recursive: true);
  final outcomes = <String, DayOutcome>{};
  final warnings = <String>[];
  final errors = <String>[];

  // Yesterday is asked for first, so that if today fails the folder is no
  // worse. Both are always asked for: one failure does not skip the other.
  for (final day in [previousDay(today), today]) {
    final iso = dayIso(day);
    SgpcVerdict verdict = const Rejected('Not asked.');
    SgpcReply? reply;
    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        reply = await fetch(iso);
        verdict = checkSgpcReply(reply, iso);
      } on Object catch (e) {
        reply = null;
        verdict = Rejected('The request failed ($e).');
      }
      if (verdict is Accepted || verdict is NotPublished) break;
      if (attempt < attempts) await Future<void>.delayed(pause);
    }

    switch (verdict) {
      case Accepted():
        final changed = _writeIfChanged(File('${dir.path}/$iso.json'), reply!);
        outcomes[iso] = changed ? DayOutcome.written : DayOutcome.unchanged;
      case NotPublished():
        outcomes[iso] = DayOutcome.notPublished;
        // Today is normally unpublished until about 05:30 IST. Yesterday
        // should exist, so say so, but a day SGPC skipped must not keep the
        // job red.
        if (day != today) {
          warnings.add('SGPC has no Hukamnama for $iso, the day before.');
        }
      case Rejected(:final reason):
        outcomes[iso] = DayOutcome.failed;
        errors.add('$iso: $reason');
    }
  }

  _refreshLatest(dir);
  for (final name in namesToPrune(_names(dir), today)) {
    File('${dir.path}/$name').deleteSync();
  }
  return MirrorReport(outcomes, warnings, errors);
}

List<String> _names(Directory dir) => [
      for (final entry in dir.listSync())
        if (entry is File) entry.uri.pathSegments.last,
    ];

/// Writes the body of [reply] unless the file already holds those bytes.
/// Returns whether the file changed. The write goes to a temporary file first,
/// so a run that stops half way cannot leave half a Hukamnama behind.
bool _writeIfChanged(File file, SgpcReply reply) {
  if (file.existsSync() && _sameBytes(file.readAsBytesSync(), reply.body)) {
    return false;
  }
  final temp = File('${file.path}.tmp')..writeAsBytesSync(reply.body);
  temp.renameSync(file.path);
  return true;
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Makes `latest.json` a copy of the newest day file on disk. Every day file
/// was checked before it was written, so the newest one is the newest
/// accepted day, even when this run could not reach SGPC for today.
void _refreshLatest(Directory dir) {
  String? newest;
  DateTime? newestDay;
  for (final name in _names(dir)) {
    final day = dayOfFileName(name);
    if (day != null && (newestDay == null || day.isAfter(newestDay))) {
      newest = name;
      newestDay = day;
    }
  }
  if (newest == null) return;

  final bytes = File('${dir.path}/$newest').readAsBytesSync();
  _writeIfChanged(File('${dir.path}/latest.json'), SgpcReply(200, bytes));
}

/// Asks SGPC for one day, the way `HukamnamaService` does: a form post with
/// `selected_date`, and the `X-Requested-With` header that SGPC requires.
/// Without that header SGPC answers 200 with an empty body.
Future<SgpcReply> fetchFromSgpc(String day) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final request = await client
        .postUrl(Uri.parse(kSgpcArchiveUrl))
        .timeout(const Duration(seconds: 20));
    request.headers
      ..set('X-Requested-With', 'XMLHttpRequest')
      ..contentType = ContentType(
        'application',
        'x-www-form-urlencoded',
        charset: 'utf-8',
      );
    request.write('selected_date=$day');
    final response = await request.close().timeout(
          const Duration(seconds: 20),
        );
    final body = BytesBuilder(copy: false);
    await for (final chunk in response.timeout(const Duration(seconds: 30))) {
      body.add(chunk);
    }
    return SgpcReply(response.statusCode, body.takeBytes());
  } finally {
    client.close(force: true);
  }
}

Future<void> main(List<String> args) async {
  var out = '.';
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--out' && i + 1 < args.length) {
      out = args[++i];
    } else {
      stderr.writeln('Usage: dart tool/hukamnama_mirror.dart [--out DIR]');
      exit(64);
    }
  }

  final report = await mirror(
    root: Directory(out),
    now: DateTime.now(),
    fetch: fetchFromSgpc,
  );

  // GitHub Actions turns `::warning::` and `::error::` lines into annotations.
  final inCi = Platform.environment['GITHUB_ACTIONS'] == 'true';
  for (final entry in report.outcomes.entries) {
    stdout.writeln('${entry.key}: ${entry.value.name}');
  }
  for (final (level, message) in [
    for (final m in report.warnings) ('warning', m),
    for (final m in report.errors) ('error', m),
  ]) {
    stdout.writeln(inCi ? '::$level::$message' : '$level: $message');
  }
  exit(report.exitCode);
}
