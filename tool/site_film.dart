// Builds one demo film for the darbar.live landing page, from a screen
// recording of the app: the video, its sound track, its poster, and the file
// that tells the page where the cursor and the chapters are. Run it once for
// each language.
//
//     dart tool/site_film.dart --raw raw.mov --marks marks.log --pass A \
//       --audio audio/
//     dart tool/site_film.dart --raw raw.mov --marks marks.log --pass C \
//       --audio audio/ --suffix -pa
//
// It writes site/img/film<suffix>.mp4 (H.264, AAC), film<suffix>.webm (VP9,
// Opus), film-poster<suffix>.webp (the first frame) and film<suffix>.json.
// Then run tool/check_film_sync.dart on each film.
//
// Input, all made by hand beforehand:
//
//   --raw    the simulator recording that integration_test/landing_film_test.dart
//            makes (its doc comment says how)
//   --marks  the marks.log that test writes beside it
//   --pass   A for the English pass, C for the Punjabi pass
//   --audio  a folder with the 3 recordings the app plays, each made with
//            ffmpeg, from the URLs in lib/src/models:
//              live-high.aac   -t 45 -c copy, from http://live.sgpc.net:7339/;
//              hukamnama.mp3   https://hs.sgpc.net/uploadhukamnama/hukamnama.mp3
//              katha.mp3       https://hs.sgpc.net/uploadkatha/katha.mp3
//            The simulator's audio does not reach the recording, so the sound
//            is added here. Check that the live file carries kirtan and not
//            the silence between sessions.
//
// How it works:
//
//   1. The test writes a mark just before each tap, in the clock of the Mac.
//      The recording has its own clock. This script finds each tap on the
//      recording by looking for the frame where the screen first changes round
//      the place that was tapped, and takes that frame as the tap.
//   2. The app shows that a source plays on the frame where the tapped
//      button's glyph turns from play to pause (or stop). That is the frame
//      where the sound must start, and not the tap: SGPC's recordings take up
//      to a few seconds to load. A wait of more than 0.6 s from the tap to
//      that frame is cut out of the video, at 2 frames of the loading ring
//      that look the same, so the cut does not show.
//   3. The film is rendered from those cuts. It is one take: the app is never
//      restarted inside a pass, so nothing else is cut. Every time in the data
//      file is then measured again, on the film itself, and not worked out
//      from the recording.
//   4. The sound: live kirtan, the Hukamnama, then the Katha, each starting on
//      its source's playing frame and stopped by the tap that starts the next.
//      A soft click sounds at every tap. Live kirtan plays through the
//      quality part without a break. From the tap on Data saver it is the same
//      kirtan through a real 28 kbps AAC encode (mono, AAC-LC), cross-faded
//      over 150 ms.
//   5. The cursor and the chapters go to the JSON file. The page draws the
//      cursor by the video's clock, from that file. A chapter starts 0.3 s
//      before its first tap, and the file names that tap, so that
//      tool/check_film_sync.dart can check it.
//
// Aim for under 1 MB for each file. Raise CRF_MP4 or CRF_WEBM when one runs over.
//
// Needs ffmpeg (libx264, libvpx-vp9, libopus) and cwebp (brew install webp).
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'film_lib.dart';

// The recording is 60 fps. The film is 30.
const _detectFps = 60;
const _filmFps = 30;

// The order of the taps in a pass, and the part of the film each one starts.
// A part starts [_partLead] before its first tap, so a viewer who jumps to a
// part sees the app as it is just before the tap, and the tap itself.
const _taps = [
  'live',
  'player',
  'quality',
  'saver',
  'scrim',
  'close',
  'hukamnama',
  'katha',
  'language',
];
// Each part: its id, and the tap that starts it.
const _parts = [
  ('live', 'live'),
  ('quality', 'player'),
  ('hukamnama', 'hukamnama'),
  ('katha', 'katha'),
  ('language', 'language'),
];

// Seconds.
const _partLead = 0.3; // a part starts this long before its first tap
const _leadIn = _partLead; // so the film runs this long before the first tap
const _travel = 0.95; // the cursor takes this long to reach a tap
const _maxWait = 0.6; // a longer wait from a tap to its playing frame is cut
const _keepWait = 0.45; // and what is left of it is about this long
const _fadeIn = 0.04; // a source starts with a fade this long
const _crossfade = 0.15; // the switch to Data saver
const _tailAfterLast = 2.0; // the film ends this long after the last tap

// Each source: its file, and the seconds into it where the film takes it.
// The live kirtan is taken from where that recording is loud and steady, so
// the film does not swell or drop. The file is 45 s long, and the kirtan has
// to last from the first tap to the Hukamnama, about 17 s. The Hukamnama
// starts where its first word is, 0.42 s in: the app plays the 0.4 s of room
// hiss before it too, but a film whose sound lags its picture by that much is
// wrong. The Katha starts at its start.
const _sources = {
  'live': ('live-high.aac', 24.0),
  'hukamnama': ('hukamnama.mp3', 0.42),
  'katha': ('katha.mp3', 0.0),
};

Future<void> main(List<String> args) async {
  final a = _Args(args);
  final root = File(Platform.script.toFilePath()).parent.parent.path;
  final out = a.opt('out') ?? '$root/site/img';
  final suffix = a.opt('suffix') ?? '';
  final pass = a.need('pass');
  final rawPath = a.need('raw');
  final audio = Directory(a.need('audio')).absolute.path;
  final crfMp4 = Platform.environment['CRF_MP4'] ?? '31';
  final crfWebm = Platform.environment['CRF_WEBM'] ?? '41';

  final marks = _readMarks(a.need('marks'));
  Mark m(String name) => marks['${pass}_$name'] ?? _fail('No mark ${pass}_$name.');
  Place place(String name) => Place(m(name).x!, m(name).y!);
  final work = Directory.systemTemp.createTempSync('site_film');
  try {
    // ---- 1. Find each tap on the recording ----
    stdout.writeln('Reading frames of $rawPath ...');
    final rois = [for (final n in audioTaps) Roi(m(n).x!, m(n).y!)];
    final raw = await readFrames(rawPath, fps: _detectFps, rois: rois);
    stdout.writeln('  ${raw.small.length} frames');

    final rawTap = _findTaps(raw.small, marks, pass);
    final tapList = [for (final n in _taps) '$n ${rawTap[n]!.toStringAsFixed(2)} s'];
    stdout.writeln('  taps: ${tapList.join(', ')}');

    // ---- 2. Where the app shows that it plays, and the waits to cut ----
    final rawPlay = <String, double>{};
    for (var i = 0; i < audioTaps.length; i++) {
      final name = audioTaps[i];
      final next = _taps[_taps.indexOf(name) + 1];
      rawPlay[name] = playingTime(
        raw.rois[i], _detectFps, tap: rawTap[name]!, next: rawTap[next]!,
      );
    }
    final cuts = <_Cut>[];
    for (final name in audioTaps) {
      final tapF = (rawTap[name]! * _detectFps).round();
      final playF = (rawPlay[name]! * _detectFps).round();
      final wait = (playF - tapF) / _detectFps;
      stdout.writeln('  ${name.padRight(10)} tap ${rawTap[name]!.toStringAsFixed(3)} s, '
          'playing ${rawPlay[name]!.toStringAsFixed(3)} s, wait ${wait.toStringAsFixed(2)} s');
      if (wait > _maxWait) cuts.add(_findCut(raw.small, name, tapF, playF, wait));
    }
    for (final c in cuts) {
      stdout.writeln('  cut ${c.name}: ${(c.a / _detectFps).toStringAsFixed(3)} s to '
          '${(c.b / _detectFps).toStringAsFixed(3)} s, looks alike to ${c.score.toStringAsFixed(2)}');
    }

    // ---- 3. The cut: the film, from before the first tap to the end mark ----
    final startF = math.max(0, ((rawTap['live']! - _leadIn) * _detectFps).round());
    // The film ends a little after the last tap, and before the test ends
    // and the app goes: the first big change after the tap is the app leaving.
    final lastF = (rawTap['language']! * _detectFps).round();
    var endF = math.min(
      ((rawTap['language']! + _tailAfterLast) * _detectFps).round(),
      raw.small.length,
    );
    for (var n = lastF + (0.6 * _detectFps).round(); n < endF + _detectFps; n++) {
      if (n < raw.small.length && meanDifference(raw.small[n - 1], raw.small[n]) > 4) {
        endF = math.min(endF, n - (0.25 * _detectFps).round());
        break;
      }
    }
    final keep = <(int, int)>[];
    var from = startF;
    for (final c in cuts) {
      keep.add((from, c.a));
      from = c.b;
    }
    keep.add((from, endF));
    final edited = '${work.path}/edited.mp4';
    await _renderEdited(rawPath, keep, edited);

    // ---- 4. Measure the film itself ----
    // Where each tap should be on the edited film, to look for it there.
    double toFilm(double rawTime) {
      final f = rawTime * _detectFps;
      var n = f - startF;
      for (final c in cuts) {
        if (f >= c.b) {
          n -= c.b - c.a;
        } else if (f > c.a) {
          n -= f - c.a;
        }
      }
      return n / _detectFps;
    }

    stdout.writeln('Reading frames of the film ...');
    final film = await readFrames(edited, fps: _filmFps, rois: rois);
    final duration = film.duration;
    final tap = <String, double>{};
    for (final name in _taps) {
      final predicted = toFilm(rawTap[name]!);
      final frame = changeNear(
        film.small, _filmFps, place(name), predicted,
        slack: 0.3,
        halfWidth: tapHalfWidth(name),
      );
      if (frame == null) _fail('No change found in the film for the tap "${pass}_$name".');
      tap[name] = frame / _filmFps;
    }
    final play = <String, double>{};
    for (var i = 0; i < audioTaps.length; i++) {
      final name = audioTaps[i];
      final next = _taps[_taps.indexOf(name) + 1];
      play[name] = playingTime(
        film.rois[i], _filmFps, tap: tap[name]!, next: tap[next]!,
      );
    }
    stdout.writeln('Film: ${(startF / _detectFps).toStringAsFixed(2)} s to '
        '${(endF / _detectFps).toStringAsFixed(2)} s of the recording, '
        '${duration.toStringAsFixed(2)} s long');
    for (final name in _taps) {
      final wait = play.containsKey(name) ? play[name]! - tap[name]! : null;
      stdout.writeln('  ${name.padRight(10)} tap ${tap[name]!.toStringAsFixed(3)} s'
          '${wait == null ? '' : '  playing ${play[name]!.toStringAsFixed(3)} s  wait ${wait.toStringAsFixed(2)} s'}');
      if (wait != null && wait > _maxWait + 0.1) {
        _fail('The wait for "$name" is still ${wait.toStringAsFixed(2)} s.');
      }
    }

    // ---- 5. The data file ----
    double at(String tapName) => tap[tapName]!;
    final starts = <double>[
      for (var i = 0; i < _parts.length; i++)
        i == 0 ? 0.0 : at(_parts[i].$2) - _partLead,
    ];
    final chapters = [
      for (var i = 0; i < _parts.length; i++)
        {
          'id': _parts[i].$1,
          // The tap that starts the part, for tool/check_film_sync.dart.
          'tap': _parts[i].$2,
          'start': _r(starts[i]),
          'end': _r(i + 1 < _parts.length ? starts[i + 1] : duration),
        },
    ];
    // The cursor waits close to the first tap, so it can reach it in the
    // 0.3 s that the film runs before it.
    final first = m(_taps.first);
    final cursor = <List<double>>[
      [0, first.x! + 0.10, first.y! + 0.09],
    ];
    var prevT = 0.0;
    var prevX = first.x! + 0.10;
    var prevY = first.y! + 0.09;
    for (final name in _taps) {
      final mark = m(name);
      final t = at(name);
      final depart = name == _taps.first ? 0.0 : math.max(t - _travel, prevT + 0.15);
      if (depart > prevT + 0.01) cursor.add([depart, prevX, prevY]);
      cursor.add([t, mark.x!, mark.y!]);
      prevT = t;
      prevX = mark.x!;
      prevY = mark.y!;
    }
    cursor.add([duration, prevX, prevY]);
    final json = {
      'duration': _r(duration),
      'chapters': chapters,
      'cursor': [
        for (final k in cursor) [_r(k[0]), _r(k[1], 4), _r(k[2], 4)],
      ],
      'clicks': [for (final name in _taps) _r(at(name))],
      // For tool/check_film_sync.dart. "t" is when the screen reacts to the
      // tap. "playing" is when the tapped button shows that the source plays,
      // and "audio" is when its sound starts: the same moment.
      'taps': [
        for (final name in _taps)
          {
            'id': name,
            'x': _r(m(name).x!, 4),
            'y': _r(m(name).y!, 4),
            't': _r(at(name)),
            if (play.containsKey(name)) 'playing': _r(play[name]!),
            if (play.containsKey(name)) 'audio': _r(play[name]!),
          },
      ],
    };
    File('$out/film$suffix.json')
        .writeAsStringSync('${const JsonEncoder().convert(json)}\n');

    // ---- 6. The sound ----
    final soundFile = await _buildSound(
      work: work.path,
      audio: audio,
      tap: tap,
      play: play,
      duration: duration,
    );

    // ---- 7. The video, both ways ----
    final inputs = ['-i', edited, '-i', soundFile];
    final map = ['-map', '0:v', '-map', '1:a', '-t', duration.toStringAsFixed(3)];
    await run('ffmpeg', [
      '-hide_banner', '-loglevel', 'error', '-y', '-threads', '4', ...inputs, ...map,
      '-c:v', 'libx264', '-preset', 'slow', '-profile:v', 'main', '-level', '3.1',
      '-crf', crfMp4, '-r', '$_filmFps',
      '-c:a', 'aac', '-b:a', '64k', '-movflags', '+faststart',
      '$out/film$suffix.mp4',
    ]);
    await run('ffmpeg', [
      '-hide_banner', '-loglevel', 'error', '-y', '-threads', '4', ...inputs, ...map,
      '-c:v', 'libvpx-vp9', '-b:v', '0', '-crf', crfWebm, '-row-mt', '1',
      '-deadline', 'good', '-cpu-used', '2', '-r', '$_filmFps',
      '-c:a', 'libopus', '-b:a', '48k',
      '$out/film$suffix.webm',
    ]);

    // The poster is the first frame, before any compression.
    await run('ffmpeg', [
      '-hide_banner', '-loglevel', 'error', '-y', '-i', edited, '-frames:v', '1',
      '${work.path}/poster.png',
    ]);
    await run('cwebp', [
      '-quiet', '-q', '78', '-m', '6', '${work.path}/poster.png',
      '-o', '$out/film-poster$suffix.webp',
    ]);
  } finally {
    work.deleteSync(recursive: true);
  }

  for (final f in ['film$suffix.mp4', 'film$suffix.webm', 'film-poster$suffix.webp', 'film$suffix.json']) {
    stdout.writeln('${File('$out/$f').lengthSync().toString().padLeft(9)}  $out/$f');
  }
}

double _r(double v, [int digits = 3]) => double.parse(v.toStringAsFixed(digits));

/// The time of every tap of [pass] on the recording, by the frame where the
/// screen first changes round the place that was tapped.
///
/// The marks give the order and the places of the taps. They do not give the
/// times, because the recording's clock is not the Mac's: it can run behind
/// it, or ahead, by a second over a few seconds. So each tap is looked for
/// after the one before it, in a window as long as the marks say the gap was,
/// and then some.
Map<String, double> _findTaps(
  List<Uint8List> frames,
  Map<String, Mark> marks,
  String pass,
) {
  Mark m(String p, String name) =>
      marks['${p}_$name'] ?? _fail('No mark ${p}_$name.');
  Place at(String name) => Place(m(pass, name).x!, m(pass, name).y!);

  double firstTap;
  if (pass == 'A' || !marks.containsKey('A_language')) {
    // The recording starts a few seconds before the test does, by a different
    // amount each time. Look for the first tap anywhere in the first 12
    // seconds, and as a clear change, because the recording's own start-up
    // flickers.
    final f = firstChange(frames, _detectFps, at('live'), 1.0, 12.0, minimum: 80);
    if (f == null) _fail('No change found for the tap "${pass}_live".');
    firstTap = f / _detectFps;
  } else {
    // The Punjabi pass starts from a fresh app, after the English pass. Look
    // for its first tap where the marks put it, counted from the last tap of
    // the English pass.
    final lastA = _findTaps(frames, marks, 'A')['language']!;
    final predicted =
        lastA + (m(pass, 'live').epoch - m('A', 'language').epoch) / 1000;
    final f = firstChange(
      frames, _detectFps, at('live'), predicted - 1.5, predicted + 3.0,
      minimum: 80,
    );
    if (f == null) _fail('No change found for the tap "${pass}_live".');
    firstTap = f / _detectFps;
  }

  final times = <String, double>{'live': firstTap};
  for (var i = 1; i < _taps.length; i++) {
    final name = _taps[i];
    final prev = times[_taps[i - 1]]!;
    final gap = (m(pass, name).epoch - m(pass, _taps[i - 1]).epoch) / 1000;
    // Other things change the picture round a tap too: take the change that
    // is nearest to where the marks put the tap.
    // The window starts 0.6 s after the last tap, when what that tap set
    // moving has settled: it is what the quiet level before the window is
    // taken from.
    final predicted = prev + gap;
    final slack = math.max(1.2, gap * 0.8);
    final all = changeFrames(
      frames, _detectFps, at(name),
      math.max(predicted - slack, prev + 0.6), predicted + slack,
      halfWidth: tapHalfWidth(name),
    );
    if (all.isEmpty) _fail('No change found for the tap "${pass}_$name".');
    all.sort((a, b) =>
        (a / _detectFps - predicted).abs().compareTo((b / _detectFps - predicted).abs()));
    times[name] = all.first / _detectFps;
  }
  return times;
}

/// A stretch of the recording to leave out: frames [a, b).
class _Cut {
  _Cut(this.name, this.a, this.b, this.score);
  final String name;
  final int a;
  final int b;
  final double score;
}

/// Where to cut the wait between the tap on [name] (frame [tapF]) and its
/// playing frame ([playF]), which is [wait] seconds.
///
/// While the app loads, the picture is the same except for the ring that turns
/// on the button. So it looks for a frame a to leave and a frame b to go on
/// from whose pictures match best, and the cut does not show. A cut ends the
/// wait at about [_keepWait] seconds. It leaves the press and the start of the
/// ring at the front, and the last 0.1 s of the wait before the glyph morphs.
_Cut _findCut(List<Uint8List> frames, String name, int tapF, int playF, double wait) {
  final remove = ((wait - _keepWait) * _detectFps).ceil();
  final earliest = tapF + (0.30 * _detectFps).round();
  final latest = tapF + (0.55 * _detectFps).round();
  final lastB = playF - (0.10 * _detectFps).round();
  _Cut? best;
  for (var a = earliest; a <= latest; a++) {
    for (var b = a + remove; b <= lastB; b++) {
      // 2 frames each, so the ring turns the same way on both sides.
      final score = (meanDifference(frames[a], frames[b]) +
              meanDifference(frames[a + 1], frames[b + 1])) /
          2;
      if (best == null || score < best.score) best = _Cut(name, a, b, score);
    }
  }
  if (best == null) _fail('No place to cut the wait for "$name".');
  return best;
}

/// The film's frames, with the cuts left out, at [_filmFps]: 1 pass of 540 by
/// 1174 pixels, nearly lossless.
Future<void> _renderEdited(String raw, List<(int, int)> keep, String out) async {
  final g = StringBuffer('[0:v]fps=$_detectFps,split=${keep.length}');
  for (var i = 0; i < keep.length; i++) {
    g.write('[s$i]');
  }
  g.write(';');
  for (var i = 0; i < keep.length; i++) {
    g.write('[s$i]trim=start_frame=${keep[i].$1}:end_frame=${keep[i].$2},'
        'setpts=PTS-STARTPTS[v$i];');
  }
  for (var i = 0; i < keep.length; i++) {
    g.write('[v$i]');
  }
  g.write('concat=n=${keep.length}:v=1:a=0,fps=$_filmFps,'
      'scale=540:1174:flags=lanczos,format=yuv420p[v]');
  await run('ffmpeg', [
    '-hide_banner', '-loglevel', 'error', '-y', '-threads', '4', '-i', raw,
    '-filter_complex', g.toString(), '-map', '[v]',
    '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '6', '-r', '$_filmFps',
    out,
  ]);
}

/// The sound track, as 1 WAV file. See the notes at the top.
Future<String> _buildSound({
  required String work,
  required String audio,
  required Map<String, double> tap,
  required Map<String, double> play,
  required double duration,
}) async {
  // When each source stops: when the tap that starts the next one lands. The
  // Katha goes on to the end of the film.
  final stops = <String, double>{
    'live': tap['hukamnama']!,
    'hukamnama': tap['katha']!,
    'katha': duration,
  };
  // A source stops with a short fade. The next one starts later, but not by
  // much, so the fade is short enough to end before it.
  double stopFade(String name) {
    final i = audioTaps.indexOf(name);
    if (i + 1 >= audioTaps.length) return 0.6;
    return (play[audioTaps[i + 1]]! - stops[name]! - 0.04).clamp(0.02, 0.08);
  }

  const chain = 'aresample=44100,aformat=sample_fmts=fltp:channel_layouts=stereo,'
      'highpass=f=60,loudnorm=I=-19:TP=-2:LRA=9,aresample=44100,'
      'aformat=sample_fmts=fltp:channel_layouts=stereo';

  // Each source, decoded from its start, as a WAV. Seeking in an MP3 loses the
  // first 50 ms or so, and does not do it the same way twice. A WAV can be cut
  // to the sample.
  final decoded = <String, String>{};
  Future<String> decode(String src) async {
    return decoded[src] ??= await () async {
      final wav = '$work/${src.replaceAll('.', '_')}.wav';
      await run('ffmpeg', [
        '-hide_banner', '-loglevel', 'error', '-y', '-t', '70', '-i', '$audio/$src',
        '-c:a', 'pcm_s16le', wav,
      ]);
      return wav;
    }();
  }

  /// [seconds] of [name]'s source, levelled, as a WAV. It starts where the
  /// sound does: the first frame of the file is often silence, and the
  /// Hukamnama begins with room hiss. The film must not carry that lag.
  Future<String> segment(String name, double seconds, String file) async {
    final (src, taken) = _sources[name]!;
    final wav = await decode(src);
    final head = await readSound(wav,
        inputArgs: ['-ss', taken.toStringAsFixed(3), '-t', '3']);
    final lead = audioOnset(head, tap: 0, expected: 0, within: 2.0) ?? 0.0;
    // audioOnset names the middle of the first window that is loud enough.
    final from = taken + math.max(0.0, lead - 0.003);
    await run('ffmpeg', [
      '-hide_banner', '-loglevel', 'error', '-y',
      '-ss', from.toStringAsFixed(3), '-t', (seconds + 0.5).toStringAsFixed(3),
      '-i', wav, '-af',
      '$chain,atrim=duration=${seconds.toStringAsFixed(3)}',
      '-c:a', 'pcm_s16le', file,
    ]);
    return file;
  }

  final inputs = <String>[];
  final graph = StringBuffer();
  final mix = StringBuffer();
  var n = 0;
  void place(String file, double at, String filters, String label) {
    inputs.addAll(['-i', file]);
    final ms = (at * 1000).round();
    graph.write('[$n:a]$filters,adelay=$ms|$ms[$label];');
    mix.write('[$label]');
    n++;
  }

  for (final name in audioTaps) {
    final onset = play[name]!;
    final length = stops[name]! - onset + stopFade(name);
    if (name == 'live') {
      // The same kirtan twice, from the same moment: as the stream gives it,
      // and through a real 28 kbps AAC encode. The film moves from the first to
      // the second at the tap on Data saver, over [_crossfade] seconds. They
      // match to the sample, so a straight fade holds the level. The second
      // goes on to the tap on the Hukamnama.
      final hi = await segment(name, length, '$work/live_hi.wav');
      final lo = await _dataSaver(hi, '$work/live_lo.wav');
      final switchAt = tap['saver']! - onset;
      final fade = stopFade(name);
      place(
        hi, onset,
        'afade=t=in:st=0:d=$_fadeIn:curve=qsin,'
            'afade=t=out:st=${switchAt.toStringAsFixed(3)}:d=$_crossfade:curve=tri',
        'hi',
      );
      place(
        lo, onset,
        'afade=t=in:st=${switchAt.toStringAsFixed(3)}:d=$_crossfade:curve=tri,'
            'afade=t=out:st=${(length - fade).toStringAsFixed(3)}:d=${fade.toStringAsFixed(3)}:curve=qsin',
        'lo',
      );
    } else {
      final file = await segment(name, length, '$work/$name.wav');
      final fade = stopFade(name);
      place(
        file, onset,
        'afade=t=in:st=0:d=$_fadeIn:curve=qsin,'
            'afade=t=out:st=${(length - fade).toStringAsFixed(3)}:d=${fade.toStringAsFixed(3)}:curve=qsin',
        name,
      );
    }
  }

  // One soft click at each tap: the press, and a quieter release 90 ms later.
  const click = '0.5*(sin(2*PI*1100*t)*exp(-t*70)+0.6*sin(2*PI*520*t)*exp(-t*45))'
      '*min(1,t/0.003)'
      '+if(gte(t,0.09),0.2*sin(2*PI*900*(t-0.09))*exp(-(t-0.09)*90),0)';
  final clickGraph = StringBuffer(
    "aevalsrc='$click':d=0.3:s=44100,"
    'aformat=sample_fmts=fltp:channel_layouts=stereo,lowpass=f=3500,volume=0.55,'
    'asplit=${_taps.length}',
  );
  for (var i = 0; i < _taps.length; i++) {
    clickGraph.write('[c$i]');
  }
  clickGraph.write(';');
  for (var i = 0; i < _taps.length; i++) {
    final ms = (tap[_taps[i]]! * 1000).round();
    clickGraph.write('[c$i]adelay=$ms|$ms[k$i];');
    mix.write('[k$i]');
  }
  final count = n + _taps.length;
  final out = '$work/sound.wav';
  await run('ffmpeg', [
    '-hide_banner', '-loglevel', 'error', '-y', ...inputs,
    '-filter_complex',
    '$graph$clickGraph${mix}amix=inputs=$count:normalize=0:duration=longest,'
        'alimiter=limit=0.9,'
        'afade=t=out:st=${(duration - 0.6).toStringAsFixed(2)}:d=0.6,'
        'atrim=duration=${duration.toStringAsFixed(3)}[a]',
    '-map', '[a]', '-c:a', 'pcm_s16le', out,
  ]);
  return out;
}

/// [wav] through a real 28 kbps AAC encode, decoded again, lined up with the
/// original to the sample, and at the same level.
///
/// It is 28 kbps of AAC-LC, mono: ffmpeg's encoder. Apple's encoder (aac_at)
/// cannot go under 64 kbps for stereo or 32 for mono, and the native encoder
/// at 28 kbps stereo keeps nothing above 5 kHz. Mono at 28 kbps keeps about
/// 11 kHz. SGPC's own 28 kbps stream, which is HE-AAC, keeps about 13 kHz.
/// The kirtan is near mono, so nothing is lost by it.
Future<String> _dataSaver(String wav, String out) async {
  final dir = File(out).parent.path;
  await run('ffmpeg', [
    '-hide_banner', '-loglevel', 'error', '-y', '-i', wav,
    '-af', 'pan=mono|c0=0.5*c0+0.5*c1',
    '-c:a', 'aac', '-b:a', '28k', '$dir/saver.m4a',
  ]);
  // The encoder starts a little late, and the decoder may or may not take the
  // delay off. Measure it, and take it off here.
  final (lag, gain) = await _lagAndGain(wav, '$dir/saver.m4a');
  stdout.writeln('  28 kbps encode: starts ${(lag * 1000).toStringAsFixed(1)} ms late, '
      'level ${(20 * math.log(gain) / math.ln10).toStringAsFixed(2)} dB under the original');
  final shift = lag >= 0
      ? 'atrim=start=${lag.toStringAsFixed(6)},asetpts=PTS-STARTPTS'
      : 'adelay=${(-lag * 1000).toStringAsFixed(3)}|${(-lag * 1000).toStringAsFixed(3)}';
  await run('ffmpeg', [
    '-hide_banner', '-loglevel', 'error', '-y', '-i', '$dir/saver.m4a',
    '-af', 'aresample=44100,$shift,volume=${gain.toStringAsFixed(4)},'
        'pan=stereo|c0=c0|c1=c0',
    '-c:a', 'pcm_s16le', out,
  ]);
  return out;
}

/// How many seconds later [b] is than [a], by the lag where they match best,
/// and by what factor [b] must be louder to match [a].
Future<(double, double)> _lagAndGain(String a, String b) async {
  Future<List<double>> read(String f) async {
    final s = await readSound(f);
    return [for (final v in s.samples) v.toDouble()];
  }

  final x = await read(a);
  final y = await read(b);
  // Mono samples at [soundRate]. Look 100 ms either way.
  const range = soundRate ~/ 10;
  final n = math.min(x.length, y.length) - range;
  var best = -1.0;
  var bestLag = 0;
  for (var lag = -range; lag <= range; lag++) {
    var num = 0.0;
    var dx = 0.0;
    var dy = 0.0;
    for (var i = range; i < n; i += 2) {
      final u = x[i];
      final v = y[i + lag];
      num += u * v;
      dx += u * u;
      dy += v * v;
    }
    final r = num / math.sqrt(dx * dy + 1e-9);
    if (r > best) {
      best = r;
      bestLag = lag;
    }
  }
  var dx = 0.0;
  var dy = 0.0;
  for (var i = range; i < n; i++) {
    dx += x[i] * x[i];
    dy += y[i + bestLag] * y[i + bestLag];
  }
  stdout.writeln('  28 kbps encode matches the original at r = ${best.toStringAsFixed(3)}');
  return (bestLag / soundRate, math.sqrt(dx / (dy + 1e-9)));
}

/// One line of marks.log: a name, the Mac's clock in milliseconds, and for a
/// tap, its place as a fraction of the screen.
class Mark {
  Mark(this.epoch, this.x, this.y);
  final int epoch;
  final double? x;
  final double? y;
}

Map<String, Mark> _readMarks(String path) {
  final result = <String, Mark>{};
  for (final line in File(path).readAsLinesSync()) {
    final p = line.trim().split(' ');
    if (p.length < 2) continue;
    result[p[0]] = Mark(
      int.parse(p[1]),
      p.length > 3 ? double.parse(p[2]) : null,
      p.length > 3 ? double.parse(p[3]) : null,
    );
  }
  return result;
}

class _Args {
  _Args(List<String> args) {
    for (var i = 0; i + 1 < args.length; i += 2) {
      if (!args[i].startsWith('--')) _fail('Unknown option ${args[i]}.');
      _values[args[i].substring(2)] = args[i + 1];
    }
  }
  final _values = <String, String>{};
  String? opt(String name) => _values[name];
  String need(String name) => _values[name] ?? _fail('Missing --$name.');
}

Never _fail(String message) {
  stderr.writeln('site_film: $message');
  exit(1);
}
