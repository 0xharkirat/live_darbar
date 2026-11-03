// What tool/site_film.dart (which builds a demo film) and
// tool/check_film_sync.dart (which checks one) both need: a way to read a
// video as small gray pictures, and 3 measurements taken from it.
//
//   firstChange    the frame where the screen first reacts to a tap
//   playingTime    the frame where the tapped button shows its playing glyph
//   audioOnset     the moment the sound of a chapter starts
//
// and 2 that look for dead time in a film:
//
//   frozenStretches   where the picture does not move
//   silentStretches   where there is no sound
//
// The film is right when the sound starts on the frame where the app shows
// that it plays, so the build and the check use the same measurements.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// The gray picture that the tap detection looks at.
const grayWidth = 100;
const grayHeight = 218;

/// How far a glyph picture reaches from the centre of a button, as a fraction
/// of the screen width. It holds the play, pause or stop glyph and not the
/// ring that turns while the app loads.
const glyphHalf = 0.035;

/// Taps on a row that spans the screen. What changes is the check mark at the
/// row's end, far from the place tapped.
const wideTaps = {'saver', 'scrim', 'close'};

/// Taps on the mini player. The equaliser at its left end moves all the time,
/// so the picture is only taken from the middle of it.
const narrowTaps = {'player'};

/// How far a tap's change reaches sideways, as a fraction of the screen width.
double tapHalfWidth(String id) =>
    wideTaps.contains(id) ? 0.46 : (narrowTaps.contains(id) ? 0.10 : 0.18);

/// The taps that start sound, in the order they come.
const audioTaps = ['live', 'hukamnama', 'katha'];

/// The place of a tap on the screen, as fractions of its width and height.
class Place {
  const Place(this.x, this.y);
  final double x;
  final double y;
}

/// A square round [x], [y]. [half] is its half side as a fraction of the
/// screen width.
class Roi {
  const Roi(this.x, this.y, [this.half = glyphHalf]);
  final double x;
  final double y;
  final double half;
}

class VideoInfo {
  VideoInfo(this.width, this.height, this.audioOffset);
  final int width;
  final int height;

  /// Seconds to add to a sample's time in the audio stream to get its time in
  /// the film, because the 2 streams of a file need not start together.
  final double audioOffset;
}

Future<VideoInfo> probeVideo(String path) async {
  final r = await Process.run('ffprobe', [
    '-v', 'error', '-show_entries', 'stream=codec_type,width,height,start_time',
    '-of', 'json', path,
  ]);
  if (r.exitCode != 0) fail('ffprobe failed on $path: ${r.stderr}');
  final streams = (jsonDecode(r.stdout as String)['streams'] as List)
      .cast<Map<String, dynamic>>();
  double start(Map<String, dynamic> s) =>
      double.tryParse('${s['start_time']}') ?? 0.0;
  final video = streams.where((s) => s['codec_type'] == 'video');
  final audio = streams.where((s) => s['codec_type'] == 'audio');
  // A sound file has no picture, and then no offset.
  return VideoInfo(
    video.isEmpty ? 0 : video.first['width'] as int,
    video.isEmpty ? 0 : video.first['height'] as int,
    audio.isEmpty || video.isEmpty ? 0.0 : start(audio.first) - start(video.first),
  );
}

/// All frames of a video, at [fps], as gray pictures.
class Frames {
  Frames(this.fps, this.small, this.rois);
  final int fps;

  /// The whole screen, [grayWidth] by [grayHeight].
  final List<Uint8List> small;

  /// For each region asked for, its frames.
  final List<List<Uint8List>> rois;

  double get duration => small.length / fps;
}

/// Reads every frame of [video] at [fps] in one pass: the whole screen small,
/// and each of [rois] at full size. Frame n is on screen at n / fps seconds.
Future<Frames> readFrames(
  String video, {
  required int fps,
  List<Roi> rois = const [],
}) async {
  final info = await probeVideo(video);
  final tmp = Directory.systemTemp.createTempSync('film_frames');
  try {
    final n = rois.length + 1;
    final graph = StringBuffer('[0:v]fps=$fps,split=$n');
    for (var i = 0; i < n; i++) {
      graph.write('[s$i]');
    }
    graph.write(';[s0]scale=$grayWidth:$grayHeight:flags=area,format=gray[o0]');
    final sides = <int>[];
    for (var i = 0; i < rois.length; i++) {
      final r = rois[i];
      final side = (2 * r.half * info.width).round().clamp(4, info.width);
      final x = (r.x * info.width - side / 2).round().clamp(0, info.width - side);
      final y = (r.y * info.height - side / 2).round().clamp(0, info.height - side);
      sides.add(side);
      graph.write(';[s${i + 1}]crop=$side:$side:$x:$y,format=gray[o${i + 1}]');
    }
    final args = [
      '-hide_banner', '-loglevel', 'error', '-y', '-i', video,
      '-filter_complex', graph.toString(),
      for (var i = 0; i < n; i++) ...[
        '-map', '[o$i]', '-pix_fmt', 'gray', '-f', 'rawvideo', '${tmp.path}/o$i.raw',
      ],
    ];
    await run('ffmpeg', args);

    List<Uint8List> split(String file, int size) {
      final all = File(file).readAsBytesSync();
      return [
        for (var i = 0; i + size <= all.length; i += size)
          Uint8List.sublistView(all, i, i + size),
      ];
    }

    return Frames(
      fps,
      split('${tmp.path}/o0.raw', grayWidth * grayHeight),
      [
        for (var i = 0; i < rois.length; i++)
          split('${tmp.path}/o${i + 1}.raw', sides[i] * sides[i]),
      ],
    );
  } finally {
    tmp.deleteSync(recursive: true);
  }
}

/// The first frame in [from]..[to] seconds where the picture round [tap]
/// changes more than it did just before. Null when it never does.
int? firstChange(
  List<Uint8List> frames,
  int fps,
  Place tap,
  double from,
  double to, {
  double halfWidth = 0.18,
  int minimum = 16,
}) {
  final all = changeFrames(frames, fps, tap, from, to,
      halfWidth: halfWidth, minimum: minimum);
  return all.isEmpty ? null : all.first;
}

/// The frame, in [expected] +- [slack] seconds, where a change starts that is
/// the nearest to [expected]. Null when there is none.
///
/// A tap is not the only thing that changes the picture round it: a mini
/// player that slides in, or a button that grows, does too. The time that the
/// tap should have is a better guide than being first.
int? changeNear(
  List<Uint8List> frames,
  int fps,
  Place tap,
  double expected, {
  double slack = 0.5,
  double halfWidth = 0.18,
  int minimum = 16,
}) {
  final all = changeFrames(frames, fps, tap, expected - slack, expected + slack,
      halfWidth: halfWidth, minimum: minimum);
  if (all.isEmpty) return null;
  all.sort((a, b) => (a / fps - expected).abs().compareTo((b / fps - expected).abs()));
  return all.first;
}

/// Each frame in [from]..[to] seconds where a change round [tap] starts: a
/// frame where the picture moves more than it did just before, after at least
/// 0.3 s that it did not.
///
/// It adds up how much the pixels move, and does not average it. A press on a
/// small button, or a thin check mark that fades in, changes a few pixels of a
/// small picture a little, and a mean would lose that.
List<int> changeFrames(
  List<Uint8List> frames,
  int fps,
  Place tap,
  double from,
  double to, {
  double halfWidth = 0.18,
  int minimum = 16,
}) {
  // The change of a press reaches a little past the thing tapped.
  final x0 = ((tap.x - halfWidth) * grayWidth).floor().clamp(0, grayWidth - 1);
  final x1 = ((tap.x + halfWidth) * grayWidth).ceil().clamp(1, grayWidth);
  final y0 = ((tap.y - 0.07) * grayHeight).floor().clamp(0, grayHeight - 1);
  final y1 = ((tap.y + 0.07) * grayHeight).ceil().clamp(1, grayHeight);
  int moved(int n) {
    final a = frames[n - 1];
    final b = frames[n];
    var sum = 0;
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        final d = (a[y * grayWidth + x] - b[y * grayWidth + x]).abs();
        // A difference of 1 is the video's own noise.
        if (d >= 2) sum += d;
      }
    }
    return sum;
  }

  final lo = math.max(1, (from * fps).floor());
  final hi = math.min(frames.length - 1, (to * fps).ceil());
  // What the picture does when nothing is tapped: the median of the 0.2 s
  // before each frame. One stray frame does not count, a steady animation
  // does. A change starts where a frame moves more than twice that, and not
  // less than [minimum]. The level is read from the frames before each frame,
  // and not from the window, so the same change is found whatever the window.
  final span = math.max(4, (0.2 * fps).round());
  final gap = (0.3 * fps).round();
  final first = math.max(span + 1, lo - gap);
  final moves = <int, int>{
    for (var n = first - span; n <= hi; n++) n: moved(n),
  };
  final starts = <int>[];
  var lastActive = -1000000;
  for (var n = first; n <= hi; n++) {
    final before = [for (var k = n - span; k < n; k++) moves[k]!]..sort();
    final quiet = before[before.length ~/ 2];
    if (moves[n]! < math.max(minimum, quiet * 2 + 5)) continue;
    if (n >= lo && n - lastActive > gap) starts.add(n);
    lastActive = n;
  }
  return starts;
}

/// The mean difference of 2 pictures of the same size, 0 to 255.
double meanDifference(Uint8List a, Uint8List b) {
  var sum = 0;
  for (var i = 0; i < a.length; i++) {
    sum += (a[i] - b[i]).abs();
  }
  return sum / a.length;
}

/// The time at which the tapped button shows that the app plays.
///
/// [roi] holds the frames of the button's glyph. The picture before the tap
/// shows a play glyph. The picture just before [next] (the time of the tap
/// after this one) shows what the glyph becomes: a pause or a stop. The glyph
/// morphs from the first to the second over a few frames. This returns the
/// first frame that is nearer to the second, and stays so. While the app loads
/// the glyph does not change, only the ring round it turns, and the ring is
/// outside the picture.
///
/// Throws when the glyph never changes.
double playingTime(
  List<Uint8List> roi,
  int fps, {
  required double tap,
  required double next,
}) {
  final first = (tap * fps).round();
  final last = math.min(roi.length - 1, ((next - 0.12) * fps).floor());
  final before = roi[math.max(0, ((tap - 0.1) * fps).floor())];
  final after = roi[last];
  if (meanDifference(before, after) < 3) {
    fail('The glyph at the tap at ${tap.toStringAsFixed(2)} s never changes.');
  }
  bool nearAfter(int f) =>
      meanDifference(roi[f], after) < meanDifference(roi[f], before);
  for (var f = first; f + 3 <= last; f++) {
    if (nearAfter(f) && nearAfter(f + 1) && nearAfter(f + 2) && nearAfter(f + 3)) {
      return f / fps;
    }
  }
  fail('No playing glyph after the tap at ${tap.toStringAsFixed(2)} s.');
}

/// A stretch of a film, from [start] to [end] seconds.
class Stretch {
  const Stretch(this.start, this.end);
  final double start;
  final double end;
  double get length => end - start;

  @override
  String toString() =>
      '${start.toStringAsFixed(2)} s to ${end.toStringAsFixed(2)} s '
      '(${length.toStringAsFixed(2)} s)';
}

/// How much of the picture moves from frame [n] - 1 to frame [n]: the sum of
/// the differences of at least 2, so that the video's own noise does not count.
int pictureMotion(List<Uint8List> frames, int n) {
  final a = frames[n - 1];
  final b = frames[n];
  var sum = 0;
  for (var i = 0; i < a.length; i++) {
    final d = (a[i] - b[i]).abs();
    if (d >= 2) sum += d;
  }
  return sum;
}

/// A picture that moves less than this, from one frame to the next, is not
/// moving. Compression noise on a still picture moves a few units. The
/// equaliser of the mini player, the smallest thing that moves in the app
/// while it plays, moves 10 to 60 on the small gray picture. So a film that
/// plays, even with only the equaliser going, is not frozen, and a film
/// stopped on one frame is.
const stillBelow = 10;

/// Each stretch longer than [longer] seconds in which the picture does not
/// move: every frame of it is the same as the one before.
List<Stretch> frozenStretches(
  List<Uint8List> frames,
  int fps, {
  double longer = 0.8,
}) {
  final found = <Stretch>[];
  var run = 0; // frames in a row that match the one before
  void close(int endFrame) {
    // The first frame of the run is the one the others match: the picture
    // stands still for run + 1 frames.
    final length = (run + 1) / fps;
    if (length > longer) {
      found.add(Stretch((endFrame - run - 1) / fps, endFrame / fps));
    }
    run = 0;
  }

  for (var n = 1; n < frames.length; n++) {
    if (pictureMotion(frames, n) < stillBelow) {
      run++;
    } else if (run > 0) {
      close(n);
    }
  }
  if (run > 0) close(frames.length);
  return found;
}

/// Each stretch longer than [longer] seconds in which the level of [sound] is
/// under [below] dBFS.
List<Stretch> silentStretches(
  Sound sound, {
  double longer = 0.8,
  double below = -50,
}) {
  const hop = 0.005;
  final env = sound.levels(hop: hop);
  final found = <Stretch>[];
  var from = -1;
  void close(int to) {
    final length = (to - from) * hop;
    if (length > longer) {
      found.add(Stretch(from * hop + sound.offset, to * hop + sound.offset));
    }
    from = -1;
  }

  for (var i = 0; i < env.length; i++) {
    if (env[i] < below) {
      if (from < 0) from = i;
    } else if (from >= 0) {
      close(i);
    }
  }
  if (from >= 0) close(env.length);
  return found;
}

/// The sample rate of the sound that is measured. A multiple of 1 / 0.005, so
/// a hop of 5 ms is a whole number of samples and times do not drift.
const soundRate = 20000;

/// Sound read from a file: mono, at [soundRate], with its level over time.
class Sound {
  Sound(this.samples, this.rate, this.offset);
  final Int16List samples;
  final int rate;

  /// See [VideoInfo.audioOffset].
  final double offset;

  /// The level in dBFS of each [hop] seconds, from a window of [window]
  /// seconds that starts there. Index i is at i * hop + [offset] in the film.
  List<double> levels({double hop = 0.005, double window = 0.010}) {
    final step = (hop * rate).round();
    final w = (window * rate).round();
    assert((step / rate - hop).abs() < 1e-9, 'a hop must be whole samples');
    final out = <double>[];
    for (var i = 0; i + w <= samples.length; i += step) {
      var acc = 0.0;
      for (var j = i; j < i + w; j++) {
        final s = samples[j] / 32768.0;
        acc += s * s;
      }
      out.add(10 * math.log(acc / w + 1e-12) / math.ln10);
    }
    return out;
  }
}

Future<Sound> readSound(String path, {List<String> inputArgs = const []}) async {
  final tmp = Directory.systemTemp.createTempSync('film_sound');
  try {
    await run('ffmpeg', [
      '-hide_banner', '-loglevel', 'error', '-y', ...inputArgs, '-i', path,
      '-vn', '-ac', '1', '-ar', '$soundRate', '-f', 's16le', '${tmp.path}/a.pcm',
    ]);
    final bytes = File('${tmp.path}/a.pcm').readAsBytesSync();
    final samples = Int16List.view(
      bytes.buffer,
      bytes.offsetInBytes,
      bytes.length ~/ 2,
    );
    final offset = inputArgs.isEmpty ? (await probeVideo(path)).audioOffset : 0.0;
    return Sound(Int16List.fromList(samples), soundRate, offset);
  } finally {
    tmp.deleteSync(recursive: true);
  }
}

/// The time at which the sound of a chapter starts, searched for from [tap]
/// to [tap] + [within]. Null when there is none.
///
/// The sound starts where the level rises through a threshold, from below it,
/// and stays above it for [hold] seconds. The click at a tap, and the end of
/// the sound that the tap stopped, are shorter than [hold]. The threshold is
/// [below] dB under the level the sound has over the second that starts
/// [steadyAt] seconds after [expected].
double? audioOnset(
  Sound sound, {
  required double tap,
  required double expected,
  double within = 2.0,
  double hold = 0.15,
  double below = 30,
  double steadyAt = 0.3,
}) {
  const hop = 0.005;
  final env = sound.levels(hop: hop);
  int at(double t) => ((t - sound.offset) / hop).round().clamp(0, env.length - 1);
  final steady = <double>[
    for (var i = at(expected + steadyAt); i <= at(expected + steadyAt + 1.0); i++)
      env[i],
  ]..sort();
  final threshold = steady[steady.length ~/ 2] - below;
  final need = (hold / hop).round();
  for (var i = math.max(1, at(tap - 0.02)); i <= at(tap + within); i++) {
    if (env[i] < threshold || env[i - 1] >= threshold) continue;
    var ok = true;
    for (var j = i; j < i + need && j < env.length; j++) {
      if (env[j] < threshold) {
        ok = false;
        break;
      }
    }
    if (ok) return i * hop + sound.offset + 0.003;
  }
  return null;
}

Future<void> run(String exe, List<String> args) async {
  final proc = await Process.start('taskpolicy', ['-b', exe, ...args],
      mode: ProcessStartMode.inheritStdio);
  final code = await proc.exitCode;
  if (code != 0) fail('$exe failed with exit code $code.');
}

Never fail(String message) {
  stderr.writeln(message);
  exit(1);
}
