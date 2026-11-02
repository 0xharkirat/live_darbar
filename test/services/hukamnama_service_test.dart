import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:live_darbar/src/services/hukamnama_service.dart';

/// A real response for 2 November 2026, as received and not edited.
final _recorded =
    File('test/fixtures/sgpc_hukamnama_2026_11_02.json').readAsBytesSync();

/// SGPC's real answer for a day it has no Hukamnama for: 3 November 2026
/// asked on the morning of the 2nd. Tomorrow, `garbage`, `2026-13-45`, an
/// empty string and 2002-01-01 all got this same answer, with their own text
/// in the date.
final _notPublished = utf8.encode(
  '{"supported":false,"hukamnama":{"date":"2026-11-03","message":'
  '"No Hukamnama Available for this date."},"pdfFiles":[]}',
);

/// An answer that is not a Hukamnama and not the plain "not posted yet" either.
/// The first must never be stored, and the second must not be mistaken for it.
final throwsUnusableAnswer = throwsA(allOf(
  isA<HukamnamaException>(),
  isNot(isA<HukamnamaNotPublishedException>()),
));

HukamnamaService serviceWith(
  Future<http.Response> Function(http.Request) handler, {
  Duration timeout = const Duration(seconds: 8),
  bool isWeb = false,
  String mirrorUrl = kHukamnamaMirrorUrl,
}) {
  final service = HukamnamaService(
    client: MockClient(handler),
    timeout: timeout,
    isWeb: isWeb,
    mirrorUrl: mirrorUrl,
  );
  addTearDown(service.close);
  return service;
}

/// The recorded body with one field of its Hukamnama replaced.
List<int> recordedWith(String field, Object? value) {
  final json = jsonDecode(utf8.decode(_recorded)) as Map<String, dynamic>;
  (json['hukamnama'] as Map<String, dynamic>)[field] = value;
  return utf8.encode(jsonEncode(json));
}

void main() {
  final nov2 = DateTime.utc(2026, 11, 2);

  group('HukamnamaService.fetch', () {
    test('posts the SGPC day to the archive over HTTPS, as a page would',
        () async {
      late http.Request seen;
      final service = serviceWith((request) async {
        seen = request;
        return http.Response.bytes(_recorded, 200);
      });

      await service.fetch(nov2);

      expect(seen.method, 'POST');
      expect(seen.url.toString(),
          'https://hs.sgpc.net/hssearchhukmanamaTestCalender.php');
      expect(seen.url.scheme, 'https');
      expect(seen.bodyFields, {'selected_date': '2026-11-02'});
      expect(seen.headers['Content-Type'],
          startsWith('application/x-www-form-urlencoded'));
      // Without this header SGPC answers 200 with an empty body.
      expect(seen.headers['X-Requested-With'], 'XMLHttpRequest');
    });

    test('pads the month and the day, and ignores the time and zone', () async {
      late http.Request seen;
      final service = serviceWith((request) async {
        seen = request;
        return http.Response.bytes(_notPublished, 200);
      });
      await expectLater(service.fetch(DateTime(2027, 3, 5, 23, 59)),
          throwsA(isA<HukamnamaNotPublishedException>()));
      expect(seen.bodyFields, {'selected_date': '2027-03-05'});
    });

    test('parses the recorded response, bytes and all', () async {
      final service =
          serviceWith((_) async => http.Response.bytes(_recorded, 200));
      final h = await service.fetch(nov2);
      expect(h.date, nov2);
      expect(h.ang, 668);
      expect(h.lines, hasLength(10));
      // Gurmukhi survives the trip with no charset header on the response.
      expect(h.lines[1].gurmukhi, startsWith('ਹਰਿ ਹਰਿ ਕ੍ਰਿਪਾ ਕਰਹੁ'));
    });

    test('reports a day SGPC has not posted as not published', () async {
      final service =
          serviceWith((_) async => http.Response.bytes(_notPublished, 200));
      expect(
        service.fetch(DateTime.utc(2026, 11, 3)),
        throwsA(isA<HukamnamaNotPublishedException>()
            .having((e) => e.day, 'day', DateTime.utc(2026, 11, 3))),
      );
    });

    test('does not store a response with no Gurmukhi', () async {
      for (final body in [
        recordedWith('ghukamnama', ''),
        recordedWith('ghukamnama', null),
      ]) {
        final service =
            serviceWith((_) async => http.Response.bytes(body, 200));
        await expectLater(service.fetch(nov2), throwsUnusableAnswer);
      }
    });

    test('does not store a response whose date is missing or not a day',
        () async {
      for (final date in [null, '', 'garbage', '2026-13-45']) {
        final service = serviceWith(
            (_) async => http.Response.bytes(recordedWith('date', date), 200));
        await expectLater(
            service.fetch(nov2), throwsA(isA<HukamnamaException>()),
            reason: 'date: $date');
      }
    });

    test('is not fooled into labelling another day as the one asked for',
        () async {
      // SGPC answers 2 November to a request for 3 November.
      final service =
          serviceWith((_) async => http.Response.bytes(_recorded, 200));
      expect(
        service.fetch(DateTime.utc(2026, 11, 3)),
        throwsA(isA<HukamnamaException>()
            .having((e) => e.message, 'message', contains('2026-11-03'))),
      );
    });

    test('turns the empty 200 SGPC gives without its header into an exception',
        () async {
      final service = serviceWith((_) async => http.Response('', 200));
      await expectLater(service.fetch(nov2), throwsUnusableAnswer);
    });

    test('turns a server error into an exception', () async {
      final service = serviceWith((_) async => http.Response('oops', 503));
      expect(service.fetch(nov2), throwsA(isA<HukamnamaException>()));
    });

    test('turns a body that is not a Hukamnama into an exception', () async {
      for (final body in [
        '<html>captive portal</html>',
        '[]',
        '{}',
        '{"supported":true}',
        '{"hukamnama":{"date":"2026-11-02","ghukamnama":"ਸਲੋਕੁ ॥"}}',
        '',
      ]) {
        final service = serviceWith(
            (_) async => http.Response.bytes(utf8.encode(body), 200));
        await expectLater(service.fetch(nov2), throwsUnusableAnswer,
            reason: 'body: "$body"');
      }
    });

    test('gives up after the timeout instead of waiting forever', () async {
      final never = Completer<http.Response>();
      final service = serviceWith(
        (_) => never.future,
        timeout: const Duration(milliseconds: 50),
      );
      await expectLater(service.fetch(nov2), throwsA(isA<TimeoutException>()));
    });

    test('waits 8 seconds by default', () {
      final service = HukamnamaService(
          client: MockClient((_) async => http.Response('', 500)));
      addTearDown(service.close);
      expect(service.timeout, const Duration(seconds: 8));
    });

    test('lets a network failure through for the caller to handle', () async {
      final service = serviceWith(
          (_) async => throw const SocketException('Failed host lookup'));
      expect(service.fetch(nov2), throwsA(isA<SocketException>()));
    });
  });

  group('HukamnamaService on web', () {
    const mirror = 'https://mirror.test/data';

    /// A web service whose every request is recorded in [seen].
    HukamnamaService web(
      List<http.Request> seen,
      http.Response Function(http.Request request) answer, {
      String mirrorUrl = mirror,
    }) =>
        serviceWith(
          (request) async {
            seen.add(request);
            return answer(request);
          },
          isWeb: true,
          mirrorUrl: mirrorUrl,
        );

    /// SGPC's host must never be called from a browser: it would fail on CORS.
    void expectNeverSgpc(List<http.Request> seen) {
      expect(seen, isNotEmpty);
      expect(seen.map((r) => r.url.host), everyElement(isNot('hs.sgpc.net')));
    }

    test('reads the day\'s file from the mirror with a plain GET', () async {
      final seen = <http.Request>[];
      final service = web(seen, (_) => http.Response.bytes(_recorded, 200));

      final h = await service.fetch(nov2);

      expect(seen, hasLength(1));
      expect(seen.single.method, 'GET');
      expect(seen.single.url.toString(), '$mirror/hukamnama/2026-11-02.json');
      // No header of ours: a custom one makes the browser send a preflight.
      expect(seen.single.headers.keys.map((k) => k.toLowerCase()),
          isNot(contains('x-requested-with')));
      expectNeverSgpc(seen);

      // Parsed by the same code as the native answer.
      expect(h.date, nov2);
      expect(h.ang, 668);
      expect(h.lines, hasLength(10));
      expect(h.lines[1].gurmukhi, startsWith('ਹਰਿ ਹਰਿ ਕ੍ਰਿਪਾ ਕਰਹੁ'));
      expect(h.englishMeaning, isNotNull);
      expect(h.punjabiMeaning, isNotNull);
    });

    test('pads the month and the day, and ignores the time and zone', () async {
      final seen = <http.Request>[];
      final service = web(seen, (_) => http.Response('', 404));
      await expectLater(service.fetch(DateTime(2027, 3, 5, 23, 59)),
          throwsA(isA<HukamnamaNotPublishedException>()));
      expect(seen.single.url.path, '/data/hukamnama/2027-03-05.json');
    });

    test('ignores a slash at the end of the mirror address', () async {
      final seen = <http.Request>[];
      final service = web(seen, (_) => http.Response.bytes(_recorded, 200),
          mirrorUrl: '$mirror//');
      await service.fetch(nov2);
      expect(seen.single.url.toString(), '$mirror/hukamnama/2026-11-02.json');
    });

    test('reads the real default mirror address when none is given', () async {
      final seen = <http.Request>[];
      final service = HukamnamaService(
        client: MockClient((request) async {
          seen.add(request);
          return http.Response.bytes(_recorded, 200);
        }),
        isWeb: true,
      );
      addTearDown(service.close);

      await service.fetch(nov2);

      expect(
        seen.single.url.toString(),
        'https://raw.githubusercontent.com/0xharkirat/live_darbar/'
        'hukamnama-data/hukamnama/2026-11-02.json',
      );
    });

    test('a 404 means the day is not posted yet', () async {
      final seen = <http.Request>[];
      final service = web(seen, (_) => http.Response('404: Not Found', 404));
      await expectLater(
        service.fetch(DateTime.utc(2026, 11, 3)),
        throwsA(isA<HukamnamaNotPublishedException>()
            .having((e) => e.day, 'day', DateTime.utc(2026, 11, 3))),
      );
      expectNeverSgpc(seen);
    });

    test('any other status is a fault, not "not published"', () async {
      for (final status in [500, 502, 503, 429, 403, 301]) {
        final seen = <http.Request>[];
        final service = web(seen, (_) => http.Response('oops', status));
        await expectLater(
          service.fetch(nov2),
          throwsA(isA<HukamnamaException>()
              .having((e) => e, 'type',
                  isNot(isA<HukamnamaNotPublishedException>()))
              .having((e) => e.message, 'message',
                  allOf(contains('$status'), contains('mirror')))),
          reason: 'status $status',
        );
        expectNeverSgpc(seen);
      }
    });

    test('a body that is not JSON is a fault', () async {
      final seen = <http.Request>[];
      final service = web(seen, (_) => http.Response('<html>Hi</html>', 200));
      await expectLater(service.fetch(nov2), throwsUnusableAnswer);
      expectNeverSgpc(seen);
    });

    test('a file that is not a Hukamnama is a fault', () async {
      for (final body in ['', '[]', '{}', '{"supported":true}']) {
        final service = web([], (_) => http.Response(body, 200));
        await expectLater(service.fetch(nov2), throwsUnusableAnswer,
            reason: 'body: "$body"');
      }
    });

    test('is not fooled into labelling another day as the one asked for',
        () async {
      final service = web([], (_) => http.Response.bytes(_recorded, 200));
      await expectLater(
        service.fetch(DateTime.utc(2026, 11, 3)),
        throwsA(isA<HukamnamaException>()
            .having((e) => e.message, 'message', contains('2026-11-03'))),
      );
    });

    test('lets a network failure through for the caller to handle', () async {
      final service = serviceWith(
        (_) async => throw http.ClientException('Failed to fetch'),
        isWeb: true,
      );
      await expectLater(
          service.fetch(nov2), throwsA(isA<http.ClientException>()));
    });

    test('gives up after the timeout instead of waiting forever', () async {
      final never = Completer<http.Response>();
      final service = serviceWith(
        (_) => never.future,
        timeout: const Duration(milliseconds: 50),
        isWeb: true,
      );
      await expectLater(service.fetch(nov2), throwsA(isA<TimeoutException>()));
    });
  });

  group('HukamnamaService off the web', () {
    test('posts to SGPC and never touches the mirror', () async {
      final seen = <http.Request>[];
      final service = serviceWith(
        (request) async {
          seen.add(request);
          return http.Response.bytes(_recorded, 200);
        },
        mirrorUrl: 'https://mirror.test/data',
      );

      await service.fetch(nov2);

      expect(seen, hasLength(1));
      expect(seen.single.method, 'POST');
      expect(seen.single.url.host, 'hs.sgpc.net');
      expect(seen.single.bodyFields, {'selected_date': '2026-11-02'});
    });

    test(
        'treats a 404 as a fault, because only the mirror answers 404 for a '
        'day not posted', () async {
      final service = serviceWith((_) async => http.Response('', 404));
      await expectLater(service.fetch(nov2), throwsUnusableAnswer);
    });
  });
}
