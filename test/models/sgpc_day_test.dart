import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/models/sgpc_day.dart';

void main() {
  group('sgpcDayOf', () {
    test('is the calendar day in Amritsar, not in UTC', () {
      // 20:00 UTC is already the next morning in India.
      final instant = DateTime.utc(2026, 8, 11, 20, 0);
      expect(sgpcDayOf(instant), DateTime.utc(2026, 8, 12));
    });

    test('rolls over at 18:30 UTC, which is midnight IST', () {
      expect(
        sgpcDayOf(DateTime.utc(2026, 8, 11, 18, 29, 59)),
        DateTime.utc(2026, 8, 11),
      );
      expect(
        sgpcDayOf(DateTime.utc(2026, 8, 11, 18, 30)),
        DateTime.utc(2026, 8, 12),
      );
    });

    test('gives the same day whatever zone the instant is expressed in', () {
      // The bug this guards against is keying off the device's calendar. A
      // listener in Los Angeles at 15:00 on 11 August and one in Auckland at
      // 10:00 on 12 August are the same moment, and both should be served the
      // Hukamnama being read in Amritsar right then.
      final losAngeles = DateTime.utc(2026, 8, 11, 22, 0); // 15:00 PDT
      final auckland = DateTime.utc(2026, 8, 11, 22, 0); // 10:00 NZST, 12 Aug
      expect(sgpcDayOf(losAngeles), DateTime.utc(2026, 8, 12));
      expect(sgpcDayOf(auckland), DateTime.utc(2026, 8, 12));
    });

    test('converts a local DateTime before reading its fields', () {
      final local = DateTime.utc(2026, 8, 11, 20, 0).toLocal();
      expect(sgpcDayOf(local), DateTime.utc(2026, 8, 12));
    });

    test('always returns UTC midnight', () {
      final day = sgpcDayOf(DateTime.utc(2026, 8, 11, 20, 0));
      expect(day.isUtc, isTrue);
      expect(day.hour, 0);
      expect(day.minute, 0);
    });

    test('crosses a month boundary', () {
      expect(
        sgpcDayOf(DateTime.utc(2026, 7, 31, 19, 0)),
        DateTime.utc(2026, 8, 1),
      );
    });

    test('crosses a year boundary', () {
      expect(
        sgpcDayOf(DateTime.utc(2025, 12, 31, 19, 0)),
        DateTime.utc(2026, 1, 1),
      );
    });
  });

  group('previousSgpcDay', () {
    test('steps back one calendar day', () {
      expect(
        previousSgpcDay(DateTime.utc(2026, 8, 12)),
        DateTime.utc(2026, 8, 11),
      );
    });

    test('steps back across a month boundary', () {
      expect(
        previousSgpcDay(DateTime.utc(2026, 8, 1)),
        DateTime.utc(2026, 7, 31),
      );
    });

    test('steps back across a leap day', () {
      expect(
        previousSgpcDay(DateTime.utc(2024, 3, 1)),
        DateTime.utc(2024, 2, 29),
      );
    });

    test('steps back across a year boundary', () {
      expect(
        previousSgpcDay(DateTime.utc(2026, 1, 1)),
        DateTime.utc(2025, 12, 31),
      );
    });

    test('never repeats a day, even over a daylight-saving transition', () {
      // Duration arithmetic on a local DateTime measures elapsed time rather
      // than calendar days, so 24 hours across a DST boundary lands on 23:00
      // the day you started and truncating back to midnight repeats the date.
      // Working in UTC is what makes this safe, and this walks a full year to
      // prove it rather than asserting it.
      var day = DateTime.utc(2026, 3, 15);
      for (var i = 0; i < 365; i++) {
        final previous = previousSgpcDay(day);
        expect(
          previous.isBefore(day),
          isTrue,
          reason: '$previous should precede $day',
        );
        expect(day.difference(previous), const Duration(days: 1));
        day = previous;
      }
    });
  });

  group('sgpcDayStamp', () {
    test('is ddmmyy with both fields zero padded', () {
      expect(sgpcDayStamp(DateTime.utc(2026, 8, 12)), '120826');
      expect(sgpcDayStamp(DateTime.utc(2026, 8, 5)), '050826');
      expect(sgpcDayStamp(DateTime.utc(2026, 1, 1)), '010126');
    });

    test('takes the last two digits of the year', () {
      expect(sgpcDayStamp(DateTime.utc(2026, 12, 31)), '311226');
      expect(sgpcDayStamp(DateTime.utc(2030, 3, 9)), '090330');
      // The one that would silently produce "0301100" without the modulo.
      expect(sgpcDayStamp(DateTime.utc(2100, 3, 1)), '010300');
    });

    test('is always six characters', () {
      var day = DateTime.utc(2026, 1, 1);
      for (var i = 0; i < 400; i++) {
        expect(sgpcDayStamp(day), hasLength(6));
        day = DateTime.utc(day.year, day.month, day.day + 1);
      }
    });
  });

  group('sgpcDayIso', () {
    test('is yyyy-MM-dd, the shape the archive endpoint takes', () {
      expect(sgpcDayIso(DateTime.utc(2026, 8, 12)), '2026-08-12');
      expect(sgpcDayIso(DateTime.utc(2026, 1, 5)), '2026-01-05');
    });
  });

  group('sgpcDayFileStamp', () {
    test('is yyyy_MM_dd', () {
      expect(sgpcDayFileStamp(DateTime.utc(2026, 8, 12)), '2026_08_12');
      expect(sgpcDayFileStamp(DateTime.utc(2026, 1, 5)), '2026_01_05');
    });
  });

  group('DailyAsset', () {
    test('builds the dated Hukamnama audio URL', () {
      // Verified live on 2026-08-12: HTTP 200, audio/mpeg, 4784170 bytes.
      expect(
        DailyAsset.hukamnama.urlFor(DateTime.utc(2026, 8, 12)),
        'https://hs.sgpc.net/hukamnamaaudio/SGPCNET120826.mp3',
      );
    });

    test('builds the dated Katha audio URL', () {
      // Verified live on 2026-08-12 for the previous day: HTTP 200,
      // audio/mpeg, 142248241 bytes.
      expect(
        DailyAsset.katha.urlFor(DateTime.utc(2026, 8, 11)),
        'https://hs.sgpc.net/kathaaudio/katha110826.mp3',
      );
    });

    test('keeps the undated URLs as the last resort', () {
      expect(
        DailyAsset.hukamnama.latestUrl,
        'https://hs.sgpc.net/uploadhukamnama/hukamnama.mp3',
      );
      expect(
        DailyAsset.katha.latestUrl,
        'https://hs.sgpc.net/uploadkatha/katha.mp3',
      );
    });

    test('gives a different URL for every day, which is the whole point', () {
      final urls = <String>{};
      var day = DateTime.utc(2026, 1, 1);
      for (var i = 0; i < 365; i++) {
        urls.add(DailyAsset.hukamnama.urlFor(day));
        day = DateTime.utc(day.year, day.month, day.day + 1);
      }
      expect(urls, hasLength(365));
    });
  });

  group('hukamnamaPdfUrl', () {
    test('addresses the generated PDF by archive id', () {
      // id 769 was today's entry when this was measured: HTTP 200,
      // application/pdf, 683778 bytes, 0.37 s to first byte.
      expect(
        hukamnamaPdfUrl(769),
        'https://hs.sgpc.net/intdep/pdfdownload.php?id=769',
      );
    });
  });

  group('hukamnamaPdfIdFrom', () {
    test('reads the id out of a real answer', () {
      // Trimmed from the live response for selected_date=2026-08-12.
      const body = '{"supported":true,"hukamnama":{"id":"328","ang":"591",'
          '"ghukamnama":"\\u0a38\\u0a24\\u0a3f\\u0a17\\u0a41\\u0a30",'
          '"date":"2026-08-12",'
          '"efooter1":"Wednesday, 28th Saawan (Samvat 558 Nanakshahi)"},'
          '"pdfFiles":[{"id":769,"file_name":"hukamnama.pdf"}]}';
      expect(hukamnamaPdfIdFrom(body), 769);
    });

    test('returns null for a day SGPC does not have', () {
      // Byte for byte what the server sends for a date in the future. Note
      // that it is HTTP 200, so the status code cannot be the signal, and
      // that this is the ordinary state of today between midnight and roughly
      // half past five in Amritsar.
      const body = '{"supported":false,"hukamnama":{"date":"2026-08-13",'
          '"message":"No Hukamnama Available for this date."},"pdfFiles":[]}';
      expect(hukamnamaPdfIdFrom(body), isNull);
    });

    test('returns null rather than throwing on anything unexpected', () {
      expect(hukamnamaPdfIdFrom(''), isNull);
      expect(hukamnamaPdfIdFrom('<html>maintenance</html>'), isNull);
      expect(hukamnamaPdfIdFrom('[]'), isNull);
      expect(hukamnamaPdfIdFrom('{"supported":true}'), isNull);
      expect(hukamnamaPdfIdFrom('{"supported":true,"pdfFiles":[]}'), isNull);
      expect(hukamnamaPdfIdFrom('{"supported":true,"pdfFiles":[{}]}'), isNull);
      expect(
        hukamnamaPdfIdFrom('{"supported":"true","pdfFiles":[{"id":769}]}'),
        isNull,
      );
    });
  });
}
