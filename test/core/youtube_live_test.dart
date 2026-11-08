import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/core/youtube_live.dart';
import 'package:live_darbar/src/models/sgpc_day.dart';
import 'package:live_darbar/src/models/youtube_live_check.dart';

/// SGPC streams Sri Harmandir Sahib on YouTube about 3 times a day. The row
/// follows the answer a GitHub Action publishes ([YoutubeLiveCheck]). When
/// there is no fresh answer, the app guesses from the times seen on 1 to 7
/// November 2026: 04:00 to 09:05, 12:30 to 14:25 and 17:00 to 19:00, India
/// time. A window holds its start and not its end.
void main() {
  /// [hour]:[minute]:[second] India time on 7 November 2026, as an instant.
  DateTime ist(int hour, int minute, [int second = 0]) =>
      DateTime.utc(2026, 11, 7, hour, minute, second).subtract(kIndiaOffset);

  bool live(DateTime at) => isYoutubeLiveWindow(at);

  test('the channel is pinned by its ID, and the link opens its live page', () {
    expect(kYoutubeChannelId, 'UCYn6UEtQ771a_OWSiNBoG8w');
    expect(
      kYoutubeLiveUrl,
      'https://www.youtube.com/channel/UCYn6UEtQ771a_OWSiNBoG8w/live',
    );
  });

  group('the morning window, 04:00 to 09:05', () {
    test('is closed at 03:59 and open at 04:00', () {
      expect(live(ist(3, 59)), isFalse);
      expect(live(ist(3, 59, 59)), isFalse);
      expect(live(ist(4, 0)), isTrue);
    });

    test('is open at 09:04:59 and closed at 09:05', () {
      expect(live(ist(9, 4, 59)), isTrue);
      expect(live(ist(9, 5)), isFalse);
    });

    test('is open in the middle', () {
      expect(live(ist(6, 30)), isTrue);
    });
  });

  group('the midday window, 12:30 to 14:25', () {
    test('is closed at 12:29 and open at 12:30', () {
      expect(live(ist(12, 29)), isFalse);
      expect(live(ist(12, 30)), isTrue);
    });

    test('is open at 14:24 and closed at 14:25', () {
      expect(live(ist(14, 24, 59)), isTrue);
      expect(live(ist(14, 25)), isFalse);
    });
  });

  group('the evening window, 17:00 to 19:00', () {
    test('is closed at 16:59 and open at 17:00', () {
      expect(live(ist(16, 59)), isFalse);
      expect(live(ist(17, 0)), isTrue);
    });

    test('is open at 18:59 and closed at 19:00', () {
      expect(live(ist(18, 59, 59)), isTrue);
      expect(live(ist(19, 0)), isFalse);
    });
  });

  test('is closed between the windows and through the night', () {
    for (final (h, m) in [
      (0, 0),
      (2, 30),
      (10, 0),
      (11, 59),
      (15, 0),
      (16, 30),
      (19, 30),
      (23, 59),
    ]) {
      expect(live(ist(h, m)), isFalse, reason: '$h:$m IST');
    }
  });

  group('a listener far from India', () {
    // Dart cannot build a DateTime in a zone of our choice, so each case is
    // the instant a clock in that zone shows, written in UTC. The comment says
    // what that clock reads. A window that read the phone's own clock would
    // get every one of these wrong.

    test('in Sydney (UTC+11) sees 04:30 India time as 10:00 at home', () {
      // 10:00 in Sydney on 7 Nov is 23:00 UTC on 6 Nov: 04:30 at Amritsar.
      expect(live(DateTime.utc(2026, 11, 6, 23)), isTrue);
    });

    test('in Sydney, 07:00 at home is 01:30 in Amritsar: closed', () {
      expect(live(DateTime.utc(2026, 11, 6, 20)), isFalse);
    });

    test('in Sydney, 09:30 at home is 04:00 in Amritsar: open', () {
      expect(live(DateTime.utc(2026, 11, 6, 22, 30)), isTrue);
      expect(live(DateTime.utc(2026, 11, 6, 22, 29)), isFalse);
    });

    test('in Vancouver (UTC-8) sees 13:00 at home as 02:30 in Amritsar', () {
      // 13:00 in Vancouver on 6 Nov is 21:00 UTC: 02:30 on 7 Nov at Amritsar.
      expect(live(DateTime.utc(2026, 11, 6, 21)), isFalse);
    });

    test('in Vancouver, 08:00 at home is 21:30 in Amritsar: closed', () {
      expect(live(DateTime.utc(2026, 11, 6, 16)), isFalse);
    });

    test('in Vancouver, 14:30 at home is 04:00 in Amritsar: open', () {
      expect(live(DateTime.utc(2026, 11, 6, 22, 30)), isTrue);
    });

    test('in Vancouver, 05:00 at home is 18:30 in Amritsar: open', () {
      expect(live(DateTime.utc(2026, 11, 6, 13)), isTrue);
    });

    test('a local DateTime and a UTC one for the same instant agree', () {
      final instant = ist(13, 0);
      expect(live(instant.toLocal()), live(instant.toUtc()));
      expect(live(instant.toLocal()), isTrue);
    });
  });

  group('untilNextYoutubeChange', () {
    Duration until(DateTime at) => untilNextYoutubeChange(at);

    test('before the morning window it counts to 04:00', () {
      expect(until(ist(3, 59)), const Duration(minutes: 1));
      expect(until(ist(2, 0)), const Duration(hours: 2));
    });

    test('at the start it counts to the end of that window', () {
      expect(until(ist(4, 0)), const Duration(hours: 5, minutes: 5));
      expect(until(ist(12, 30)), const Duration(hours: 1, minutes: 55));
      expect(until(ist(17, 0)), const Duration(hours: 2));
    });

    test('inside a window it counts to its end, to the second', () {
      expect(until(ist(8, 59, 30)), const Duration(minutes: 5, seconds: 30));
    });

    test('at the end it counts to the start of the next window', () {
      expect(until(ist(9, 5)), const Duration(hours: 3, minutes: 25));
      expect(until(ist(14, 25)), const Duration(hours: 2, minutes: 35));
    });

    test('after the evening window it counts to 04:00 tomorrow', () {
      expect(until(ist(19, 0)), const Duration(hours: 9));
      expect(until(ist(23, 0)), const Duration(hours: 5));
      expect(until(ist(23, 59, 59)), const Duration(hours: 4, seconds: 1));
    });

    test('is the same for a listener in Sydney or Vancouver', () {
      // 04:00 IST is 22:30 UTC the day before, whatever clock shows it.
      final at = DateTime.utc(2026, 11, 6, 22, 29);
      expect(until(at), const Duration(minutes: 1));
      expect(until(at.toLocal()), const Duration(minutes: 1));
    });

    test('keeps the microseconds', () {
      final at = ist(9, 4, 59).add(const Duration(microseconds: 250));
      expect(until(at), const Duration(microseconds: 999750));
    });

    test('lands on a real change, and not before it, at every minute', () {
      // Every 30 seconds for a day. Waiting that long and looking again must
      // find a different answer, and 1 microsecond sooner the same one.
      const microsecond = Duration(microseconds: 1);
      final start = ist(0, 0);
      for (var s = 0; s < 24 * 3600; s += 30) {
        final now = start.add(Duration(seconds: s));
        final wait = until(now);
        expect(wait, greaterThan(Duration.zero), reason: '$now');
        expect(
          live(now.add(wait - microsecond)),
          live(now),
          reason: 'just before the edge, from $now',
        );
        expect(
          live(now.add(wait)),
          isNot(live(now)),
          reason: 'at the edge, from $now',
        );
      }
    });
  });

  group('the checked answer', () {
    const kirtanId = 'AbCdEfGhIjK';
    const kathaId = 'KkKkKkKkKkK';
    const audioId = '7M4WO8CokSA';
    String watch(String id) => 'https://www.youtube.com/watch?v=$id';

    YoutubeStream stream(
      YoutubeStreamKind kind,
      String id, {
      String? url,
    }) =>
        YoutubeStream(
            videoId: id, kind: kind, title: '', url: url ?? watch(id));

    final kirtan = stream(YoutubeStreamKind.kirtan, kirtanId);
    final katha = stream(YoutubeStreamKind.katha, kathaId);
    final audio = stream(YoutubeStreamKind.audio, audioId);

    /// An answer made [ago] before [now].
    YoutubeLiveCheck made(
      DateTime now,
      List<YoutubeStream> live, {
      Duration ago = const Duration(minutes: 1),
    }) =>
        YoutubeLiveCheck(checkedAt: now.subtract(ago), live: live);

    group('youtubeLiveLink, with a fresh answer', () {
      test('a kirtan stream shows the row, and its link is the video', () {
        final now = ist(5, 0);

        expect(youtubeLiveLink(now, made(now, [kirtan])), watch(kirtanId));
      });

      test('shows the row outside every window, because the answer rules', () {
        final now = ist(10, 30);
        expect(live(now), isFalse);

        expect(youtubeLiveLink(now, made(now, [kirtan])), watch(kirtanId));
      });

      test('a katha stream is the link when there is no kirtan', () {
        final now = ist(13, 0);

        expect(youtubeLiveLink(now, made(now, [katha])), watch(kathaId));
        expect(
          youtubeLiveLink(now, made(now, [audio, katha])),
          watch(kathaId),
        );
      });

      test('kirtan wins over katha, in either order', () {
        final now = ist(5, 0);

        expect(
          youtubeLiveLink(now, made(now, [katha, kirtan])),
          watch(kirtanId),
        );
        expect(
          youtubeLiveLink(now, made(now, [kirtan, katha])),
          watch(kirtanId),
        );
      });

      test('audio only hides the row, even inside a window', () {
        final now = ist(5, 0);
        expect(live(now), isTrue);

        expect(youtubeLiveLink(now, made(now, [audio])), isNull);
      });

      test('an empty answer hides the row, even inside a window', () {
        final now = ist(17, 30);
        expect(live(now), isTrue);

        expect(youtubeLiveLink(now, made(now, const [])), isNull);
      });

      test('a stream of an unknown kind hides the row', () {
        final now = ist(5, 0);
        final other = stream(YoutubeStreamKind.unknown, 'UuUuUuUuUuU');

        expect(youtubeLiveLink(now, made(now, [other])), isNull);
      });

      test('an answer 20 minutes old is still fresh', () {
        final now = ist(5, 0);
        final old = made(now, const [], ago: const Duration(minutes: 20));

        // Fresh and empty hides the row. The timetable would show it.
        expect(youtubeLiveLink(now, old), isNull);
      });

      test('an answer 4 minutes ahead of the phone is fresh', () {
        final now = ist(5, 0);
        final ahead = made(now, const [], ago: -const Duration(minutes: 4));

        expect(youtubeLiveLink(now, ahead), isNull);
      });
    });

    group('youtubeLiveLink, with no usable answer it is the timetable', () {
      test('no answer: inside a window it opens the channel live page', () {
        expect(youtubeLiveLink(ist(5, 0), null), kYoutubeLiveUrl);
      });

      test('no answer: outside a window the row is hidden', () {
        expect(youtubeLiveLink(ist(10, 30), null), isNull);
      });

      test('a stale answer is ignored: inside a window, the channel page', () {
        final now = ist(5, 0);
        final stale = made(
          now,
          const [],
          ago: const Duration(minutes: 20, microseconds: 1),
        );

        // The empty answer would hide the row. It is too old to say so.
        expect(youtubeLiveLink(now, stale), kYoutubeLiveUrl);
      });

      test('a stale answer is ignored: outside a window, hidden', () {
        final now = ist(10, 30);
        final stale = made(now, [kirtan], ago: const Duration(minutes: 21));

        // The kirtan stream would show the row. It is too old to say so.
        expect(youtubeLiveLink(now, stale), isNull);
      });

      test('an answer from more than 5 minutes ahead is ignored', () {
        final now = ist(5, 0);
        final ahead = made(
          now,
          const [],
          ago: -const Duration(minutes: 5, microseconds: 1),
        );

        expect(youtubeLiveLink(now, ahead), kYoutubeLiveUrl);
      });

      test('the timetable still ends at its edge', () {
        expect(youtubeLiveLink(ist(9, 4, 59), null), kYoutubeLiveUrl);
        expect(youtubeLiveLink(ist(9, 5), null), isNull);
      });
    });

    group('the link of a stream is checked before it is opened', () {
      String? link(YoutubeStream s) {
        final now = ist(5, 0);
        return youtubeLiveLink(now, made(now, [s]));
      }

      YoutubeStream withUrl(String url) =>
          stream(YoutubeStreamKind.kirtan, kirtanId, url: url);

      test('the exact watch link is kept', () {
        expect(link(kirtan), watch(kirtanId));
      });

      test('an id with - and _ is fine', () {
        final s = stream(YoutubeStreamKind.kirtan, 'a-B_c-D_e-F');

        expect(link(s), 'https://www.youtube.com/watch?v=a-B_c-D_e-F');
      });

      test('more query after the id is fine, and is kept', () {
        final s = withUrl('${watch(kirtanId)}&t=5s');

        expect(link(s), '${watch(kirtanId)}&t=5s');
      });

      final bad = <String, YoutubeStream>{
        'an http link': withUrl('http://www.youtube.com/watch?v=$kirtanId'),
        'no www': withUrl('https://youtube.com/watch?v=$kirtanId'),
        'another host': withUrl(
          'https://www.youtube.com.example.org/watch?v=$kirtanId',
        ),
        'a host before it': withUrl(
          'https://evil.example/https://www.youtube.com/watch?v=$kirtanId',
        ),
        'the channel live page': withUrl(kYoutubeLiveUrl),
        'another scheme': withUrl(
          'intent://www.youtube.com/watch?v=$kirtanId',
        ),
        'a different id in the link': withUrl(watch('ZzZzZzZzZzZ')),
        'a longer id in the link': withUrl('${watch(kirtanId)}x'),
        'a fragment straight after the id': withUrl('${watch(kirtanId)}#top'),
        'no id in the link': withUrl('https://www.youtube.com/watch?v='),
        'a videoId that is too short':
            stream(YoutubeStreamKind.kirtan, 'AbCdEfGhIj'),
        'a videoId that is too long':
            stream(YoutubeStreamKind.kirtan, 'AbCdEfGhIjKl'),
        'a videoId with a bad character':
            stream(YoutubeStreamKind.kirtan, 'AbCdEfGh.jK'),
        'an empty videoId and url':
            stream(YoutubeStreamKind.kirtan, '', url: ''),
      };
      bad.forEach((name, s) {
        test('$name: the row stays, and opens the channel live page', () {
          expect(link(s), kYoutubeLiveUrl);
        });
      });
    });

    group('untilYoutubeLinkChanges', () {
      test('with no answer it is the timetable edge', () {
        final now = ist(8, 59, 30);

        expect(untilYoutubeLinkChanges(now, null), untilNextYoutubeChange(now));
        expect(
          untilYoutubeLinkChanges(now, null),
          const Duration(minutes: 5, seconds: 30),
        );
      });

      test('with a fresh answer that goes stale first, it is that', () {
        final now = ist(6, 0);
        final answer = made(now, [kirtan], ago: const Duration(minutes: 19));

        expect(
          untilYoutubeLinkChanges(now, answer),
          const Duration(minutes: 1, seconds: 1),
        );
      });

      test('with a fresh answer and an edge first, it is the edge', () {
        final now = ist(9, 4);
        final answer = made(now, [kirtan], ago: const Duration(minutes: 1));

        expect(
          untilYoutubeLinkChanges(now, answer),
          const Duration(minutes: 1),
        );
      });

      test('with a stale answer it is the timetable edge', () {
        final now = ist(9, 4);
        final answer = made(now, [kirtan], ago: const Duration(hours: 3));

        expect(
          untilYoutubeLinkChanges(now, answer),
          untilNextYoutubeChange(now),
        );
      });

      test('the link has changed when the wait ends, and not before it', () {
        // The wait carries 1 second more than the 20 minutes, so the answer
        // is stale when the timer fires, and is still fresh 1 second before.
        final now = ist(6, 0);
        final answer = made(now, [kirtan], ago: const Duration(minutes: 19));
        final wait = untilYoutubeLinkChanges(now, answer);

        expect(
          youtubeLiveLink(now.add(wait - const Duration(seconds: 1)), answer),
          watch(kirtanId),
        );
        expect(youtubeLiveLink(now.add(wait), answer), kYoutubeLiveUrl);
      });
    });
  });
}
