import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// The most a Mukhwak PDF may weigh. The real file is about 680 KB, so this
/// leaves room to grow while still stopping a hostile or broken server from
/// filling memory and then the documents directory.
const kMaxPdfBytes = 5 * 1024 * 1024;

/// A download that was stopped on purpose rather than one that failed.
///
/// Separate from a plain error so a caller can tell "the server said no" from
/// "the server tried something it should not have".
class DownloadRefused implements Exception {
  const DownloadRefused(this.reason);

  final String reason;

  @override
  String toString() => 'DownloadRefused: $reason';
}

const _redirectStatuses = {301, 302, 303, 307, 308};

/// How long [_release] waits for a cancelled subscription to finish closing.
const _cancelGrace = Duration(seconds: 2);

/// Fetches [url] with `GET`, holding the body in memory only up to [maxBytes].
///
/// Returns null when the server answers with anything other than 200, the
/// same as the code this replaces. Throws [DownloadRefused] when the download
/// breaks one of its rules:
///
/// * [url], or any redirect it leads to, is not https. Redirects are followed
///   by hand, one hop at a time, because the default would follow an
///   https-to-http downgrade without telling anyone.
/// * More than [maxRedirects] redirects in a row.
/// * The body is larger than [maxBytes]. This is checked against
///   `Content-Length` before reading, and again as the bytes arrive, because
///   a server can lie about the first or leave it out.
/// * Nothing arrives for [idleTimeout], whether that is the response headers
///   or the next chunk of the body.
/// * The whole thing, redirects included, runs past [deadline]. The idle
///   timeout alone would let a server that sends one byte every few seconds
///   hold the connection open for as long as the cap allows.
///
/// The body is streamed, so an oversized response is abandoned at the cap
/// rather than buffered whole and measured afterwards.
///
/// Every refusal also aborts the request, through its `abortTrigger`, so the
/// socket is closed rather than left reading in the background. A caller
/// should not wrap this in its own `Future.timeout`: that would abandon the
/// future while the transfer carried on. Pass [deadline] instead.
Future<Uint8List?> downloadCapped(
  http.Client client,
  Uri url, {
  int maxBytes = kMaxPdfBytes,
  int maxRedirects = 3,
  Duration idleTimeout = const Duration(seconds: 15),
  Duration deadline = const Duration(seconds: 60),
}) async {
  final clock = Stopwatch()..start();
  final abort = Completer<void>();
  var clean = false;

  // How long the next wait may last, and whether the deadline sets it.
  (Duration, bool) nextWait() {
    final left = deadline - clock.elapsed;
    if (left <= Duration.zero) throw _overDeadline;
    return left < idleTimeout ? (left, true) : (idleTimeout, false);
  }

  try {
    var target = url;

    for (var hop = 0; hop <= maxRedirects; hop++) {
      if (target.scheme != 'https') {
        throw DownloadRefused('refusing a non-https url: ${target.scheme}');
      }

      final request = http.AbortableRequest(
        'GET',
        target,
        abortTrigger: abort.future,
      )..followRedirects = false;

      final (headerWait, headerByDeadline) = nextWait();
      final http.StreamedResponse response;
      try {
        response = await client.send(request).timeout(headerWait);
      } on TimeoutException {
        throw headerByDeadline ? _overDeadline : _idle;
      }

      if (_redirectStatuses.contains(response.statusCode)) {
        await _discard(response);
        final location = response.headers['location'];
        final next = location == null ? null : Uri.tryParse(location);
        if (next == null) {
          throw const DownloadRefused('redirect without a usable location');
        }
        target = target.resolveUri(next);
        continue;
      }

      if (response.statusCode != 200) {
        await _discard(response);
        clean = true;
        return null;
      }

      final declared = response.contentLength;
      if (declared != null && declared > maxBytes) {
        await _discard(response);
        throw DownloadRefused('body of $declared bytes is over the cap');
      }

      final body = BytesBuilder(copy: false);
      final chunks = StreamIterator(response.stream);
      try {
        while (true) {
          final (wait, byDeadline) = nextWait();
          final bool more;
          try {
            more = await chunks.moveNext().timeout(wait);
          } on TimeoutException {
            throw byDeadline ? _overDeadline : _idle;
          }
          if (!more) break;

          body.add(chunks.current);
          if (body.length > maxBytes) {
            throw const DownloadRefused('body is over the cap');
          }
        }
        clean = true;
        return body.takeBytes();
      } finally {
        // Abort first, so the socket is closed even if cancelling the
        // subscription is slow to finish. Then cancel, which is what stops
        // the transfer on a client that does not honour the abort.
        if (!clean && !abort.isCompleted) abort.complete();
        await _release(chunks);
      }
    }

    throw const DownloadRefused('too many redirects');
  } finally {
    // Only on a refusal or failure. After a clean finish the connection is
    // done with and may be reused, and aborting would close it for nothing.
    if (!clean && !abort.isCompleted) abort.complete();
  }
}

const _idle = DownloadRefused('no data within the idle timeout');
const _overDeadline = DownloadRefused('ran past its deadline');

/// Gives up on a response without reading what it says.
Future<void> _discard(http.StreamedResponse response) =>
    response.stream.listen(null).cancel();

/// Cancels [chunks], without letting a slow close hold the caller up.
Future<void> _release(StreamIterator<List<int>> chunks) async {
  try {
    await chunks.cancel().timeout(_cancelGrace);
  } catch (_) {
    // Nothing useful to do: the abort has already gone out.
  }
}
