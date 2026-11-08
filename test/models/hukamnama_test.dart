import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/models/hukamnama.dart';

Map<String, dynamic> _load(String name) => jsonDecode(
      File('test/fixtures/$name').readAsStringSync(),
    ) as Map<String, dynamic>;

/// A real response: POST https://hs.sgpc.net/hssearchhukmanamaTestCalender.php
/// with selected_date=2026-11-02, recorded on 2 November 2026 and not edited.
/// Dhanaasree Mahalla 4, Ang 668.
Map<String, dynamic> fixture() => _load('sgpc_hukamnama_2026_11_02.json');

/// A real response for 16 October 2026: a second heading line, and a
/// "Rahaau Dooja" pause marker that runs into the shabad number.
Map<String, dynamic> rahauDoojaFixture() =>
    _load('sgpc_hukamnama_2026_10_16.json');

/// The mirror's file for 2 November 2026: SGPC's answer above, plus the
/// `shabad` and `lines` keys that tool/hukamnama_mirror.dart adds from the
/// Shabad OS database. Written by the tool, so test/tool/hukamnama_mirror_test
/// keeps it true.
Map<String, dynamic> mirrorFixture() =>
    _load('mirror_hukamnama_2026_11_02.json');

/// A minimal answer that is a whole Hukamnama, with [body] merged over it.
Map<String, dynamic> response({
  Object? supported = true,
  Map<String, Object?> body = const {},
}) =>
    {
      'supported': supported,
      'hukamnama': {
        'ang': '12',
        'ghukamnama': 'ਸੋਚੈ ਸੋਚਿ ਨ ਹੋਵਈ ॥',
        'date': '2026-11-02',
        ...body,
      },
      'pdfFiles': <Object>[],
    };

void main() {
  group('Hukamnama.fromSgpc on the recorded response', () {
    final h = Hukamnama.fromSgpc(fixture());

    test('carries the day the text is for', () {
      expect(h.date, DateTime.utc(2026, 11, 2));
      expect(h.isFor(DateTime.utc(2026, 11, 2)), isTrue);
      expect(h.isFor(DateTime.utc(2026, 11, 3)), isFalse);
      // Only the calendar day counts, not the time or the zone.
      expect(h.isFor(DateTime(2026, 11, 2, 14, 30)), isTrue);
    });

    test('reads the Ang from SGPC\'s string', () {
      expect(h.ang, 668);
    });

    test('carries the heading in both languages', () {
      expect(h.headingGurmukhi, 'ਧਨਾਸਰੀ ਮਹਲਾ ੪॥');
      expect(h.headingEnglish, 'DHANAASAREE, FOURTH MEHL:');
    });

    test('breaks the text into its 10 lines, markers and numbers kept', () {
      expect(h.lines.map((l) => l.gurmukhi), [
        'ਹਰਿ ਹਰਿ ਬੂੰਦ ਭਏ ਹਰਿ ਸੁਆਮੀ ਹਮ ਚਾਤ੍ਰਿਕ ਬਿਲਲ ਬਿਲਲਾਤੀ ॥',
        'ਹਰਿ ਹਰਿ ਕ੍ਰਿਪਾ ਕਰਹੁ ਪ੍ਰਭ ਅਪਨੀ ਮੁਖਿ ਦੇਵਹੁ ਹਰਿ ਨਿਮਖਾਤੀ ॥੧॥',
        'ਹਰਿ ਬਿਨੁ ਰਹਿ ਨ ਸਕਉ ਇਕ ਰਾਤੀ ॥',
        'ਜਿਉ ਬਿਨੁ ਅਮਲੈ ਅਮਲੀ ਮਰਿ ਜਾਈ ਹੈ ਤਿਉ ਹਰਿ ਬਿਨੁ ਹਮ ਮਰਿ ਜਾਤੀ ॥ ਰਹਾਉ ॥',
        'ਤੁਮ ਹਰਿ ਸਰਵਰ ਅਤਿ ਅਗਾਹ ਹਮ ਲਹਿ ਨ ਸਕਹਿ ਅੰਤੁ ਮਾਤੀ ॥',
        'ਤੂ ਪਰੈ ਪਰੈ ਅਪਰੰਪਰੁ ਸੁਆਮੀ ਮਿਤਿ ਜਾਨਹੁ ਆਪਨ ਗਾਤੀ ॥੨॥',
        'ਹਰਿ ਕੇ ਸੰਤ ਜਨਾ ਹਰਿ ਜਪਿਓ ਗੁਰ ਰੰਗਿ ਚਲੂਲੈ ਰਾਤੀ ॥',
        'ਹਰਿ ਹਰਿ ਭਗਤਿ ਬਨੀ ਅਤਿ ਸੋਭਾ ਹਰਿ ਜਪਿਓ ਊਤਮ ਪਾਤੀ ॥੩॥',
        'ਆਪੇ ਠਾਕੁਰੁ ਆਪੇ ਸੇਵਕੁ ਆਪਿ ਬਨਾਵੈ ਭਾਤੀ ॥',
        'ਨਾਨਕੁ ਜਨੁ ਤੁਮਰੀ ਸਰਣਾਈ ਹਰਿ ਰਾਖਹੁ ਲਾਜ ਭਗਾਤੀ ॥੪॥੫॥',
      ]);
    });

    test('leaves the per-line meanings empty, which SGPC does not give', () {
      for (final line in h.lines) {
        expect(line.punjabi, isNull);
        expect(line.english, isNull);
        expect(line.transliteration, isNull);
      }
    });

    test('carries SGPC\'s whole Punjabi and English meanings', () {
      expect(h.punjabiMeaning, startsWith('ਹੇ ਹਰੀ! ਹੇ ਸੁਆਮੀ! ਮੈਂ ਪਪੀਹਾ'));
      expect(h.punjabiMeaning, endsWith('ਰੱਖਦਾ ਹੈਂ।੪।੫।'));
      expect(
          h.englishMeaning,
          startsWith('The Lord, Har, Har, is the rain-drop; I am the '
              'song-bird, crying, crying out for it.'));
      expect(h.englishMeaning, endsWith('|| 4 || 5 ||'));
    });

    test('carries the Nanakshahi date line, trimmed', () {
      // ਸ਼ is the one-piece ਸ਼, which is how SGPC writes it.
      expect(h.footerGurmukhi, 'ਸੋਮਵਾਰ, ੧੭ ਕੱਤਕ (ਸੰਮਤ ੫੫੮ ਨਾਨਕਸ਼ਾਹੀ)');
      expect(h.footerEnglish, 'Monday, 17th Katak (Samvat 558 Nanakshahi)');
    });

    test('loses no text between SGPC\'s block and the lines', () {
      final source = (fixture()['hukamnama'] as Map)['ghukamnama'] as String;
      expect(h.lines.map((l) => l.gurmukhi).join(' '), source);
    });

    test('survives the round trip to disk', () {
      final again = Hukamnama.fromJson(
        jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>,
      );
      expect(again.date, h.date);
      expect(again.ang, h.ang);
      expect(again.headingGurmukhi, h.headingGurmukhi);
      expect(again.headingEnglish, h.headingEnglish);
      expect(again.lines, h.lines);
      expect(again.punjabiMeaning, h.punjabiMeaning);
      expect(again.englishMeaning, h.englishMeaning);
      expect(again.footerGurmukhi, h.footerGurmukhi);
      expect(again.footerEnglish, h.footerEnglish);
    });
  });

  group('Hukamnama.fromSgpc on a day with a second heading line', () {
    final h = Hukamnama.fromSgpc(rahauDoojaFixture());

    test('joins the heading lines with a newline', () {
      expect(h.date, DateTime.utc(2026, 10, 16));
      expect(h.ang, 641);
      expect(
          h.headingGurmukhi, 'ਸੋਰਠਿ ਮਹਲਾ ੫ ਘਰੁ ੨ ਅਸਟਪਦੀਆ\nੴ ਸਤਿਗੁਰ ਪ੍ਰਸਾਦਿ ॥');
      expect(h.headingEnglish, startsWith('SORAT’H, FIFTH MEHL, SECOND HOUSE'));
      expect(h.headingEnglish, contains('\nONE UNIVERSAL CREATOR GOD.'));
    });

    test('keeps a pause marker with its line, and the number after it', () {
      final lines = h.lines.map((l) => l.gurmukhi).toList();
      expect(lines, hasLength(20));
      expect(lines,
          contains('ਹਾਰਿ ਪਰਿਓ ਸੁਆਮੀ ਕੈ ਦੁਆਰੈ ਦੀਜੈ ਬੁਧਿ ਬਿਬੇਕਾ ॥ ਰਹਾਉ ॥'));
      expect(
          lines.last,
          'ਭਇਓ ਕ੍ਰਿਪਾਲੁ ਦੀਨ ਦੁਖ ਭੰਜਨੁ ਹਰਿ ਹਰਿ ਕੀਰਤਨਿ ਇਹੁ ਮਨੁ ਰਾਤਾ ॥ '
          'ਰਹਾਉ ਦੂਜਾ ॥੧॥੩॥');
    });

    test('no line starts with a marker or ends without one', () {
      for (final line in h.lines.map((l) => l.gurmukhi)) {
        expect(line, endsWith('॥'));
        expect(line, isNot(matches(RegExp(r'^(ਰਹਾਉ|[੦-੯]|॥)'))));
      }
    });
  });

  group('splitHukamnamaLines', () {
    test('ends a line at each plain ॥', () {
      expect(splitHukamnamaLines('ਇਕ ਸਤਰ ॥ ਦੂਜੀ ਸਤਰ ॥'),
          ['ਇਕ ਸਤਰ ॥', 'ਦੂਜੀ ਸਤਰ ॥']);
    });

    test('keeps a verse number with its line', () {
      expect(
          splitHukamnamaLines('ਪਹਿਲੀ ॥੧॥ ਦੂਜੀ ॥੨॥'), ['ਪਹਿਲੀ ॥੧॥', 'ਦੂਜੀ ॥੨॥']);
    });

    test('keeps a run of numbers, the verse and the shabad', () {
      expect(splitHukamnamaLines('ਅੰਤ ਸਤਰ ॥੪॥੫॥੧੭॥ ਅਗਲੀ ॥'), [
        'ਅੰਤ ਸਤਰ ॥੪॥੫॥੧੭॥',
        'ਅਗਲੀ ॥',
      ]);
    });

    test('keeps ਰਹਾਉ with the line it follows', () {
      expect(splitHukamnamaLines('ਸਤਰ ॥ ਰਹਾਉ ॥ ਅਗਲੀ ॥'), [
        'ਸਤਰ ॥ ਰਹਾਉ ॥',
        'ਅਗਲੀ ॥',
      ]);
    });

    test('keeps ਰਹਾਉ after a verse number, and ਰਹਾਉ ਦੂਜਾ before one', () {
      expect(splitHukamnamaLines('ਸਤਰ ॥੧॥ ਰਹਾਉ ॥ ਅਗਲੀ ॥ ਰਹਾਉ ਦੂਜਾ ॥੧॥੩॥'), [
        'ਸਤਰ ॥੧॥ ਰਹਾਉ ॥',
        'ਅਗਲੀ ॥ ਰਹਾਉ ਦੂਜਾ ॥੧॥੩॥',
      ]);
    });

    test('breaks where the next word follows with no space', () {
      // SGPC writes `॥੨॥ਸਤਸੰਗਤਿ` and `॥ਸਰਵਰ` in places.
      expect(splitHukamnamaLines('ਪਹਿਲੀ ॥੨॥ਦੂਜੀ ॥ਤੀਜੀ ॥'),
          ['ਪਹਿਲੀ ॥੨॥', 'ਦੂਜੀ ॥', 'ਤੀਜੀ ॥']);
    });

    test('gives a section label such as ਸਲੋਕੁ a line of its own', () {
      expect(splitHukamnamaLines('ਸਲੋਕੁ ॥ ਪਹਿਲੀ ॥੧॥ ਛੰਤੁ ॥ ਦੂਜੀ ॥੧॥'),
          ['ਸਲੋਕੁ ॥', 'ਪਹਿਲੀ ॥੧॥', 'ਛੰਤੁ ॥', 'ਦੂਜੀ ॥੧॥']);
    });

    test('collapses runs of white space and trims', () {
      expect(splitHukamnamaLines('  ਤਟ   ਤੀਰਥ \n ਸਭ ॥  \t ਅਗਲੀ ॥  '),
          ['ਤਟ ਤੀਰਥ ਸਭ ॥', 'ਅਗਲੀ ॥']);
    });

    test('keeps text after the last ॥ as a last line', () {
      expect(splitHukamnamaLines('ਪਹਿਲੀ ॥ ਬਿਨਾ ਅੰਤ'), ['ਪਹਿਲੀ ॥', 'ਬਿਨਾ ਅੰਤ']);
    });

    test('gives no lines for blank text', () {
      expect(splitHukamnamaLines(''), isEmpty);
      expect(splitHukamnamaLines('  \n '), isEmpty);
    });
  });

  group('Hukamnama.fromSgpc with gaps in the response', () {
    test('accepts the smallest whole answer', () {
      final h = Hukamnama.fromSgpc(response());
      expect(h.lines.single.gurmukhi, 'ਸੋਚੈ ਸੋਚਿ ਨ ਹੋਵਈ ॥');
      expect(h.ang, 12);
      expect(h.headingGurmukhi, isNull);
      expect(h.headingEnglish, isNull);
      expect(h.punjabiMeaning, isNull);
      expect(h.englishMeaning, isNull);
      expect(h.footerGurmukhi, isNull);
      expect(h.footerEnglish, isNull);
    });

    test('refuses a day SGPC has no Hukamnama for', () {
      // SGPC's real answer for 3 November 2026 on the morning of the 2nd.
      final notPosted = jsonDecode(
        '{"supported":false,"hukamnama":{"date":"2026-11-03","message":'
        '"No Hukamnama Available for this date."},"pdfFiles":[]}',
      ) as Map<String, dynamic>;
      expect(() => Hukamnama.fromSgpc(notPosted), throwsFormatException);
      expect(() => Hukamnama.fromSgpc(response(supported: false)),
          throwsFormatException);
      expect(() => Hukamnama.fromSgpc(response(supported: null)),
          throwsFormatException);
      expect(() => Hukamnama.fromSgpc(response(supported: 'true')),
          throwsFormatException);
    });

    test('refuses a response with no Hukamnama object', () {
      expect(
          () => Hukamnama.fromSgpc({'supported': true}), throwsFormatException);
      expect(() => Hukamnama.fromSgpc({'supported': true, 'hukamnama': []}),
          throwsFormatException);
      expect(
          () => Hukamnama.fromSgpc(<String, dynamic>{}), throwsFormatException);
    });

    test('refuses a response with no Gurmukhi', () {
      for (final broken in <Object?>[null, '', '   \n', 12, <String>[]]) {
        expect(
          () => Hukamnama.fromSgpc(response(body: {'ghukamnama': broken})),
          throwsFormatException,
          reason: 'ghukamnama: $broken',
        );
      }
      // The meanings alone are not a Hukamnama.
      final onlyMeanings = response();
      (onlyMeanings['hukamnama'] as Map).remove('ghukamnama');
      (onlyMeanings['hukamnama'] as Map)['ehukamnamadesc'] = 'Meaning.';
      expect(() => Hukamnama.fromSgpc(onlyMeanings), throwsFormatException);
    });

    test('refuses a response that cannot say which day it is for', () {
      for (final broken in <Object?>[
        null,
        '',
        'yesterday',
        '2026-11-2',
        '02-11-2026',
        '2026-13-45',
        '2026-02-30',
        20261102,
      ]) {
        expect(
          () => Hukamnama.fromSgpc(response(body: {'date': broken})),
          throwsFormatException,
          reason: 'date: $broken',
        );
      }
    });

    test('has no Ang when SGPC gives none that is a page', () {
      for (final broken in <Object?>[null, '', 'sixty', '0', '-4', '1431']) {
        expect(
          Hukamnama.fromSgpc(response(body: {'ang': broken})).ang,
          isNull,
          reason: 'ang: $broken',
        );
      }
      expect(Hukamnama.fromSgpc(response(body: {'ang': ' 1430 '})).ang, 1430);
      expect(Hukamnama.fromSgpc(response(body: {'ang': 668})).ang, 668);
    });

    test('treats a blank heading, meaning or footer as missing', () {
      final h = Hukamnama.fromSgpc(response(body: {
        'gheading1': '  ',
        'gheading2': '',
        'eheading1': null,
        'ghukamnamadesc': '\n',
        'ehukamnamadesc': '',
        'gfooter1': ' ',
        'efooter1': null,
      }));
      expect(h.headingGurmukhi, isNull);
      expect(h.headingEnglish, isNull);
      expect(h.punjabiMeaning, isNull);
      expect(h.englishMeaning, isNull);
      expect(h.footerGurmukhi, isNull);
      expect(h.footerEnglish, isNull);
    });

    test('takes the second heading alone when the first is blank', () {
      final h = Hukamnama.fromSgpc(response(body: {
        'gheading1': '',
        'gheading2': ' ਸਲੋਕੁ  ਮਃ ੩ ॥ ',
      }));
      expect(h.headingGurmukhi, 'ਸਲੋਕੁ ਮਃ ੩ ॥');
    });
  });

  group('Hukamnama.fromJson', () {
    test('refuses what toJson did not write', () {
      expect(() => Hukamnama.fromJson({'version': 3}), throwsFormatException);
      expect(() => Hukamnama.fromJson({'version': 2}), throwsFormatException);
      expect(
          () => Hukamnama.fromJson({
                'version': 2,
                'date': '2026-11-02',
                'lines': <Object>[],
              }),
          throwsFormatException);
      expect(
          () => Hukamnama.fromJson({
                'version': 2,
                'date': 'yesterday',
                'lines': [
                  {'gurmukhi': 'ਸਲੋਕੁ ॥'},
                ],
              }),
          throwsFormatException);
    });

    test('does not read the early build\'s version 1 file', () {
      expect(
          () => Hukamnama.fromJson({
                'version': 1,
                'date': '2026-11-02',
                'ang': 668,
                'raag': 'Raag Dhanaasree',
                'lines': [
                  {'gurmukhi': 'ਧਨਾਸਰੀ ਮਹਲਾ ੪ ॥', 'english': 'Dhanaasaree.'},
                ],
              }),
          throwsFormatException);
    });
  });

  group('Hukamnama.shabad', () {
    test('is null for SGPC\'s own answer', () {
      expect(Hukamnama.fromSgpc(fixture()).shabad, isNull);
    });

    test('is read from the keys that the mirror adds', () {
      final h = Hukamnama.fromSgpc(mirrorFixture());
      final shabad = h.shabad!;

      expect(shabad.lines, hasLength(10));
      expect(shabad.ids, ['R5B']);
      expect(shabad.ang, 668);
      expect(shabad.angEnd, 668);
      expect(shabad.sections.single.roman, 'Raag Dhanaasree');
      expect(shabad.writers.single.roman, 'Guru Ramdas');
      expect(shabad.writers.single.gurmukhi, 'ਗੁਰੂ ਰਾਮਦਾਸ');
      expect(shabad.source, 'Shabad OS');
      expect(shabad.version, '5.0.0-next.0');
      expect(shabad.similarity, 1);
      expect(shabad.credits['english'], 'Dr. Sant Singh Khalsa');
      expect(shabad.credits['punjabi'], contains('Sahib Singh'));
    });

    test('reads each line: Gurmukhi, pauses, and both meanings', () {
      final line = Hukamnama.fromSgpc(mirrorFixture()).shabad!.lines.first;

      expect(line.id, '015H');
      expect(line.ang, 668);
      expect(
        line.gurmukhi,
        'ਹਰਿ ਹਰਿ ਬੂੰਦ ਭਏ ਹਰਿ ਸੁਆਮੀ ਹਮ ਚਾਤ੍ਰਿਕ ਬਿਲਲ ਬਿਲਲਾਤੀ ॥',
      );
      expect(line.vishraam, const [
        HukamnamaVishraam(5, HukamnamaPause.heavy),
      ]);
      expect(line.english, startsWith('The Lord, Har, Har'));
      expect(line.punjabi, startsWith('ਹੇ ਹਰੀ!'));
      // The Shabad OS release that the mirror uses has no transliteration.
      expect(line.transliteration, isNull);
    });

    test('leaves the lines of SGPC\'s text as they were', () {
      final plain = Hukamnama.fromSgpc(fixture());
      final mirrored = Hukamnama.fromSgpc(mirrorFixture());

      expect(mirrored.lines, plain.lines);
      expect(mirrored.englishMeaning, plain.englishMeaning);
      expect(mirrored.headingGurmukhi, plain.headingGurmukhi);
      expect(mirrored.ang, plain.ang);
      // SGPC's lines carry no pauses and no meanings of their own.
      for (final line in mirrored.lines) {
        expect(line.vishraam, isEmpty);
        expect(line.english, isNull);
        expect(line.id, isNull);
      }
    });

    test('counts the words that a pause follows in the line it belongs to', () {
      for (final line in Hukamnama.fromSgpc(mirrorFixture()).shabad!.lines) {
        final words = line.gurmukhi.split(' ');
        for (final pause in line.vishraam) {
          expect(pause.after, lessThan(words.length - 1), reason: '${line.id}');
        }
        // A pause never follows another on the same word.
        expect(
            {for (final p in line.vishraam) p.after},
            hasLength(
              line.vishraam.length,
            ));
      }
    });

    group('is null, and the day still reads, when', () {
      void isNullFor(String name, void Function(Map<String, dynamic>) change) {
        test(name, () {
          final json = mirrorFixture();
          change(json);
          final h = Hukamnama.fromSgpc(json);
          expect(h.shabad, isNull);
          expect(h.lines, hasLength(10));
          expect(h.ang, 668);
        });
      }

      isNullFor('the day did not match', (j) {
        j['shabad'] = {'matched': false, 'reason': 'Two runs match.'};
        j.remove('lines');
      });
      isNullFor('"matched" is missing', (j) {
        (j['shabad'] as Map).remove('matched');
      });
      isNullFor('there are no lines', (j) => j.remove('lines'));
      isNullFor('the lines are empty', (j) => j['lines'] = <Object>[]);
      isNullFor('the lines are not a list', (j) => j['lines'] = 'lines');
      isNullFor('one line is not an object', (j) {
        (j['lines'] as List)[3] = 'not a line';
      });
      isNullFor('one line has no Gurmukhi', (j) {
        ((j['lines'] as List)[3] as Map).remove('gurmukhi');
      });
      isNullFor('one line has blank Gurmukhi', (j) {
        ((j['lines'] as List)[3] as Map)['gurmukhi'] = '  ';
      });
      isNullFor('shabad is not an object', (j) => j['shabad'] = 'shabad');
      isNullFor('the Ang is missing', (j) {
        (j['shabad'] as Map).remove('ang');
      });
      isNullFor('the Ang is not a page of the Granth', (j) {
        (j['shabad'] as Map)['ang'] = 1431;
      });
    });

    test('keeps a line whose pause it cannot read, without the pause', () {
      final json = mirrorFixture();
      ((json['lines'] as List)[0] as Map)['vishraam'] = [
        {'after': 5, 'weight': 'heavy'},
        {'after': 2, 'weight': 'enormous'},
        {'after': -1, 'weight': 'light'},
        {'weight': 'light'},
        'not a pause',
      ];
      final line = Hukamnama.fromSgpc(json).shabad!.lines.first;
      expect(line.vishraam, const [
        HukamnamaVishraam(5, HukamnamaPause.heavy),
      ]);
    });

    test('lets a line have no meaning, no pause and no id', () {
      final json = mirrorFixture();
      json['lines'] = [
        {'gurmukhi': 'ਸਲੋਕੁ ॥'},
      ];
      final line = Hukamnama.fromSgpc(json).shabad!.lines.single;
      expect(line.gurmukhi, 'ਸਲੋਕੁ ॥');
      expect(line.english, isNull);
      expect(line.punjabi, isNull);
      expect(line.id, isNull);
      expect(line.vishraam, isEmpty);
    });

    test('ends on the starting Ang when the end Ang is wrong', () {
      final json = mirrorFixture();
      (json['shabad'] as Map)['angEnd'] = 600;
      expect(Hukamnama.fromSgpc(json).shabad!.angEnd, 668);
    });

    test('survives the on-disk cache', () {
      final h = Hukamnama.fromSgpc(mirrorFixture());
      final back = Hukamnama.fromJson(
        jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>,
      );

      expect(back.shabad, isNotNull);
      expect(back.shabad!.lines, h.shabad!.lines);
      expect(back.shabad!.ids, h.shabad!.ids);
      expect(back.shabad!.ang, h.shabad!.ang);
      expect(back.shabad!.credits, h.shabad!.credits);
      expect(back.shabad!.writers, h.shabad!.writers);
      expect(back.lines, h.lines);
    });

    // 7 November 2026: SGPC titled a part of Sidh Gosht "ਦਖਣੀ ਓਅੰਕਾਰ". The
    // mirror gives the title from the database, with its meanings.
    test('reads the title lines, with their meanings', () {
      final h = Hukamnama.fromSgpc(_load('mirror_hukamnama_2026_11_07.json'));
      expect(h.headingGurmukhi, startsWith('ਰਾਮਕਲੀ ਮਹਲਾ ੧ ਦਖਣੀ ਓਅੰਕਾਰ'));
      final heading = h.shabad!.heading;
      expect([
        for (final l in heading) l.gurmukhi
      ], [
        'ਰਾਮਕਲੀ ਮਹਲਾ ੧ ਸਿਧ ਗੋਸਟਿ ॥',
        'ੴ ਸਤਿਗੁਰ ਪ੍ਰਸਾਦਿ ॥',
      ]);
      expect(heading[1].english,
          'One Universal Creator God. By The Grace Of The True Guru:');
      expect(heading[1].punjabi, startsWith('ਅਕਾਲ ਪੁਰਖ ਇੱਕ ਹੈ'));
    });

    test('keeps the title lines in the on-disk cache', () {
      final h = Hukamnama.fromSgpc(_load('mirror_hukamnama_2026_11_07.json'));
      final back = Hukamnama.fromJson(
        jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>,
      );
      expect(back.shabad!.heading, h.shabad!.heading);
      expect(back.shabad!.heading, hasLength(2));
    });

    test('reads a shabad with no title lines, as files before 7 November', () {
      final json = mirrorFixture();
      (json['shabad'] as Map).remove('heading');
      expect(Hukamnama.fromSgpc(json).shabad!.heading, isEmpty);
    });

    test('is not in the cache of a day that has none', () {
      final json = Hukamnama.fromSgpc(fixture()).toJson();
      expect(json.containsKey('shabad'), isFalse);
      expect(Hukamnama.fromJson(json).shabad, isNull);
    });

    test('reads a cache that has a damaged shabad as a day with none', () {
      final json = Hukamnama.fromSgpc(mirrorFixture()).toJson();
      (json['shabad'] as Map<String, dynamic>)['lines'] = <Object>[];
      final h = Hukamnama.fromJson(json);
      expect(h.shabad, isNull);
      expect(h.lines, hasLength(10));
    });
  });

  group('hukamnamaPreviewLine', () {
    Hukamnama of(List<String> lines) => Hukamnama(
          date: DateTime.utc(2026, 11, 2),
          lines: [for (final l in lines) HukamnamaLine(gurmukhi: l)],
        );

    test('is the Rahao line of the recorded 2 November shabad', () {
      final line = hukamnamaPreviewLine(Hukamnama.fromSgpc(fixture()))!;
      expect(line.gurmukhi, contains('ਰਹਾਉ'));
    });

    test('is the first Rahao line when a shabad has a second pause', () {
      final h = Hukamnama.fromSgpc(rahauDoojaFixture());
      final line = hukamnamaPreviewLine(h)!;
      expect(line.gurmukhi, contains('ਰਹਾਉ'));
      expect(
        h.lines.where((l) => l.gurmukhi.contains('ਰਹਾਉ')).first,
        line,
      );
    });

    test('prefers the Rahao line to an earlier long verse', () {
      final h = of([
        'ਗੁਰ ਪ੍ਰਸਾਦਿ ਸਾਧਸੰਗਿ ਮਿਲਿ ਹਰਿ ਨਾਮੁ ਜਪਿਓ ॥੧॥',
        'ਹਰਿ ਹਰਿ ਨਾਮੁ ਮੇਰੈ ਮਨਿ ਭਾਵੈ ॥੧॥ ਰਹਾਉ ॥',
      ]);
      expect(hukamnamaPreviewLine(h)!.gurmukhi, contains('ਰਹਾਉ'));
    });

    test('skips a short section label when there is no Rahao line', () {
      final h = of([
        'ਸਲੋਕੁ ॥',
        'ਗੁਰ ਪ੍ਰਸਾਦਿ ਸਾਧਸੰਗਿ ਮਿਲਿ ਹਰਿ ਨਾਮੁ ਜਪਿਓ ॥੧॥',
      ]);
      expect(
        hukamnamaPreviewLine(h)!.gurmukhi,
        'ਗੁਰ ਪ੍ਰਸਾਦਿ ਸਾਧਸੰਗਿ ਮਿਲਿ ਹਰਿ ਨਾਮੁ ਜਪਿਓ ॥੧॥',
      );
    });

    test('falls back to the first line when every line is short', () {
      final h = of(['ਸਲੋਕੁ ॥', 'ਪਉੜੀ ॥']);
      expect(hukamnamaPreviewLine(h)!.gurmukhi, 'ਸਲੋਕੁ ॥');
    });

    test('is null for a Hukamnama with no lines', () {
      expect(hukamnamaPreviewLine(of(const [])), isNull);
    });
  });
}
