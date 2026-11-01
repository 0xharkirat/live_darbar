import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/media_session/voice_query.dart';
import 'package:live_darbar/src/models/source_index.dart';

/// What "Hey Google, play ... on Live Darbar" turns into.
void main() {
  group('sourceForQuery', () {
    test('every live word asks for live', () {
      for (final word in liveWords) {
        expect(sourceForQuery(word), kLiveIndex, reason: word);
      }
    });

    test('live phrases ask for live', () {
      expect(sourceForQuery('live kirtan'), kLiveIndex);
      expect(sourceForQuery('kirtan from Harmandir Sahib'), kLiveIndex);
      expect(sourceForQuery('play Live Darbar'), kLiveIndex);
      expect(sourceForQuery('darbar sahib'), kLiveIndex);
    });

    test('Hukamnama words ask for the Hukamnama', () {
      for (final word in [
        'hukamnama',
        'Hukamnama',
        "today's hukamnama",
        'hukam',
        'hukum',
        'hukumnama',
        'mukhwak',
        'mukhvak',
        'Mukhwak Sahib',
      ]) {
        expect(sourceForQuery(word), kMukhwakIndex, reason: word);
      }
    });

    test('speech engines spell Mukhwak many ways', () {
      for (final spoken in [
        'mukhwaak',
        'Mukhwaak Sahib',
        'mukh wak',
        'Mukh Wak',
        'mukh-wak',
        'mukh waak',
        'mukhvaak',
        'mukh vak',
        'MUKHWAAK.',
        "today's mukh wak!",
        'play mukhwaak on Live Darbar',
        'mukwak',
        'hukmnama',
        'hukamnaama',
        'hukumnaama',
      ]) {
        expect(sourceForQuery(spoken), kMukhwakIndex, reason: spoken);
      }
    });

    test('Gurmukhi spellings with a space, addak or tippi work', () {
      for (final spoken in [
        'ਮੁੱਖ ਵਾਕ',
        'ਮੁੱਖ  ਵਾਕ',
        'ਮੁਖ ਵਾਕ',
        'ਮੁਖਵਾਕ',
        'ਮੁੱਖਵਾਕ',
        'ਅੱਜ ਦਾ ਮੁੱਖ ਵਾਕ',
        'ਹੁਕਮ ਨਾਮਾ',
        'ਹੁਕਮਨਾਮਾ',
      ]) {
        expect(sourceForQuery(spoken), kMukhwakIndex, reason: spoken);
      }
    });

    test('Katha keeps winning over a Mukhwak spelling', () {
      expect(sourceForQuery('mukh wak katha'), kKathaIndex);
      expect(sourceForQuery('mukhwaak kathaa'), kKathaIndex);
      expect(sourceForQuery('ਮੁੱਖ ਵਾਕ ਕਥਾ'), kKathaIndex);
      expect(sourceForQuery('ਕੱਥਾ'), kKathaIndex);
    });

    test('Katha words ask for the Katha', () {
      for (final word in ['katha', 'Katha', 'daily katha', 'katha today']) {
        expect(sourceForQuery(word), kKathaIndex, reason: word);
      }
    });

    test('Punjabi words work', () {
      expect(sourceForQuery('ਲਾਈਵ'), kLiveIndex);
      expect(sourceForQuery('ਕੀਰਤਨ'), kLiveIndex);
      expect(sourceForQuery('ਲਾਈਵ ਕੀਰਤਨ ਚਲਾਓ'), kLiveIndex);
      expect(sourceForQuery('ਹੁਕਮਨਾਮਾ'), kMukhwakIndex);
      expect(sourceForQuery('ਅੱਜ ਦਾ ਹੁਕਮਨਾਮਾ'), kMukhwakIndex);
      expect(sourceForQuery('ਮੁਖਵਾਕ'), kMukhwakIndex);
      expect(sourceForQuery('ਮੁੱਖਵਾਕ'), kMukhwakIndex);
      expect(sourceForQuery('ਕਥਾ'), kKathaIndex);
      expect(sourceForQuery('ਹੁਕਮਨਾਮਾ ਕਥਾ'), kKathaIndex);
    });

    test('case and padding do not matter', () {
      expect(sourceForQuery('  KATHA  '), kKathaIndex);
      expect(sourceForQuery('HUKAMNAMA'), kMukhwakIndex);
      expect(sourceForQuery('\tLIVE\n'), kLiveIndex);
    });

    test('an empty or missing query plays live', () {
      expect(sourceForQuery(null), kLiveIndex);
      expect(sourceForQuery(''), kLiveIndex);
      expect(sourceForQuery('   '), kLiveIndex);
    });

    test('a query nobody expects plays live', () {
      expect(sourceForQuery('some music'), kLiveIndex);
      expect(sourceForQuery('taylor swift'), kLiveIndex);
      expect(sourceForQuery('12345'), kLiveIndex);
    });

    test('the Katha beats the Hukamnama, because it is named after it', () {
      expect(sourceForQuery('mukhwak katha'), kKathaIndex);
      expect(sourceForQuery('hukamnama katha'), kKathaIndex);
    });

    test('a specific word beats the app name left inside the query', () {
      expect(sourceForQuery('katha on Live Darbar'), kKathaIndex);
      expect(sourceForQuery('hukamnama on Live Darbar'), kMukhwakIndex);
      expect(sourceForQuery('live kirtan on Live Darbar'), kLiveIndex);
    });
  });

  group('normaliseQuery', () {
    test('lowercases and drops spaces and punctuation', () {
      expect(normaliseQuery('  Mukh-Wak!  '), 'mukhwak');
      expect(normaliseQuery("Today's  Katha."), 'todayskatha');
      expect(normaliseQuery(null), '');
      expect(normaliseQuery(''), '');
    });

    test('cuts a run of the same Latin vowel to one', () {
      expect(normaliseQuery('mukhwaak'), 'mukhwak');
      expect(normaliseQuery('hukamnaama'), 'hukamnama');
      expect(normaliseQuery('kathaa'), 'katha');
      expect(normaliseQuery('keertan'), 'kertan');
    });

    test('drops the Gurmukhi marks that spellings disagree on', () {
      expect(normaliseQuery('ਮੁੱਖ ਵਾਕ'), 'ਮੁਖਵਾਕ');
      expect(normaliseQuery('ਮੁੱਖਵਾਕ'), normaliseQuery('ਮੁਖਵਾਕ'));
      expect(normaliseQuery('ਸੰਗਤ'), normaliseQuery('ਸਗਤ'));
    });

    test('leaves consonants and other letters alone', () {
      expect(normaliseQuery('Katha'), 'katha');
      expect(normaliseQuery('12345'), '12345');
      expect(normaliseQuery('ਕਥਾ'), 'ਕਥਾ');
    });
  });

  group('matchQuery', () {
    test('names the source a keyword asks for', () {
      expect(matchQuery('katha'), kKathaIndex);
      expect(matchQuery('mukh wak'), kMukhwakIndex);
      expect(matchQuery('ਮੁੱਖ ਵਾਕ'), kMukhwakIndex);
      expect(matchQuery('kirtan'), kLiveIndex);
      expect(matchQuery('keertan'), kLiveIndex);
      expect(matchQuery('Live Darbar'), kLiveIndex);
    });

    test('is null when no keyword is in the query', () {
      expect(matchQuery('weather'), isNull);
      expect(matchQuery('what is the weather today'), isNull);
      expect(matchQuery('taylor swift'), isNull);
      expect(matchQuery('12345'), isNull);
      expect(matchQuery(''), isNull);
      expect(matchQuery('   '), isNull);
      expect(matchQuery('...'), isNull);
      expect(matchQuery(null), isNull);
    });

    test('agrees with sourceForQuery wherever it finds a match', () {
      for (final query in ['katha', 'hukam', 'live', 'mukhwaak', 'ਕਥਾ']) {
        expect(sourceForQuery(query), matchQuery(query), reason: query);
      }
    });
  });

  group('sourceForMediaId', () {
    test('the published ids name their source', () {
      expect(sourceForMediaId('0'), kLiveIndex);
      expect(sourceForMediaId('1'), kMukhwakIndex);
      expect(sourceForMediaId('2'), kKathaIndex);
    });

    test('readable ids work', () {
      expect(sourceForMediaId('live'), kLiveIndex);
      expect(sourceForMediaId('hukamnama'), kMukhwakIndex);
      expect(sourceForMediaId('katha'), kKathaIndex);
    });

    test('an unknown id plays live', () {
      expect(sourceForMediaId(null), kLiveIndex);
      expect(sourceForMediaId(''), kLiveIndex);
      expect(sourceForMediaId('7'), kLiveIndex);
      expect(sourceForMediaId('-1'), kLiveIndex);
      expect(sourceForMediaId('root'), kLiveIndex);
    });
  });
}
