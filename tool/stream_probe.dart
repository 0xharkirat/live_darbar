// Breaks down where the time goes when the app opens an audio endpoint:
// DNS, TCP, TLS, request, response headers, first body byte, and then how long
// until enough audio has arrived for a player to start decoding.
//
// Run it from the project root:
//
//   dart run tool/stream_probe.dart              # every endpoint
//   dart run tool/stream_probe.dart live         # only endpoints matching "live"
//   dart run tool/stream_probe.dart --runs=5
//
// This uses dart:io sockets directly rather than package:http so the timings
// are not hidden behind a client that pools connections. Note the caveat: on
// Android the audio itself is fetched by ExoPlayer, which is native code with
// its own networking, so treat these numbers as the shape of the problem
// rather than as ExoPlayer's exact behaviour. For the Mukhwak PDF, which the
// app really does fetch with package:http, they are exact.

import 'dart:async';
import 'dart:io';

/// Bytes of body to wait for at each checkpoint.
///
/// A 96 kbps stream carries 12 KB per second of audio, so 32 KB is roughly
/// 2.7 seconds of listening. ExoPlayer's default is to hold 2.5 seconds before
/// it starts, which puts the 32 KB mark close to the moment sound comes out.
const _marks = <int>[16 * 1024, 32 * 1024, 64 * 1024, 128 * 1024];

const _readDeadline = Duration(seconds: 30);

const _endpoints = <String, String>{
  'live 96k cleartext': 'http://live.sgpc.net:7339/;',
  'live 28k tls': 'https://live.sgpc.net:8442/;',
  'hukamnama mp3': 'https://hs.sgpc.net/uploadhukamnama/hukamnama.mp3',
  'katha mp3': 'https://hs.sgpc.net/uploadkatha/katha.mp3',
  'hukamnama pdf': 'https://hs.sgpc.net/hukamnamapdf.php',
};

/// Cumulative milliseconds from the start of the attempt, keyed by phase.
typedef Timings = Map<String, int>;

class ProbeResult {
  ProbeResult(this.timings, this.headers, this.status);

  final Timings timings;
  final Map<String, String> headers;
  final String status;
}

Future<ProbeResult> probe(Uri url) async {
  final https = url.scheme == 'https';
  final port = url.hasPort ? url.port : (https ? 443 : 80);
  final path = url.path.isEmpty ? '/' : url.path;
  final target = url.hasQuery ? '$path?${url.query}' : path;

  final watch = Stopwatch()..start();
  final timings = <String, int>{};
  void mark(String phase) => timings[phase] = watch.elapsedMilliseconds;

  await InternetAddress.lookup(url.host, type: InternetAddressType.IPv4);
  mark('dns');

  Socket socket = await Socket.connect(url.host, port);
  mark('tcp');

  if (https) {
    socket = await SecureSocket.secure(socket, host: url.host);
  }
  mark('tls');

  socket.write(
    'GET $target HTTP/1.1\r\n'
    'Host: ${url.host}:$port\r\n'
    'User-Agent: live-darbar-probe/1\r\n'
    'Icy-MetaData: 1\r\n'
    'Accept: */*\r\n'
    'Connection: close\r\n\r\n',
  );
  await socket.flush();
  mark('request');

  // Walk the byte stream once, marking each checkpoint as it is passed. The
  // header/body split has to be found by hand because we are below the level
  // of HttpClient on purpose.
  final headerBytes = <int>[];
  var headersDone = false;
  var bodyBytes = 0;
  var nextMark = 0;
  final done = Completer<void>();

  final sub = socket.listen(
    (chunk) {
      var offset = 0;
      if (!headersDone) {
        headerBytes.addAll(chunk);
        final split = _findHeaderEnd(headerBytes);
        if (split == -1) return;
        headersDone = true;
        mark('headers');
        offset = chunk.length - (headerBytes.length - split);
      }
      final added = chunk.length - offset;
      if (added <= 0) return;
      if (bodyBytes == 0) mark('first_byte');
      bodyBytes += added;
      while (nextMark < _marks.length && bodyBytes >= _marks[nextMark]) {
        mark('${_marks[nextMark] ~/ 1024}k');
        nextMark++;
      }
      if (nextMark == _marks.length && !done.isCompleted) done.complete();
    },
    onDone: () => done.isCompleted ? null : done.complete(),
    onError: (Object e) => done.isCompleted ? null : done.completeError(e),
    cancelOnError: true,
  );

  try {
    await done.future.timeout(_readDeadline);
  } on TimeoutException {
    // A partial result is still a result: it tells us which checkpoint the
    // endpoint failed to reach.
  } finally {
    await sub.cancel();
    socket.destroy();
  }

  final split = _findHeaderEnd(headerBytes);
  final head = String.fromCharCodes(
    headerBytes.take(split == -1 ? headerBytes.length : split),
  );
  final lines = head.split('\r\n');
  final headers = <String, String>{};
  for (final line in lines.skip(1)) {
    final i = line.indexOf(':');
    if (i > 0) {
      headers[line.substring(0, i).trim().toLowerCase()] =
          line.substring(i + 1).trim();
    }
  }
  return ProbeResult(timings, headers, lines.isEmpty ? '' : lines.first);
}

/// Index just past the blank line that ends the HTTP headers, or -1.
int _findHeaderEnd(List<int> bytes) {
  for (var i = 3; i < bytes.length; i++) {
    if (bytes[i] == 10 &&
        bytes[i - 1] == 13 &&
        bytes[i - 2] == 10 &&
        bytes[i - 3] == 13) {
      return i + 1;
    }
  }
  return -1;
}

int _median(List<int> xs) {
  final s = [...xs]..sort();
  final mid = s.length ~/ 2;
  return s.length.isOdd ? s[mid] : ((s[mid - 1] + s[mid]) / 2).round();
}

Future<void> run(String label, String url, int runs) async {
  stdout.writeln('\n### $label\n$url');
  final results = <ProbeResult>[];
  for (var i = 0; i < runs; i++) {
    try {
      results.add(await probe(Uri.parse(url)));
    } catch (e) {
      stdout.writeln('  run ${i + 1}: FAILED ${e.runtimeType}: $e');
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  if (results.isEmpty) return;

  final last = results.last;
  stdout.writeln('  ${last.status}');
  for (final k in const [
    'content-type',
    'icy-br',
    'icy-name',
    'server',
    'last-modified',
    'content-length',
    'cache-control',
  ]) {
    final v = last.headers[k];
    if (v != null) stdout.writeln('  $k: $v');
  }

  final phases = <String>[
    'dns',
    'tcp',
    'tls',
    'request',
    'headers',
    'first_byte',
    for (final m in _marks) '${m ~/ 1024}k',
  ];
  stdout.writeln('  ${'phase'.padRight(12)}${'median ms'.padLeft(10)}'
      '${'min'.padLeft(9)}${'max'.padLeft(9)}   (cumulative)');
  for (final p in phases) {
    final vals = [
      for (final r in results)
        if (r.timings[p] != null) r.timings[p]!,
    ];
    if (vals.isEmpty) {
      stdout.writeln('  ${p.padRight(12)}${'never'.padLeft(10)}');
      continue;
    }
    stdout.writeln('  ${p.padRight(12)}'
        '${_median(vals).toString().padLeft(10)}'
        '${vals.reduce((a, b) => a < b ? a : b).toString().padLeft(9)}'
        '${vals.reduce((a, b) => a > b ? a : b).toString().padLeft(9)}');
  }
}

Future<void> main(List<String> args) async {
  var runs = 3;
  final filters = <String>[];
  for (final a in args) {
    if (a.startsWith('--runs=')) {
      runs = int.parse(a.substring(7));
    } else {
      filters.add(a);
    }
  }
  for (final entry in _endpoints.entries) {
    if (filters.isNotEmpty && !filters.any(entry.key.contains)) continue;
    await run(entry.key, entry.value, runs);
  }
}
