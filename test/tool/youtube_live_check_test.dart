import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/youtube_live_check.dart';

/// The check that tells the app which of SGPC's YouTube streams are live.
///
/// The fixtures in test/fixtures/youtube are real pages from 7 November 2026,
/// 16:20 India time, cut down to the parts the check reads, with their real
/// shapes. Then the audio stream was live, and the midday kirtan had ended.
void main() {
  String page(String name) =>
      File('test/fixtures/youtube/$name.html').readAsStringSync();

  group('kindOf', () {
    test('reads the kind from SGPC\'s titles', () {
      expect(
        kindOf('Official SGPC LIVE (Audio) | Gurbani Kirtan | Sachkhand Sri '
            'Harmandir Sahib, Sri Amritsar 07.11.2026'),
        StreamKind.audio,
      );
      expect(
        kindOf('Hukamnama Katha (discourse) Gurdwara Sri Manji Sahib Diwan '
            'Hall, Sri Amritsar'),
        StreamKind.katha,
      );
      expect(
        kindOf('Official SGPC LIVE | Gurbani Kirtan | Sachkhand Sri Harmandir '
            'Sahib, Sri Amritsar 07.11.2026'),
        StreamKind.kirtan,
      );
    });

    test('matches whole words only', () {
      expect(kindOf('Audiovisual archive'), StreamKind.kirtan);
    });
  });

  group('the streams page', () {
    test('gives the streams it marks LIVE, and no ended one', () {
      expect(liveIdsOnStreamsPage(page('streams_page')), ['7M4WO8CokSA']);
    });

    test('is an error when it lists no streams, not "nothing is live"', () {
      expect(
        () => liveIdsOnStreamsPage(
            '<script>var ytInitialData = {"contents": {}};</script>'),
        throwsA(isA<PageError>()),
      );
      expect(
        () => liveIdsOnStreamsPage('<html>Before you continue</html>'),
        throwsA(isA<PageError>()),
      );
    });
  });

  group('the /live page', () {
    test('names the stream it shows', () {
      expect(idOnLivePage(page('live_page')), '7M4WO8CokSA');
    });

    test('names none when it shows the channel', () {
      expect(
        idOnLivePage('<link rel="canonical" '
            'href="https://www.youtube.com/channel/UCYn6UEtQ771a_OWSiNBoG8w">'),
        isNull,
      );
    });
  });

  group('a stream\'s own page', () {
    test('confirms a live stream on SGPC\'s channel, with its kind', () {
      final stream = checkWatchPage(page('watch_audio_page'), '7M4WO8CokSA')!;
      expect(stream.kind, StreamKind.audio);
      expect(stream.url, 'https://www.youtube.com/watch?v=7M4WO8CokSA');
      expect(stream.startedAt, DateTime.utc(2026, 11, 7, 8, 58, 59));
      expect(stream.title, startsWith('Official SGPC LIVE (Audio)'));
    });

    test('says an ended stream is not live', () {
      expect(checkWatchPage(page('watch_ended_page'), 'WIfllmGspFM'), isNull);
    });

    test('is an error when YouTube will not show the video', () {
      // A robot check answers with LOGIN_REQUIRED, for example.
      final blocked = page('watch_audio_page')
          .replaceFirst('"status":"OK"', '"status":"LOGIN_REQUIRED"');
      expect(() => checkWatchPage(blocked, '7M4WO8CokSA'),
          throwsA(isA<PageError>()));
    });

    test('is an error for another channel, or another video', () {
      final copy = page('watch_audio_page')
          .replaceAll('UCYn6UEtQ771a_OWSiNBoG8w', 'UCxxxxxxxxxxxxxxxxxxxxxx');
      expect(
          () => checkWatchPage(copy, '7M4WO8CokSA'), throwsA(isA<PageError>()));
      expect(() => checkWatchPage(page('watch_audio_page'), 'WIfllmGspFM'),
          throwsA(isA<PageError>()));
    });

    test('reads a title that holds the end of a JSON object', () {
      final odd = page('watch_audio_page').replaceFirst(
          '"title":"Official SGPC LIVE (Audio)', '"title":"Kirtan {x}; LIVE');
      expect(checkWatchPage(odd, '7M4WO8CokSA')!.kind, StreamKind.kirtan);
    });
  });

  group('live.json', () {
    LiveStream stream(String id, StreamKind kind) =>
        LiveStream(videoId: id, title: '$kind', kind: kind);

    test('puts kirtan first, then katha, then audio', () {
      final json = liveJson(
        [
          stream('AAAAAAAAAAA', StreamKind.audio),
          stream('BBBBBBBBBBB', StreamKind.katha),
          stream('CCCCCCCCCCC', StreamKind.kirtan),
        ],
        DateTime.utc(2026, 11, 7, 11, 31, 5, 123),
      );
      expect(json['checkedAt'], '2026-11-07T11:31:05Z');
      expect(json['channelId'], kSgpcChannelId);
      expect([for (final s in json['live']! as List) (s as Map)['kind']],
          ['kirtan', 'katha', 'audio']);
      expect((json['live']! as List).first,
          containsPair('url', 'https://www.youtube.com/watch?v=CCCCCCCCCCC'));
    });

    test('holds an empty list when nothing is live', () {
      expect(liveJson([], DateTime.utc(2026, 11, 7))['live'], isEmpty);
    });
  });

  group('events', () {
    final at = DateTime.utc(2026, 11, 7, 11, 30);
    final audio = LiveStream(
        videoId: '7M4WO8CokSA', title: 'Audio', kind: StreamKind.audio);
    final kirtan = LiveStream(
        videoId: 'CCCCCCCCCCC', title: 'Kirtan', kind: StreamKind.kirtan);

    test('records each stream that starts and ends', () {
      final before = liveJson([audio], at);
      final lines = events(before, [kirtan], at);
      expect(lines, hasLength(2));
      expect(lines[0], containsPair('event', 'start'));
      expect(lines[0], containsPair('videoId', 'CCCCCCCCCCC'));
      expect(lines[1], containsPair('event', 'end'));
      expect(lines[1], containsPair('videoId', '7M4WO8CokSA'));
      expect(lines[1], containsPair('kind', 'audio'));
    });

    test('records nothing when the same streams are live', () {
      expect(events(liveJson([audio], at), [audio], at), isEmpty);
    });

    test('records starts on the first run', () {
      expect(events(null, [audio], at).single, containsPair('event', 'start'));
    });
  });
}
