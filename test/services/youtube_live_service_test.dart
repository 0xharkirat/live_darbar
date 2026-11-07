import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:live_darbar/src/models/youtube_live_check.dart';
import 'package:live_darbar/src/services/youtube_live_service.dart';

/// The file the GitHub Action publishes, as the contract shows it.
const _file = '''
{"checkedAt":"2026-11-07T11:31:05Z","channelId":"UCYn6UEtQ771a_OWSiNBoG8w",
 "live":[{"videoId":"AbCdEfGhIjK","kind":"kirtan","title":"Official SGPC LIVE",
 "url":"https://www.youtube.com/watch?v=AbCdEfGhIjK",
 "startedAt":"2026-11-07T11:30:00Z"}]}
''';

/// The service reads the file and never throws: any fault is "no answer", and
/// the row then follows the timetable.
void main() {
  YoutubeLiveService serviceWith(
    Future<http.Response> Function(http.Request) handler, {
    Duration timeout = const Duration(seconds: 4),
  }) {
    final service = YoutubeLiveService(
      client: MockClient(handler),
      timeout: timeout,
    );
    addTearDown(service.close);
    return service;
  }

  test('the file is on the youtube-live branch of the repository', () {
    expect(
      kYoutubeLiveCheckUrl,
      'https://raw.githubusercontent.com/0xharkirat/live_darbar/'
      'youtube-live/live.json',
    );
  });

  test('asks for the file with a plain GET, and reads it', () async {
    http.Request? seen;
    final service = serviceWith((request) async {
      seen = request;
      return http.Response(_file, 200);
    });

    final check = await service.fetch();

    expect(seen!.method, 'GET');
    expect(seen!.url.toString(), kYoutubeLiveCheckUrl);
    // No custom header: a browser would then ask raw.githubusercontent.com
    // for a preflight answer first.
    expect(seen!.headers, isEmpty);
    expect(check, isNotNull);
    expect(check!.checkedAt, DateTime.utc(2026, 11, 7, 11, 31, 5));
    expect(check.video!.videoId, 'AbCdEfGhIjK');
  });

  test('reads the text as UTF-8, whatever the headers say', () async {
    final body = _file.replaceFirst('Official SGPC LIVE', 'ਸ੍ਰੀ ਦਰਬਾਰ ਸਾਹਿਬ');
    final service = serviceWith(
      (_) async => http.Response.bytes(
        utf8.encode(body),
        200,
        headers: {'content-type': 'text/plain'},
      ),
    );

    final check = await service.fetch();

    expect(check!.live.single.title, 'ਸ੍ਰੀ ਦਰਬਾਰ ਸਾਹਿਬ');
  });

  test('an empty list of streams is an answer', () async {
    final service = serviceWith(
      (_) async => http.Response(
        '{"checkedAt":"2026-11-07T11:31:05Z","live":[]}',
        200,
      ),
    );

    final check = await service.fetch();

    expect(check, isA<YoutubeLiveCheck>());
    expect(check!.live, isEmpty);
  });

  group('no answer', () {
    for (final status in [301, 400, 403, 404, 429, 500, 503]) {
      test('HTTP $status', () async {
        final service = serviceWith(
          // A good body under a bad status must not be trusted.
          (_) async => http.Response(_file, status),
        );

        expect(await service.fetch(), isNull);
      });
    }

    test('a body that is not the file', () async {
      final service = serviceWith((_) async => http.Response('oops', 200));

      expect(await service.fetch(), isNull);
    });

    test('a body that is not UTF-8', () async {
      final service = serviceWith(
        (_) async => http.Response.bytes([0xff, 0xfe, 0x00], 200),
      );

      expect(await service.fetch(), isNull);
    });

    test('a phone that is offline', () async {
      final service = serviceWith(
        (_) async => throw http.ClientException('Failed host lookup'),
      );

      expect(await service.fetch(), isNull);
    });

    test('any other error from the client', () async {
      final service = serviceWith((_) async => throw StateError('boom'));

      expect(await service.fetch(), isNull);
    });

    test('a server that does not answer in time', () async {
      final never = Completer<http.Response>();
      final service = serviceWith(
        (_) => never.future,
        timeout: const Duration(milliseconds: 20),
      );

      expect(await service.fetch(), isNull);
    });
  });
}
