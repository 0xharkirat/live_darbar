import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/models/youtube_live_check.dart';

/// The file a GitHub Action publishes every 5 minutes on the `youtube-live`
/// branch: which SGPC streams are on YouTube now. The app reads it and must
/// never crash on it, so a file it cannot read is "no answer".
const _contract = '''
{
  "checkedAt": "2026-11-07T11:31:05Z",
  "channelId": "UCYn6UEtQ771a_OWSiNBoG8w",
  "live": [
    {"videoId": "AbCdEfGhIjK", "kind": "kirtan", "title": "Official SGPC LIVE | Gurbani Kirtan | ...", "url": "https://www.youtube.com/watch?v=AbCdEfGhIjK", "startedAt": "2026-11-07T11:30:00Z"},
    {"videoId": "7M4WO8CokSA", "kind": "audio", "title": "Official SGPC LIVE (Audio) | ...", "url": "https://www.youtube.com/watch?v=7M4WO8CokSA"}
  ]
}
''';

/// The contract file with [change] applied to its decoded map.
String _edited(void Function(Map<String, dynamic> file) change) {
  final file = jsonDecode(_contract) as Map<String, dynamic>;
  change(file);
  return jsonEncode(file);
}

/// The contract file with [change] applied to its first entry.
String _withEntry(void Function(Map<String, dynamic> entry) change) {
  return _edited((file) {
    final entry = (file['live'] as List).first as Map<String, dynamic>;
    change(entry);
  });
}

YoutubeStream _stream(YoutubeStreamKind kind, String id) => YoutubeStream(
      videoId: id,
      kind: kind,
      title: '',
      url: 'https://www.youtube.com/watch?v=$id',
    );

void main() {
  group('YoutubeLiveCheck.tryParse', () {
    test('reads the published file', () {
      final check = YoutubeLiveCheck.tryParse(_contract)!;

      expect(check.checkedAt, DateTime.utc(2026, 11, 7, 11, 31, 5));
      expect(check.checkedAt.isUtc, isTrue);
      expect(check.channelId, 'UCYn6UEtQ771a_OWSiNBoG8w');
      expect(check.live, hasLength(2));

      final kirtan = check.live.first;
      expect(kirtan.videoId, 'AbCdEfGhIjK');
      expect(kirtan.kind, YoutubeStreamKind.kirtan);
      expect(kirtan.title, startsWith('Official SGPC LIVE | Gurbani Kirtan'));
      expect(kirtan.url, 'https://www.youtube.com/watch?v=AbCdEfGhIjK');
      expect(kirtan.startedAt, DateTime.utc(2026, 11, 7, 11, 30));

      final audio = check.live.last;
      expect(audio.kind, YoutubeStreamKind.audio);
      expect(audio.startedAt, isNull, reason: 'startedAt can be absent');
    });

    test('an empty live list is an answer: nothing is on', () {
      final check = YoutubeLiveCheck.tryParse(
        _edited((file) => file['live'] = <Object>[]),
      );

      expect(check, isNotNull);
      expect(check!.live, isEmpty);
    });

    test('keeps working when the file grows a field it does not know', () {
      final check = YoutubeLiveCheck.tryParse(
        _edited((file) {
          file['schema'] = 2;
          ((file['live'] as List).first as Map)['viewers'] = 1200;
        }),
      );

      expect(check!.live.first.videoId, 'AbCdEfGhIjK');
    });

    test('takes an offset time and turns it into UTC', () {
      final check = YoutubeLiveCheck.tryParse(
        _edited((file) => file['checkedAt'] = '2026-11-07T17:01:05+05:30'),
      );

      expect(check!.checkedAt, DateTime.utc(2026, 11, 7, 11, 31, 5));
    });

    test('a start time it cannot read is dropped, and the entry stays', () {
      final check = YoutubeLiveCheck.tryParse(
        _withEntry((entry) => entry['startedAt'] = 'earlier today'),
      );

      expect(check!.live.first.startedAt, isNull);
      expect(check.live.first.kind, YoutubeStreamKind.kirtan);
    });

    test('a missing title is empty text, not a fault', () {
      final check = YoutubeLiveCheck.tryParse(
        _withEntry((entry) => entry.remove('title')),
      );

      expect(check!.live.first.title, isEmpty);
    });

    group('an unknown kind is not video', () {
      for (final kind in <Object?>['shorts', 'Kirtan', '', 7, null]) {
        test('kind: ${jsonEncode(kind)}', () {
          final check = YoutubeLiveCheck.tryParse(
            _withEntry((entry) => entry['kind'] = kind),
          )!;

          expect(check.live.first.kind, YoutubeStreamKind.unknown);
          expect(check.live.first.kind.isVideo, isFalse);
          expect(check.video, isNull);
        });
      }

      test('a missing kind too', () {
        final check = YoutubeLiveCheck.tryParse(
          _withEntry((entry) => entry.remove('kind')),
        )!;

        expect(check.live.first.kind, YoutubeStreamKind.unknown);
      });
    });

    group('a file it cannot read is no answer', () {
      final bad = <String, String>{
        'an empty body': '',
        'text that is not JSON': 'Not Found',
        'cut off in the middle': _contract.substring(0, 120),
        'an HTML error page': '<!doctype html><title>429</title>',
        'JSON null': 'null',
        'a list': '[]',
        'a number': '7',
        'a string': '"live"',
        'no checkedAt': _edited((f) => f.remove('checkedAt')),
        'checkedAt null': _edited((f) => f['checkedAt'] = null),
        'checkedAt a number': _edited((f) => f['checkedAt'] = 1794051065),
        'checkedAt gibberish': _edited((f) => f['checkedAt'] = 'yesterday'),
        'checkedAt with no zone':
            _edited((f) => f['checkedAt'] = '2026-11-07T11:31:05'),
        'no live': _edited((f) => f.remove('live')),
        'live null': _edited((f) => f['live'] = null),
        'live an object': _edited((f) => f['live'] = {'videoId': 'x'}),
        'an entry that is a string': _edited((f) => f['live'] = ['x']),
        'an entry that is null': _edited((f) => f['live'] = [null]),
        'an entry with no videoId': _withEntry((e) => e.remove('videoId')),
        'an entry with videoId a number': _withEntry((e) => e['videoId'] = 7),
        'an entry with no url': _withEntry((e) => e.remove('url')),
        'an entry with url null': _withEntry((e) => e['url'] = null),
      };
      bad.forEach((name, body) {
        test(name, () {
          expect(YoutubeLiveCheck.tryParse(body), isNull);
        });
      });

      test('one bad entry spoils the file, so the app never trusts half', () {
        // Dropping the broken kirtan entry would read as "only audio is on",
        // and hide a row for a stream that is live.
        final body = _edited((file) {
          (file['live'] as List).insert(0, {'kind': 'kirtan'});
        });

        expect(YoutubeLiveCheck.tryParse(body), isNull);
      });
    });
  });

  group('YoutubeLiveCheck.isFreshAt', () {
    final checkedAt = DateTime.utc(2026, 11, 7, 11, 31, 5);
    final check = YoutubeLiveCheck(checkedAt: checkedAt, live: const []);
    bool fresh(Duration after) => check.isFreshAt(checkedAt.add(after));

    test('is fresh the moment it was made', () {
      expect(fresh(Duration.zero), isTrue);
    });

    test('is fresh for 20 minutes, to the microsecond', () {
      expect(fresh(const Duration(minutes: 19, seconds: 59)), isTrue);
      expect(fresh(const Duration(minutes: 20)), isTrue);
      expect(fresh(const Duration(minutes: 20, microseconds: 1)), isFalse);
      expect(fresh(const Duration(minutes: 21)), isFalse);
      expect(fresh(const Duration(hours: 9)), isFalse);
    });

    test('allows 5 minutes of clock skew when the phone runs behind', () {
      expect(fresh(-const Duration(minutes: 1)), isTrue);
      expect(fresh(-const Duration(minutes: 5)), isTrue);
      expect(fresh(-const Duration(minutes: 5, microseconds: 1)), isFalse);
      expect(fresh(-const Duration(hours: 1)), isFalse);
    });

    test('does not care which zone the clock reads in', () {
      final now = checkedAt.add(const Duration(minutes: 10));
      expect(check.isFreshAt(now.toLocal()), isTrue);
      expect(check.isFreshAt(now.toUtc()), isTrue);
    });
  });

  group('YoutubeLiveCheck.untilStale', () {
    final checkedAt = DateTime.utc(2026, 11, 7, 11, 31, 5);
    final check = YoutubeLiveCheck(checkedAt: checkedAt, live: const []);

    test('counts to just after the 20th minute', () {
      expect(
        check.untilStale(checkedAt.add(const Duration(minutes: 19))),
        const Duration(minutes: 1, seconds: 1),
      );
    });

    test('is the full 20 minutes and a second for an answer made just now', () {
      expect(
        check.untilStale(checkedAt),
        const Duration(minutes: 20, seconds: 1),
      );
    });

    test('is more than zero whenever the answer is fresh', () {
      expect(
        check.untilStale(checkedAt.add(const Duration(minutes: 20))),
        const Duration(seconds: 1),
      );
    });

    test('is null when the answer is already stale', () {
      expect(
        check.untilStale(
          checkedAt.add(const Duration(minutes: 20, microseconds: 1)),
        ),
        isNull,
      );
    });
  });

  group('YoutubeLiveCheck.video', () {
    YoutubeLiveCheck of(List<YoutubeStream> live) =>
        YoutubeLiveCheck(checkedAt: DateTime.utc(2026), live: live);

    final audio = _stream(YoutubeStreamKind.audio, 'AAAAAAAAAAA');
    final kirtan = _stream(YoutubeStreamKind.kirtan, 'KKKKKKKKKKK');
    final katha = _stream(YoutubeStreamKind.katha, 'TTTTTTTTTTT');

    test('is null when nothing is on', () {
      expect(of(const []).video, isNull);
    });

    test('is null when only audio is on', () {
      expect(of([audio]).video, isNull);
    });

    test('is the kirtan stream', () {
      expect(of([audio, kirtan]).video, same(kirtan));
    });

    test('is the katha stream when there is no kirtan', () {
      expect(of([audio, katha]).video, same(katha));
    });

    test('prefers kirtan to katha, whichever comes first', () {
      expect(of([katha, kirtan]).video, same(kirtan));
      expect(of([kirtan, katha]).video, same(kirtan));
    });

    test('skips a stream of an unknown kind', () {
      final other = _stream(YoutubeStreamKind.unknown, 'UUUUUUUUUUU');

      expect(of([other, katha]).video, same(katha));
    });
  });

  test('only kirtan and katha are video', () {
    expect(YoutubeStreamKind.kirtan.isVideo, isTrue);
    expect(YoutubeStreamKind.katha.isVideo, isTrue);
    expect(YoutubeStreamKind.audio.isVideo, isFalse);
    expect(YoutubeStreamKind.unknown.isVideo, isFalse);
  });
}
