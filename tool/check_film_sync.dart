// Checks that a demo film on darbar.live is in step with its data file.
//
//     dart tool/check_film_sync.dart site/img/film.mp4 site/img/film.json
//     dart tool/check_film_sync.dart site/img/film.mp4 site/img/film.json \
//       site/img/film-pa.mp4 site/img/film-pa.json
//
// It reads the MP4 and measures, for each tap in the data file:
//
//   screen   the frame where the picture first changes round the tapped place
//   playing  the frame where the tapped button turns to its playing glyph
//            (only for the 3 taps that start sound)
//   sound    the moment the chapter's sound starts (only for those 3)
//
// It fails, with exit code 1, when:
//
//   - the screen time or the sound time differs from the data file by more
//     than 80 ms;
//   - the sound starts more than 80 ms from the playing frame: the viewer must
//     not hear a chapter before the screen shows it plays, or after;
//   - a chapter starts more than 0.5 s from the tap that the data file names
//     as its first, measured on the film, or the chapters do not run one into
//     the next from 0 to the end of the film;
//   - the chapters on the page, which name themselves with data-chapter, are
//     not the chapters of the data file, in the same order (the page is
//     site/index.html for film.json, and site/pa/index.html for film-pa.json);
//   - the picture stands still for more than 0.8 s, or the film is silent for
//     more than 0.8 s. The app moves all the time while it plays, and the
//     sound does not stop for long, so either is a stop in the film.
//
// Run it after tool/site_film.dart, on each film.
import 'dart:convert';
import 'dart:io';

import 'film_lib.dart';

/// The most that a measured time may differ from the file's, in seconds.
const _tolerance = 0.08;

/// The most that a chapter may start from its first tap, in seconds.
const _startTolerance = 0.5;

/// The longest that the film may stand still, or be silent, in seconds.
const _longestStop = 0.8;

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.length.isOdd) {
    stderr.writeln('Usage: dart tool/check_film_sync.dart film.mp4 film.json [film.mp4 film.json ...]');
    exit(2);
  }
  var ok = true;
  for (var i = 0; i < args.length; i += 2) {
    if (!await _check(args[i], args[i + 1])) ok = false;
  }
  stdout.writeln(ok ? 'PASS' : 'FAIL');
  exit(ok ? 0 : 1);
}

class _Tap {
  _Tap(this.id, this.x, this.y, this.t, this.audio);
  final String id;
  final double x;
  final double y;

  /// When the screen reacts, by the data file.
  final double t;

  /// When the sound starts, by the data file. Null when the tap starts none.
  final double? audio;
}

Future<bool> _check(String mp4, String jsonPath) async {
  final data = jsonDecode(File(jsonPath).readAsStringSync()) as Map<String, dynamic>;
  final taps = [
    for (final t in (data['taps'] as List).cast<Map<String, dynamic>>())
      _Tap(
        t['id'] as String,
        (t['x'] as num).toDouble(),
        (t['y'] as num).toDouble(),
        (t['t'] as num).toDouble(),
        (t['audio'] as num?)?.toDouble(),
      ),
  ];
  final withSound = taps.where((t) => t.audio != null).toList();
  final chapters = (data['chapters'] as List).cast<Map<String, dynamic>>();
  const fps = 30;

  stdout.writeln('\n$mp4');
  final frames = await readFrames(
    mp4,
    fps: fps,
    rois: [for (final t in withSound) Roi(t.x, t.y)],
  );
  final sound = await readSound(mp4);
  final length = (data['duration'] as num).toDouble();
  if ((frames.duration - length).abs() > 0.1) {
    stdout.writeln('not ok: the film is ${frames.duration.toStringAsFixed(2)} s long, '
        'and the data file says ${length.toStringAsFixed(2)} s');
    return false;
  }

  // The screen, for every tap.
  final screen = <String, double>{};
  for (final t in taps) {
    final f = changeNear(
      frames.small, fps, Place(t.x, t.y), t.t,
      halfWidth: tapHalfWidth(t.id),
    );
    if (f != null) screen[t.id] = f / fps;
  }

  String ms(double v) => '${v >= 0 ? '+' : '-'}${(v.abs() * 1000).round()}'.padLeft(6);
  String sec(double? v) => v == null ? '     -' : v.toStringAsFixed(3).padLeft(6);

  var ok = true;
  stdout.writeln('${'tap'.padRight(10)} ${'screen'.padLeft(6)} ${'json'.padLeft(6)} ${'diff ms'.padLeft(7)}'
      '  ${'playing'.padLeft(7)} ${'json'.padLeft(6)} ${'sound'.padLeft(6)} ${'diff ms'.padLeft(7)} ${'vs playing'.padLeft(10)}');
  for (var i = 0; i < taps.length; i++) {
    final t = taps[i];
    final s = screen[t.id];
    final screenDiff = s == null ? null : s - t.t;
    final screenOk = screenDiff != null && screenDiff.abs() <= _tolerance;
    var line = '${t.id.padRight(10)} ${sec(s)} ${sec(t.t)} ${screenDiff == null ? '   none' : ms(screenDiff).padLeft(7)}';

    var rowOk = screenOk;
    if (t.audio != null) {
      final k = withSound.indexOf(t);
      double? playing;
      if (s != null && screen[taps[i + 1].id] != null) {
        playing = playingTime(
          frames.rois[k], fps, tap: s, next: screen[taps[i + 1].id]!,
        );
      }
      final onset = s == null
          ? null
          : audioOnset(sound, tap: s, expected: t.audio!);
      final soundDiff = onset == null ? null : onset - t.audio!;
      final againstPlaying = onset == null || playing == null ? null : onset - playing;
      final soundOk = soundDiff != null && soundDiff.abs() <= _tolerance;
      final playOk = againstPlaying != null && againstPlaying.abs() <= _tolerance;
      line += '  ${sec(playing)}  ${sec(t.audio)} ${sec(onset)} '
          '${soundDiff == null ? '   none' : ms(soundDiff).padLeft(7)} '
          '${againstPlaying == null ? '      none' : ms(againstPlaying).padLeft(10)}';
      rowOk = rowOk && soundOk && playOk;
    }
    if (!rowOk) {
      line += '   <-- OUT OF STEP';
      ok = false;
    }
    stdout.writeln(line);
  }
  stdout.writeln(ok
      ? 'ok: screen and sound are within ${(_tolerance * 1000).round()} ms of the data file'
      : 'not ok: a time is more than ${(_tolerance * 1000).round()} ms from the data file');

  // The chapters.
  var chaptersOk = true;
  stdout.writeln('\n${'chapter'.padRight(10)} ${'start'.padLeft(6)} ${'tap'.padRight(10)} ${'screen'.padLeft(6)} ${'start - tap'.padLeft(11)}');
  var expectedStart = 0.0;
  for (var i = 0; i < chapters.length; i++) {
    final c = chapters[i];
    final id = c['id'] as String;
    final start = (c['start'] as num).toDouble();
    final end = (c['end'] as num).toDouble();
    final tapId = c['tap'] as String?;
    final at = tapId == null ? null : screen[tapId];
    final off = at == null ? null : start - at;
    final startOk = off != null && off.abs() <= _startTolerance;
    final runsOn = (start - expectedStart).abs() < 0.002 && end > start;
    stdout.writeln('${id.padRight(10)} ${sec(start)} ${(tapId ?? '-').padRight(10)} ${sec(at)} '
        '${off == null ? '       none' : ms(off).padLeft(8)} ms'
        '${startOk ? '' : '   <-- STARTS TOO FAR FROM ITS TAP'}'
        '${runsOn ? '' : '   <-- DOES NOT RUN ON FROM THE ONE BEFORE'}');
    if (!startOk || !runsOn) chaptersOk = false;
    expectedStart = end;
  }
  if ((expectedStart - length).abs() > 0.01) {
    stdout.writeln('the last chapter ends at ${expectedStart.toStringAsFixed(3)} s, '
        'and the film is ${length.toStringAsFixed(3)} s long');
    chaptersOk = false;
  }
  stdout.writeln(chaptersOk
      ? 'ok: each chapter starts within $_startTolerance s of its first tap'
      : 'not ok: a chapter does not start within $_startTolerance s of its first tap');
  ok = ok && chaptersOk;

  // The page's chapters.
  final pageOk = _checkPage(jsonPath, [for (final c in chapters) c['id'] as String]);
  ok = ok && pageOk;

  // Dead time.
  final frozen = frozenStretches(frames.small, fps, longer: _longestStop);
  final silent = silentStretches(sound, longer: _longestStop);
  for (final f in frozen) {
    stdout.writeln('not ok: the picture stands still for $f');
  }
  for (final q in silent) {
    stdout.writeln('not ok: no sound for $q');
  }
  if (frozen.isEmpty && silent.isEmpty) {
    stdout.writeln('ok: the picture never stands still, and the film is never silent, '
        'for more than $_longestStop s');
  } else {
    ok = false;
  }
  return ok;
}

/// Checks that the page names the chapters of the film [jsonPath] in order:
/// each button of its chapter bar has `data-chapter="id"`. Returns true when it
/// does, and when there is no page to check.
bool _checkPage(String jsonPath, List<String> ids) {
  final name = jsonPath.split(Platform.pathSeparator).last;
  // site/img/film.json is for site/index.html, site/img/film-pa.json for
  // site/pa/index.html.
  final site = File(jsonPath).parent.parent.path;
  final page = File(name.contains('-pa')
      ? '$site${Platform.pathSeparator}pa${Platform.pathSeparator}index.html'
      : '$site${Platform.pathSeparator}index.html');
  if (!page.existsSync()) {
    stdout.writeln('skipped: no page at ${page.path}');
    return true;
  }
  final onPage = [
    for (final m in RegExp(r'<button[^>]*\bdata-chapter="([^"]+)"')
        .allMatches(page.readAsStringSync()))
      m.group(1)!,
  ];
  final same = onPage.length == ids.length &&
      [for (var i = 0; i < ids.length; i++) onPage[i] == ids[i]].every((b) => b);
  stdout.writeln(same
      ? 'ok: ${page.path} has the chapters ${ids.join(', ')}'
      : 'not ok: ${page.path} has the chapters ${onPage.join(', ')}, '
          'and the film has ${ids.join(', ')}');
  return same;
}
