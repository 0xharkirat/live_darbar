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
}) {
  final service = HukamnamaService(
    client: MockClient(handler),
    timeout: timeout,
    isWeb: isWeb,
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

    test('pads the month and the day, and ignores the time and zone',
        () async {
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
        final service = serviceWith((_) async => http.Response.bytes(body, 200));
        await expectLater(service.fetch(nov2), throwsUnusableAnswer);
      }
    });

    test('does not store a response whose date is missing or not a day',
        () async {
      for (final date in [null, '', 'garbage', '2026-13-45']) {
        final service = serviceWith(
            (_) async => http.Response.bytes(recordedWith('date', date), 200));
        await expectLater(service.fetch(nov2), throwsA(isA<HukamnamaException>()),
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
    test('fails at once with a clear exception and sends nothing', () async {
      var calls = 0;
      final service = serviceWith((_) async {
        calls++;
        return http.Response.bytes(_recorded, 200);
      }, isWeb: true);

      expect(service.isSupported, isFalse);
      await expectLater(
        service.fetch(nov2),
        throwsA(isA<HukamnamaWebUnsupportedException>()
            .having((e) => e.message, 'message', contains('web page'))),
      );
      expect(calls, 0);
    });

    test('is a HukamnamaException, so a catch for the family sees it', () {
      expect(const HukamnamaWebUnsupportedException(),
          isA<HukamnamaException>());
    });

    test('is supported everywhere else', () {
      final service = serviceWith((_) async => http.Response('', 500));
      expect(service.isSupported, isTrue);
    });
  });
}
