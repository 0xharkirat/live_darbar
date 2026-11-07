import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/core/fuzzy_search.dart';
import 'package:live_darbar/src/models/sgpc_event.dart';

/// The search behind the Sikh history screen: typo tolerant in Latin letters,
/// loose in Gurmukhi, and a first-letter search in Gurmukhi like Chet's.
///
/// Most tests run on the 120 events that the app ships and shows, so a title
/// that changes in the data shows up here.
void main() {
  final shipped = SgpcEventTable.fromJsonString(
    File('assets/data/sgpc_events_558.json').readAsStringSync(),
  );
  final events = FuzzyIndex<SgpcEvent>(
    shipped.events,
    texts: (e) => [e.titleEn, e.titlePa],
  );

  /// The ids of the events that [query] finds, best first.
  List<String> ids(String query) => [
        for (final e in events.search(query)) e.id,
      ];

  String id(int n) => 'ns558-${n.toString().padLeft(3, '0')}';

  /// Strings that carry both of their names, "English | Punjabi".
  FuzzyIndex<String> names(List<String> items) =>
      FuzzyIndex(items, texts: (s) => s.split(' | '));

  test('the data is what the tests below expect', () {
    expect(shipped.events, hasLength(120), reason: '128 less 8 to review');
    expect(shipped.events.firstWhere((e) => e.id == id(85)).titleEn,
        'Bandi Chhor Divas (Diwali)');
  });

  group('English: spellings that must not matter', () {
    test('finds the event by its name', () {
      expect(ids('bandi chhor').first, id(85));
      expect(ids('Bandi Chhor Divas (Diwali)').first, id(85));
    });

    test('a typo: bandhi chor', () {
      expect(ids('bandhi chor').first, id(85));
    });

    test('case, diacritics and doubled letters', () {
      for (final query in [
        'BANDI CHHOR',
        'Bandī Chhoṛ',
        'bandii chhhor',
        'bandi    chhor  ',
      ]) {
        expect(ids(query).first, id(85), reason: query);
      }
    });

    test('words run together or pulled apart', () {
      expect(ids('bandichhor').first, id(85));
      expect(ids('jotijot').toSet(), containsAll({id(7), id(8), id(12)}));
      expect(ids('jormela').toSet(), containsAll({id(24), id(113)}));
    });

    test('Diwali, however it is spelled', () {
      for (final query in ['diwali', 'divali', 'dewali', 'deewali']) {
        expect(ids(query), [id(85)], reason: query);
      }
    });

    test('Vaisakhi, however it is spelled', () {
      for (final query in [
        'vaisakhi',
        'baisakhi',
        'vaishakhi',
        'baisaakhi',
        'vaisaki',
      ]) {
        expect(ids(query).first, id(18), reason: query);
      }
    });

    test('the month Vaisakh follows the festival', () {
      expect(ids('baisakhi'), [id(18), id(17)]);
    });

    test('the Banda Singh Bahadur typo: banda singh bahdur', () {
      final found = ids('banda singh bahdur');
      expect(found.toSet(), {id(26), id(37)});
      expect(found.first, id(26), reason: 'the words stand side by side');
    });

    test('z and j: Zorawar, Jorawar', () {
      expect(ids('zorawar').first, id(95));
      expect(ids('sahibjada jorawar singh').first, id(95));
    });

    test('v and b: Gurpurab, Gurpurav', () {
      expect(ids('gurpurav'), ids('gurpurab'));
      expect(ids('gurpurab'), isNotEmpty);
    });

    test('aa, ee, oo, h: Shaheedi Dihaada, Shahidi Dihara', () {
      expect(ids('shaheedi dihaada'), ids('shahidi dihada'));
      expect(ids('saheedi diharha').toSet(), ids('shahidi dihada').toSet());
      expect(ids('shahidi dihada'), isNotEmpty);
    });

    test('Dussehra', () {
      expect(ids('dussehra').first, id(74));
      expect(ids('dussera').first, id(74));
      expect(ids('dasehra').first, id(74));
    });

    test('Kaur, Kor', () {
      expect(ids('mata sahib kor').first, id(84));
    });

    test('Ghallughara finds the 3 of them', () {
      for (final query in ['ghallughara', 'ghalughara', 'galugara']) {
        expect(ids(query).toSet(), {id(28), id(32), id(117)}, reason: query);
      }
    });

    test('part of a word', () {
      expect(ids('ghara').toSet(), {id(28), id(32), id(117)});
      expect(ids('ban').first, id(85), reason: 'a title that starts with it');
    });

    test('a number', () {
      expect(ids('1984'), [id(32)]);
      expect(ids('558'), [id(2)]);
    });

    test('a word that fits 1 event only', () {
      expect(ids('mardana'), [id(94)]);
      expect(ids('mardhana'), [id(94)]);
      expect(ids('maradana'), [id(94)]);
    });

    test('a word that is the English name of an event', () {
      expect(ids('ravidas').first, id(124));
      expect(ids('ravi das').first, id(124));
    });
  });

  group('English: what does not match', () {
    test('a query that matches nothing', () {
      expect(ids('xyzzy'), isEmpty);
      expect(ids('qwertyuiop'), isEmpty);
      expect(ids('!!!'), isEmpty);
      expect(ids('ਙਙਙ'), isEmpty);
    });

    test('a word that is not close to any event', () {
      expect(ids('bandi helicopter'), isEmpty);
    });

    test('an empty query finds nothing', () {
      expect(ids(''), isEmpty);
      expect(ids('   '), isEmpty);
      expect(ids('\n\t'), isEmpty);
    });

    test('a typo does not pull in unrelated events', () {
      final found = events.search('singh');
      expect(found, isNotEmpty);
      for (final e in found) {
        expect('${e.titleEn}'.toLowerCase(), contains('singh'), reason: e.id);
      }
    });

    test('a short word has to be spelled right', () {
      // 3 letters, so no typo is allowed: "sru" is not "sri".
      expect(ids('sru'), isEmpty);
      expect(ids('sri'), isNotEmpty);
    });

    test('never lists an event twice', () {
      for (final query in ['singh', 'dihada', 'ji', 'b', 'ਸ', 'ਸ਼ਹੀਦੀ ਸਿੰਘ']) {
        final found = ids(query);
        expect(found.toSet(), hasLength(found.length), reason: query);
      }
    });

    test('1 letter finds the words that begin with it', () {
      final found = events.search('b');
      expect(found, isNotEmpty);
      expect(found.length, lessThan(events.search('s').length));
    });
  });

  group('ranking', () {
    test(
        'a title that begins with the words comes first, then the whole '
        'words, then the typos', () {
      final index = names([
        'Sangrand Vaisakh',
        'Khalsa Sajna Divas (Vaisakhi)',
        'Vaisakhi Mela',
      ]);

      expect(index.search('baisakhi'), [
        'Vaisakhi Mela',
        'Khalsa Sajna Divas (Vaisakhi)',
        'Sangrand Vaisakh',
      ]);
    });

    test('a whole word comes before one that only begins with it', () {
      final index = names(['Sri Gurpurabi', 'Sri Gurpurab']);

      expect(index.search('gurpurab'), ['Sri Gurpurab', 'Sri Gurpurabi']);
    });

    test('words side by side come before words apart', () {
      final index = names([
        'Shaheedi Banda Jathedar Singh',
        'Shaheedi Banda Singh',
      ]);

      expect(index.search('banda singh'), [
        'Shaheedi Banda Singh',
        'Shaheedi Banda Jathedar Singh',
      ]);
    });

    test('a match inside a word comes after the whole words, before a typo',
        () {
      final index = names(['Dihara', 'Ghallughara', 'Gallughari']);

      // "ghara": inside Ghallughara; 1 typo away from nothing else.
      expect(index.search('ghara'), ['Ghallughara']);
      // "gallughara": a whole word (Ghallughara), then a typo (Gallughari).
      expect(index.search('gallughara'), ['Ghallughara', 'Gallughari']);
    });

    test('a tie keeps the order of the calendar', () {
      final index = names([
        'Sangrand Chet',
        'Sangrand Vaisakh',
        'Sangrand Jeth',
      ]);

      expect(index.search('sangrand'), [
        'Sangrand Chet',
        'Sangrand Vaisakh',
        'Sangrand Jeth',
      ]);
    });

    test('the best name of an event decides, whichever language it is in', () {
      final index = names([
        'Zzz Event | ਬੰਦੀ ਛੋੜ',
        'Bandi Chhor | ਕੁਝ ਹੋਰ',
      ]);

      expect(index.search('bandi'), ['Bandi Chhor | ਕੁਝ ਹੋਰ']);
      expect(index.search('ਬੰਦੀ'), ['Zzz Event | ਬੰਦੀ ਛੋੜ']);
    });

    test('on the real data, Bandi Chhor comes before the Banda Singh events',
        () {
      // "bandi" is 1 letter from "banda", so the Banda Singh events follow it
      // as typos.
      final found = ids('bandi');
      expect(found.first, id(85));
      expect(found.indexOf(id(26)), greaterThan(0));
      expect(found.indexOf(id(37)), greaterThan(0));
    });
  });

  group('both names, whatever the language', () {
    test('an event is found by its English name and by its Punjabi one', () {
      expect(ids('bandi chhor').first, id(85));
      expect(ids('ਬੰਦੀ ਛੋੜ').first, id(85));
    });

    test('an event with no English name is found in Gurmukhi', () {
      final index = FuzzyIndex<SgpcEvent>(
        [
          SgpcEvent(
            id: 'only-pa',
            first: DateTime.utc(2026, 11, 3),
            last: DateTime.utc(2026, 11, 3),
            titlePa: 'ਭਾਈ ਘਨੱਈਆ ਜੀ ਮਾਨਵ ਸੇਵਾ ਦਿਵਸ',
          ),
        ],
        texts: (e) => [e.titleEn, e.titlePa],
      );

      expect(index.search('ਘਨੱਈਆ'), hasLength(1));
      expect(index.search('ghania'), isEmpty);
    });

    test('a text that is null or blank is skipped', () {
      final index = FuzzyIndex<String>(
        ['a', 'b'],
        texts: (s) => [null, '', '  ', if (s == 'b') 'Bandi Chhor'],
      );

      expect(index.search('bandi'), ['b']);
    });
  });

  group('Gurmukhi', () {
    test('finds the event by its Punjabi name', () {
      expect(ids('ਬੰਦੀ ਛੋੜ').first, id(85));
      expect(ids('ਬੰਦੀ ਛੋੜ ਦਿਵਸ (ਦਿਵਾਲੀ)').first, id(85));
    });

    test('no tippi, nukta or addak', () {
      expect(ids('ਬਦੀ ਛੋੜ').first, id(85), reason: 'no tippi');
      expect(ids('ਸਹੀਦੀ ਦਿਹਾੜਾ ਬਾਬਾ ਦੀਪ ਸਿਘ').first, id(88),
          reason: 'no nukta');
      expect(ids('ਸਿਖ ਦਸਤਾਰ ਦਿਵਸ'), [id(16)], reason: 'no addak');
      expect(ids('ਖਾਲਸਾ ਸਾਜਣਾ').first, id(18), reason: 'no nukta');
    });

    test('a vowel sign that is a near miss', () {
      expect(ids('ਬੰਦੀ ਛੌੜ').first, id(85), reason: 'ਛੌੜ for ਛੋੜ');
      expect(ids('ਬੰਦੀ ਛੋੜ ਦਿਵਸ ਦੀਵਾਲੀ').first, id(85), reason: 'ਦੀਵਾਲੀ');
      expect(ids('ਵਿਸਾਖੀ').first, id(18), reason: 'ਵਿਸਾਖੀ for ਵੈਸਾਖੀ');
      expect(ids('ਗੁਰਪੁਰਬ ਗੁਬਿੰਦ ਸਿੰਘ').first, id(114));
    });

    test('a missing vowel sign is 1 typo', () {
      final found = ids('ਬੰਦਾ ਸਿੰਘ ਬਹਾਦੁਰ');
      expect(found.toSet(), {id(26), id(37)});
    });

    test('a typo in a long word', () {
      expect(ids('ਦਿਹਾੜਾ ਭਗਤ ਕਬੀਰ').first, id(40));
      expect(ids('ਦਿਹਾੜਾ ਭਗਤ ਕਬੀਰ ਜੀ').first, id(40));
      expect(ids('ਜਨਮ ਦਹਾੜਾ ਭਗਤ ਕਬੀਰ').first, id(40), reason: 'ਦਹਾੜਾ');
    });

    test('Gurmukhi digits', () {
      expect(ids('੧੯੮੪'), [id(32)]);
    });

    test('part of a word', () {
      expect(ids('ਘੱਲੂਘਾ').toSet(), {id(28), id(32), id(117)});
    });

    test('a query that matches nothing', () {
      expect(ids('ਹੈਲੀਕਾਪਟਰ'), isEmpty);
    });
  });

  group('Gurmukhi first letters, as in Chet', () {
    test('ਬਛਦ finds ਬੰਦੀ ਛੋੜ ਦਿਵਸ', () {
      expect(ids('ਬਛਦ').first, id(85));
    });

    test('spaces between the letters do not matter', () {
      expect(ids('ਬ ਛ ਦ').first, id(85));
      expect(ids('ਬ ਛਦ').first, id(85));
    });

    test('the first letters of the first words are enough', () {
      expect(ids('ਬਛ').first, id(85));
      expect(ids('ਬ ਛ').first, id(85));
    });

    test('the letters match the way words do: no nukta, no tippi', () {
      // ਸ਼ਹੀਦੀ ਦਿਹਾੜਾ ਬਾਬਾ ਦੀਪ ਸਿੰਘ ਜੀ
      expect(ids('ਸਦਬਦਸ').first, id(88));
      expect(ids('ਸ਼ਦਬਦਸ').first, id(88));
    });

    test('a title with the first letters at its start comes first', () {
      final index = names(['ਬੰਦੀ ਛੋੜ ਦਿਵਸ', 'ਛੋਟਾ ਦਿਨ']);

      expect(index.search('ਛਦ'), ['ਛੋਟਾ ਦਿਨ', 'ਬੰਦੀ ਛੋੜ ਦਿਵਸ']);
    });

    test(
        'first letters from the middle of a title are found, after the '
        'rest', () {
      expect(ids('ਛਦ'), contains(id(85)));
    });

    test('only the first letter of each word counts', () {
      final index = names(['ਗੁਰ ਦਿਵਸ']);

      expect(index.search('ਗਦ'), ['ਗੁਰ ਦਿਵਸ']);
      expect(index.search('ਗਰ'), isEmpty, reason: 'ਰ is not a first letter');
    });

    test('a query with a vowel sign is a word, not first letters', () {
      final index = names(['ਗੁਰ ਦਿਵਸ']);

      expect(index.search('ਗੁਦ'), isEmpty);
      expect(index.search('ਗਦ'), hasLength(1));
    });

    test('a word is found as a word before first letters', () {
      final index = names(['ਸਬ ਦੇ', 'ਸ਼ਹੀਦੀ ਬਾਬਾ ਦੀਪ', 'ਸਬਦ']);

      // "ਸਬ" has no vowel sign: it is the word ਸਬ, and also the first
      // letters of ਸ਼ਹੀਦੀ ਬਾਬਾ.
      expect(index.search('ਸਬ'), ['ਸਬ ਦੇ', 'ਸਬਦ', 'ਸ਼ਹੀਦੀ ਬਾਬਾ ਦੀਪ']);
    });

    test('the first letters of a title in English are not searched', () {
      final index = names(['Bandi Chhor Divas']);

      expect(index.search('ਬਛਦ'), isEmpty);
    });
  });
}
