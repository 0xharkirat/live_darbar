import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:live_darbar/src/models/capped_download.dart';

final _start = Uri.parse('https://example.org/hukamnama.pdf');

http.StreamedResponse _ok(List<int> body, {int? declaredLength}) {
  return http.StreamedResponse(
    Stream.value(body),
    200,
    contentLength: declaredLength ?? body.length,
  );
}

http.StreamedResponse _redirect(String? location, {int status = 302}) {
  return http.StreamedResponse(
    const Stream.empty(),
    status,
    headers: {if (location != null) 'location': location},
    isRedirect: true,
  );
}

/// Answers each request in turn from [responses] and records what was asked.
class _Script {
  _Script(this.responses);

  final List<FutureOr<http.StreamedResponse> Function(http.BaseRequest)>
      responses;
  final requests = <http.BaseRequest>[];

  List<Uri> get requested => [for (final r in requests) r.url];
  List<bool> get followed => [for (final r in requests) r.followRedirects];

  MockClient get client => MockClient.streaming((request, _) async {
        requests.add(request);
        return responses[requests.length - 1](request);
      });
}

/// Whether the request's abort trigger has fired, after letting events settle.
Future<bool> _aborted(http.BaseRequest request) async {
  var fired = false;
  (request as http.AbortableRequest).abortTrigger!.whenComplete(() {
    fired = true;
  });
  await Future<void>.delayed(const Duration(milliseconds: 20));
  return fired;
}

void main() {
  test('the default cap is 5 MB', () {
    expect(kMaxPdfBytes, 5 * 1024 * 1024);
  });

  group('downloadCapped body', () {
    test('returns the bytes of a small 200', () async {
      final script = _Script([(_) => _ok([1, 2, 3])]);

      final bytes = await downloadCapped(script.client, _start);

      expect(bytes, Uint8List.fromList([1, 2, 3]));
    });

    test('joins a body that arrives in chunks', () async {
      final script = _Script([
        (_) => http.StreamedResponse(
              Stream.fromIterable([
                [1, 2],
                [3],
                [4, 5],
              ]),
              200,
            ),
      ]);

      expect(
        await downloadCapped(script.client, _start),
        Uint8List.fromList([1, 2, 3, 4, 5]),
      );
    });

    test('returns null for a status other than 200', () async {
      for (final status in [204, 304, 404, 500]) {
        final script = _Script([
          (_) => http.StreamedResponse(Stream.value([1]), status),
        ]);
        expect(await downloadCapped(script.client, _start), isNull,
            reason: 'status $status');
      }
    });

    test('accepts a body that is exactly the cap', () async {
      final script = _Script([(_) => _ok(List.filled(10, 7))]);

      final bytes = await downloadCapped(script.client, _start, maxBytes: 10);

      expect(bytes, hasLength(10));
    });

    test('refuses a Content-Length over the cap without reading the body',
        () async {
      var chunksRead = 0;
      Stream<List<int>> body() async* {
        chunksRead++;
        yield Uint8List(1024);
      }

      final script = _Script([
        (_) => http.StreamedResponse(body(), 200, contentLength: 11),
      ]);

      await expectLater(
        downloadCapped(script.client, _start, maxBytes: 10),
        throwsA(isA<DownloadRefused>()),
      );
      // Cancelled before the first chunk, not drained and measured after.
      expect(chunksRead, lessThanOrEqualTo(1));
    });

    test('refuses a body over the cap when no length was declared', () async {
      final script = _Script([
        (_) => http.StreamedResponse(
              Stream.value(Uint8List(11)),
              200,
            ),
      ]);

      await expectLater(
        downloadCapped(script.client, _start, maxBytes: 10),
        throwsA(isA<DownloadRefused>()),
      );
    });

    test('refuses a body that outgrows a small declared length', () async {
      final script = _Script([(_) => _ok(Uint8List(100), declaredLength: 5)]);

      await expectLater(
        downloadCapped(script.client, _start, maxBytes: 10),
        throwsA(isA<DownloadRefused>()),
      );
    });

    test('stops reading an endless body soon after the cap', () async {
      var sent = 0;
      var cancelled = false;
      Stream<List<int>> endless() async* {
        try {
          while (true) {
            sent++;
            yield Uint8List(1024);
          }
        } finally {
          cancelled = true;
        }
      }

      final script = _Script([(_) => http.StreamedResponse(endless(), 200)]);

      await expectLater(
        downloadCapped(script.client, _start, maxBytes: 4096),
        throwsA(isA<DownloadRefused>()),
      );
      expect(cancelled, isTrue, reason: 'the transfer should be abandoned');
      expect(sent, lessThan(10));
    });
  });

  group('downloadCapped redirects', () {
    test('asks the client not to follow redirects itself', () async {
      final script = _Script([(_) => _ok([1])]);

      await downloadCapped(script.client, _start);

      expect(script.followed, [false]);
    });

    test('follows an absolute https redirect', () async {
      final script = _Script([
        (_) => _redirect('https://cdn.example.org/real.pdf'),
        (_) => _ok([9, 9]),
      ]);

      final bytes = await downloadCapped(script.client, _start);

      expect(bytes, Uint8List.fromList([9, 9]));
      expect(script.requested.last, Uri.parse('https://cdn.example.org/real.pdf'));
    });

    test('follows a relative redirect against the current url', () async {
      final script = _Script([
        (_) => _redirect('/files/today.pdf', status: 301),
        (_) => _ok([4]),
      ]);

      await downloadCapped(script.client, _start);

      expect(script.requested.last, Uri.parse('https://example.org/files/today.pdf'));
    });

    test('follows every redirect status', () async {
      for (final status in [301, 302, 303, 307, 308]) {
        final script = _Script([
          (_) => _redirect('https://example.org/b.pdf', status: status),
          (_) => _ok([1]),
        ]);
        expect(await downloadCapped(script.client, _start), isNotNull,
            reason: 'status $status');
      }
    });

    test('refuses a redirect to plain http and never requests it', () async {
      final script = _Script([
        (_) => _redirect('http://example.org/real.pdf'),
        (_) => _ok([1]),
      ]);

      await expectLater(
        downloadCapped(script.client, _start),
        throwsA(isA<DownloadRefused>()),
      );
      expect(script.requested, [_start]);
    });

    test('refuses a redirect to another scheme', () async {
      for (final location in [
        'file:///etc/passwd',
        'ftp://example.org/a.pdf',
        'data:application/pdf;base64,JVBERg==',
      ]) {
        final script = _Script([(_) => _redirect(location)]);
        await expectLater(
          downloadCapped(script.client, _start),
          throwsA(isA<DownloadRefused>()),
          reason: location,
        );
        expect(script.requested, hasLength(1), reason: location);
      }
    });

    test('refuses a downgrade that comes after an allowed hop', () async {
      final script = _Script([
        (_) => _redirect('https://example.org/b.pdf'),
        (_) => _redirect('http://example.org/c.pdf'),
      ]);

      await expectLater(
        downloadCapped(script.client, _start),
        throwsA(isA<DownloadRefused>()),
      );
      expect(script.requested, hasLength(2));
    });

    test('refuses a redirect with no Location', () async {
      final script = _Script([(_) => _redirect(null)]);

      await expectLater(
        downloadCapped(script.client, _start),
        throwsA(isA<DownloadRefused>()),
      );
    });

    test('refuses a redirect with an unparseable Location', () async {
      final script = _Script([(_) => _redirect('http://[::1')]);

      await expectLater(
        downloadCapped(script.client, _start),
        throwsA(isA<DownloadRefused>()),
      );
    });

    test('gives up on a redirect loop', () async {
      final script = _Script(
        List.filled(10, (_) => _redirect('https://example.org/again')),
      );

      await expectLater(
        downloadCapped(script.client, _start, maxRedirects: 3),
        throwsA(isA<DownloadRefused>()),
      );
      // The original request plus three hops.
      expect(script.requested, hasLength(4));
    });

    test('refuses a plain http starting url without a request', () async {
      final script = _Script([(_) => _ok([1])]);

      await expectLater(
        downloadCapped(script.client, Uri.parse('http://example.org/a.pdf')),
        throwsA(isA<DownloadRefused>()),
      );
      expect(script.requested, isEmpty);
    });
  });

  group('downloadCapped timeouts', () {
    const idle = Duration(milliseconds: 100);

    test('gives up on a body that stops arriving, and cancels it', () async {
      var cancelled = false;
      final body = StreamController<List<int>>(onCancel: () => cancelled = true)
        ..add([1, 2, 3]);
      final script = _Script([(_) => http.StreamedResponse(body.stream, 200)]);

      await expectLater(
        downloadCapped(script.client, _start, idleTimeout: idle),
        throwsA(isA<DownloadRefused>()),
      );

      expect(cancelled, isTrue, reason: 'the subscription should be cancelled');
      expect(await _aborted(script.requests.single), isTrue,
          reason: 'the request should be aborted so the socket closes');
    });

    test('gives up when the response headers never arrive', () async {
      final script = _Script([
        (_) => Completer<http.StreamedResponse>().future,
      ]);

      await expectLater(
        downloadCapped(script.client, _start, idleTimeout: idle),
        throwsA(isA<DownloadRefused>()),
      );

      expect(await _aborted(script.requests.single), isTrue);
    });

    test('a slow trickle is cut off by the overall deadline', () async {
      // One byte every 30 ms never trips a 100 ms idle timeout, which is the
      // point: only the deadline stops this one.
      var cancelled = false;
      late Timer ticker;
      final body = StreamController<List<int>>(onCancel: () {
        cancelled = true;
        ticker.cancel();
      });
      ticker = Timer.periodic(
        const Duration(milliseconds: 30),
        (_) => body.add([1]),
      );
      final script = _Script([(_) => http.StreamedResponse(body.stream, 200)]);

      final watch = Stopwatch()..start();
      await expectLater(
        downloadCapped(
          script.client,
          _start,
          idleTimeout: idle,
          deadline: const Duration(milliseconds: 250),
        ),
        throwsA(isA<DownloadRefused>()),
      );

      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
      expect(cancelled, isTrue);
      expect(await _aborted(script.requests.single), isTrue);
    });

    test('the deadline covers every redirect hop together', () async {
      Future<http.StreamedResponse> slowRedirect(http.BaseRequest _) async {
        await Future<void>.delayed(const Duration(milliseconds: 120));
        return _redirect('https://example.org/next');
      }

      final script = _Script([slowRedirect, slowRedirect, slowRedirect]);

      await expectLater(
        downloadCapped(
          script.client,
          _start,
          idleTimeout: const Duration(seconds: 5),
          deadline: const Duration(milliseconds: 200),
        ),
        throwsA(isA<DownloadRefused>()),
      );

      // Cut off during the second hop, not after all of them.
      expect(script.requests.length, lessThan(3));
    });

    test('the deadline cuts off a header wait that the idle limit allows',
        () async {
      final script = _Script([
        (_) => Completer<http.StreamedResponse>().future,
      ]);

      final watch = Stopwatch()..start();
      await expectLater(
        downloadCapped(
          script.client,
          _start,
          idleTimeout: const Duration(seconds: 30),
          deadline: const Duration(milliseconds: 100),
        ),
        throwsA(isA<DownloadRefused>()),
      );

      expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
    });

    test('a body that keeps arriving within both limits succeeds', () async {
      final script = _Script([
        (_) => http.StreamedResponse(
              Stream.periodic(
                const Duration(milliseconds: 20),
                (_) => [1, 2],
              ).take(4),
              200,
            ),
      ]);

      final bytes = await downloadCapped(
        script.client,
        _start,
        idleTimeout: idle,
        deadline: const Duration(seconds: 5),
      );

      expect(bytes, hasLength(8));
    });

    test('a clean download does not abort the request', () async {
      // Aborting would close a connection that could have been reused.
      final script = _Script([(_) => _ok([1, 2, 3])]);

      await downloadCapped(script.client, _start);

      expect(await _aborted(script.requests.single), isFalse);
    });

    test('a status other than 200 does not abort the request either',
        () async {
      final script = _Script([
        (_) => http.StreamedResponse(Stream.value([1]), 404),
      ]);

      expect(await downloadCapped(script.client, _start), isNull);
      expect(await _aborted(script.requests.single), isFalse);
    });

    test('a refusal aborts the request', () async {
      final script = _Script([(_) => _ok(Uint8List(100), declaredLength: 5)]);

      await expectLater(
        downloadCapped(script.client, _start, maxBytes: 10),
        throwsA(isA<DownloadRefused>()),
      );

      expect(await _aborted(script.requests.single), isTrue);
    });
  });
}
