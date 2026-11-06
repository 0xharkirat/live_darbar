import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/core/search_fold.dart';

/// What a search compares: 1 key for each word, with the spellings that mean
/// the same sound folded together.
void main() {
  /// Every spelling in [spellings] must fold to the same key.
  void sameKey(List<String> spellings) {
    final first = searchKey(spellings.first);
    expect(first, isNotEmpty, reason: spellings.first);
    for (final spelling in spellings) {
      expect(searchKey(spelling), first, reason: spelling);
    }
  }

  group('words', () {
    test('splits on spaces, hyphens and punctuation', () {
      expect(searchWords('Joti-Jot Divas (Diwali)'), hasLength(4));
      expect(searchWords('S. Bhagat Singh'), hasLength(3));
      expect(searchWords('Subeg Singh & Shahbaz Singh'), hasLength(4));
    });

    test('is empty for nothing worth comparing', () {
      expect(searchWords(''), isEmpty);
      expect(searchWords('   '), isEmpty);
      // The dash is an em dash, as SGPC's English titles use.
      expect(searchWords('()\u2014&.'), isEmpty);
      expect(searchKey('  \n '), '');
    });

    test('the key is the words with 1 space between', () {
      expect(searchKey('  Bandi    Chhor '), searchKey('bandi chhor'));
      expect(searchKey('bandi chhor').split(' '), hasLength(2));
    });

    test('an apostrophe stays inside its word', () {
      sameKey(["Guru's", 'Gurus', 'Guru’s']);
    });
  });

  group('Latin', () {
    test('case does not matter', () {
      sameKey(['Bandi Chhor', 'BANDI CHHOR', 'bandi chhor']);
    });

    test('diacritics do not matter', () {
      sameKey(['Bandī Chhoṛ', 'Bandi Chhor']);
      sameKey(['Śahīdī', 'Shahidi']);
      sameKey(['Ḍihāṛā', 'Dihara']);
      sameKey(['Jañam', 'Janam']);
      // The same letter written as a base and a combining mark.
      sameKey(['Bandī', 'Bandī', 'Bandi']);
    });

    test('doubled letters do not matter', () {
      sameKey(['Gurgaddi', 'Gurgadi', 'Gurgaddii']);
      sameKey(['Ghallughara', 'Ghalughara', 'Ghalluggara']);
    });

    test('long and short vowels are the same: aa/a, ee/i, oo/u', () {
      sameKey(['Dihaada', 'Dihada']);
      sameKey(['Shaheedi', 'Shahidi', 'Shaheedee', 'Shahiidi']);
      sameKey(['Gurpoorab', 'Gurpurab']);
      sameKey(['Jathedaar', 'Jathedar']);
    });

    test('an h after a consonant does not matter', () {
      sameKey(['Bandhi', 'Bandi']);
      sameKey(['Chhor', 'Chor', 'Chhhor']);
      sameKey(['Singh', 'Sing']);
      sameKey(['Bhai', 'Bai']);
      sameKey(['Tegh', 'Teg']);
      sameKey(['Sikh', 'Sik']);
      sameKey(['Ghallughara', 'Gallugara']);
      sameKey(['Vaishakhi', 'Vaisaki']);
      sameKey(['Dihara', 'Diharha']);
    });

    test('an h that follows a vowel stays', () {
      expect(searchKey('Sahib'), isNot(searchKey('Saib')));
      expect(searchKey('Dihada'), isNot(searchKey('Diada')));
    });

    test('v, w and b are the same', () {
      sameKey(['Diwali', 'Divali', 'Dibali']);
      sameKey(['Vaisakhi', 'Baisakhi', 'Waisakhi']);
      sameKey(['Gurpurab', 'Gurpurav']);
      sameKey(['Sawan', 'Savan']);
    });

    test('z and j are the same, and so are f and p', () {
      sameKey(['Zorawar', 'Jorawar']);
      sameKey(['Sahibzada', 'Sahibjada']);
      sameKey(['Phula', 'Fula', 'Pula']);
    });

    test('e and i are the same, and so are o and u', () {
      sameKey(['Fateh', 'Fatih']);
      sameKey(['Gobind', 'Gubind', 'Govind']);
    });

    test('au, ou and o are the same: Kaur, Kour, Kor', () {
      sameKey(['Kaur', 'Kour', 'Kor']);
    });

    test('a y after a consonant is dropped: Jyoti, Joti', () {
      sameKey(['Jyoti', 'Joti']);
      sameKey(['Dyala', 'Dala']);
    });

    test('a y after a vowel is an i: Bhay, Bhai', () {
      sameKey(['Bhay', 'Bhai', 'Bhae']);
    });

    test('words that sound different stay different', () {
      expect(searchKey('Bandi'), isNot(searchKey('Banda')));
      expect(searchKey('Guru'), isNot(searchKey('Gur')));
      expect(searchKey('Singh'), isNot(searchKey('Sangh')));
    });

    test('digits stay as they are, and are not collapsed', () {
      expect(searchKey('Ghallughara (1984)'), endsWith(' 1984'));
      expect(searchKey('100'), '100');
      expect(searchKey('558'), '558');
    });
  });

  group('Gurmukhi', () {
    test('a nukta does not matter, joined or apart', () {
      // ਸ਼ as 1 character (U+0A36), as ਸ and a nukta (U+0A3C), and plain.
      sameKey(['ਸ਼ਹੀਦੀ', 'ਸ਼ਹੀਦੀ', 'ਸਹੀਦੀ']);
      sameKey(['ਖ਼ਾਲਸਾ', 'ਖਾਲਸਾ']);
      sameKey(['ਫ਼ਤਿਹ', 'ਫਤਿਹ']);
      sameKey(['ਸਾਹਿਬਜ਼ਾਦਾ', 'ਸਾਹਿਬਜਾਦਾ']);
    });

    test('tippi, bindi and addak do not matter', () {
      sameKey(['ਬੰਦੀ', 'ਬਦੀ']);
      sameKey(['ਸਿੱਖ', 'ਸਿਖ']);
      sameKey(['ਸਿੰਘ', 'ਸਿਘ', 'ਸਿਂਘ']);
      sameKey(['ਘੱਲੂਘਾਰਾ', 'ਘਲੂਘਾਰਾ']);
      sameKey(['ਸੰਗਰਾਂਦ', 'ਸਗਰਾਦ']);
    });

    test('the vowel signs that sound alike are the same', () {
      sameKey(['ਸਾਹਿਬ', 'ਸਾਹੀਬ']);
      sameKey(['ਗੁਰੂ', 'ਗੁਰੁ']);
      sameKey(['ਗੋਬਿੰਦ', 'ਗੁਬਿੰਦ']);
      sameKey(['ਫ਼ਤਿਹ', 'ਫ਼ਤੇਹ']);
      sameKey(['ਕੌਰ', 'ਕੋਰ']);
      sameKey(['ਭੈ', 'ਭੇ']);
    });

    test('an independent vowel is its sign on a carrier', () {
      sameKey(['ਆਸਾ', 'ਅਾਸਾ']);
      sameKey(['ਇਹ', 'ੲਿਹ']);
      sameKey(['ਉਹ', 'ੳੁਹ']);
    });

    test('ੜ is read as ਡ, as most keyboards give it', () {
      sameKey(['ਛੋੜ', 'ਛੋਡ']);
    });

    test('a subscript sign is dropped', () {
      sameKey(['ਸ੍ਰੀ', 'ਸਰੀ']);
      sameKey(['ਕਿਲ੍ਹਾ', 'ਕਿਲਹਾ']);
    });

    test('Gurmukhi digits are digits', () {
      expect(searchKey('੧੯੮੪'), '1984');
      expect(searchKey('(੪੦੦ ਸਾਲਾ)'), startsWith('400 '));
    });

    test('words that sound different stay different', () {
      expect(searchKey('ਬੰਦੀ'), isNot(searchKey('ਬੰਦਾ')));
      expect(searchKey('ਸਾਹਿਬ'), isNot(searchKey('ਸਾਹਬ')));
    });

    test('the 2 scripts are not mixed up', () {
      expect(searchKey('bandi'), isNot(searchKey('ਬੰਦੀ')));
    });
  });
}
