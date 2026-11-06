/// Folds text to a key that a search compares, so spellings that sound the same
/// are equal.
///
/// Punjabi has no fixed spelling in Latin letters, and in Gurmukhi a listener
/// who types fast drops a tippi or picks the wrong long vowel. A search that
/// asks for the exact letters finds nothing for "bandhi chor" or "ਬਦੀ ਛੋਡ". So
/// both the titles and the query go through [searchWords] first.
///
/// Pure Dart, no Flutter: `test/core/search_fold_test.dart` pins every rule.
///
/// ## Latin letters
///
/// - Case and diacritics go: "Bandī Chhoṛ" is "bandi chor".
/// - An h after a consonant goes: "bandhi", "chhor", "singh", "sikh", "tegh",
///   "bhai" are "bandi", "cor", "sing", "sik", "teg", "bai". An h after a vowel
///   stays, because "sahib" and "saib" are not the same word.
/// - v and w are b, z is j, f is p, q is k.
/// - e is i and o is u, so "Fateh" is "Fatih" and "Gobind" is "Govind".
/// - "au" is u: "Kaur", "Kour" and "Kor" are 1 word.
/// - A y after a consonant goes ("Jyoti" is "Joti"). A y after a vowel is an i
///   ("Bhay" is "Bhai").
/// - A doubled letter is 1 letter. With the rule above this makes aa, ee, ii,
///   oo and uu the same as a, i, i, u and u. Digits are not collapsed.
///
/// ## Gurmukhi
///
/// - Nukta goes, joined (ਸ਼) or apart (ਸ + ਼). So do tippi, bindi, addak and the
///   subscript sign: "ਸਿੱਖ" is "ਸਿਖ" and "ਬੰਦੀ" is "ਬਦੀ".
/// - Vowel signs that sound alike are 1 sign: ਿ and ੀ, ੁ and ੂ, ੇ and ੈ and ਿ
///   (as e is i above), ੋ and ੌ and ੁ.
/// - An independent vowel is its sign on a carrier, and all 3 carriers
///   (ਅ, ੳ, ੲ) are ਅ. So ਇ and ੲਿ are the same.
/// - ੜ is ਡ, which is what most keyboards give.
/// - Gurmukhi digits are digits.
///
/// Nothing turns Latin into Gurmukhi or back. A search for "bandi" finds the
/// English title, and a search for "ਬੰਦੀ" finds the Punjabi one.
library;

/// The words of [text] as keys, in order. Empty when [text] holds no letter or
/// digit.
///
/// A word ends at a space, a hyphen, a bracket, a full stop and any other mark.
/// An apostrophe is inside its word. See the library notes for the folding.
List<String> searchWords(String text) {
  final words = <String>[];
  final word = StringBuffer();

  void flush() {
    if (word.isEmpty) return;
    final folded = _foldWord(word.toString());
    if (folded.isNotEmpty) words.add(folded);
    word.clear();
  }

  for (final rune in text.toLowerCase().runes) {
    final folded = _foldRune(rune);
    if (folded == null) {
      flush();
    } else {
      word.write(folded);
    }
  }
  flush();
  return words;
}

/// [searchWords] joined with 1 space.
String searchKey(String text) => searchWords(text).join(' ');

/// Whether [unit] is a Gurmukhi letter that a word can start with, after
/// folding: the carrier ਅ or a consonant. A vowel sign or a digit is not.
bool isGurmukhiLetter(int unit) =>
    unit == _carrier || (unit >= 0x0A15 && unit <= 0x0A39);

const _carrier = 0x0A05; // ਅ
const _sihari = 0x0A3F; // ਿ
const _aunkar = 0x0A41; // ੁ
const _kanna = 0x0A3E; // ਾ

/// What 1 character becomes: a string to add to the word (empty to drop the
/// character without ending the word), or null to end the word.
String? _foldRune(int rune) {
  if (rune >= 0x61 && rune <= 0x7A) return String.fromCharCode(rune);
  if (rune >= 0x30 && rune <= 0x39) return String.fromCharCode(rune);
  if (rune >= 0x0A00 && rune <= 0x0A7F) return _gurmukhi[rune];
  // Combining marks, so "ī" typed as "i" and a macron folds the same.
  if (rune >= 0x0300 && rune <= 0x036F) return '';
  // Joiners and the byte order mark are not letters.
  if ((rune >= 0x200B && rune <= 0x200D) || rune == 0xFEFF) return '';
  // An apostrophe stays inside its word.
  if (rune == 0x27 || rune == 0x60 || rune == 0xB4) return '';
  if (rune == 0x2018 || rune == 0x2019 || rune == 0x02BC) return '';
  return _latin[rune];
}

/// Latin letters with a mark, by the letter they fold to. The text is
/// lower-cased before it gets here. The letters come from the romanisations
/// of Punjabi (ISO 15919, IAST) and from Latin-1.
const _latinBases = {
  'a': 'àáâãäåāăąǎạảắằấầ',
  'c': 'çćĉċč',
  'd': 'ďđḍḏð',
  'e': 'èéêëēĕėęěẹẻẽếềệ',
  'g': 'ĝğġģǵ',
  'h': 'ĥħḥḫ',
  'i': 'ìíîïĩīĭįıǐỉị',
  'j': 'ĵ',
  'k': 'ķḳḵ',
  'l': 'ĺļľŀłḷḹḻ',
  'm': 'ḿṁṃ',
  'n': 'ñńņňŉŋṅṇṉ',
  'o': 'òóôõöøōŏőǒọỏốồổỗộớờ',
  'r': 'ŕŗřṛṝṟ',
  's': 'śŝşšșṣṡ',
  't': 'ţťŧțṭṯ',
  'u': 'ùúûüũūŭůűųǔụủứừ',
  'w': 'ŵ',
  'y': 'ýÿŷ',
  'z': 'źżžẓ',
};

final Map<int, String> _latin = {
  for (final entry in _latinBases.entries)
    for (final rune in entry.value.runes) rune: entry.key,
  0xDF: 'ss', // ß
  0xE6: 'ae', // æ
  0x153: 'oe', // œ
  0xFE: 'th', // þ
};

/// The Gurmukhi block (U+0A00 to U+0A7F): what each character becomes. A
/// character that is not here (the Ik Onkar sign, the abbreviation sign) ends
/// a word.
final Map<int, String> _gurmukhi = _buildGurmukhi();

Map<int, String> _buildGurmukhi() {
  final table = <int, String>{};
  String chars(List<int> units) => String.fromCharCodes(units);

  // Consonants as they are: ਕ to ਨ, ਪ to ਰ, ਲ, ਵ, ਸ, ਹ.
  for (final unit in [
    for (var u = 0x0A15; u <= 0x0A28; u++) u,
    for (var u = 0x0A2A; u <= 0x0A30; u++) u,
    0x0A32,
    0x0A35,
    0x0A38,
    0x0A39,
  ]) {
    table[unit] = chars([unit]);
  }
  // Consonants with a nukta, as 1 character, are the consonant. ੜ is ਡ.
  table[0x0A33] = chars([0x0A32]); // ਲ਼
  table[0x0A36] = chars([0x0A38]); // ਸ਼
  table[0x0A59] = chars([0x0A16]); // ਖ਼
  table[0x0A5A] = chars([0x0A17]); // ਗ਼
  table[0x0A5B] = chars([0x0A1C]); // ਜ਼
  table[0x0A5C] = chars([0x0A21]); // ੜ
  table[0x0A5E] = chars([0x0A2B]); // ਫ਼

  // Marks that do not count: bindi (3), nukta, subscript sign, udaat, tippi,
  // addak, yakash.
  for (final unit in [
    0x0A01,
    0x0A02,
    0x0A03,
    0x0A3C,
    0x0A4D,
    0x0A51,
    0x0A70,
    0x0A71,
    0x0A75,
  ]) {
    table[unit] = '';
  }

  // Vowel signs, with the ones that sound alike folded together.
  table[_kanna] = chars([_kanna]);
  for (final unit in [0x0A3F, 0x0A40, 0x0A47, 0x0A48]) {
    table[unit] = chars([_sihari]); // ਿ ੀ ੇ ੈ
  }
  for (final unit in [0x0A41, 0x0A42, 0x0A4B, 0x0A4C]) {
    table[unit] = chars([_aunkar]); // ੁ ੂ ੋ ੌ
  }

  // Independent vowels are a sign on the carrier.
  table[0x0A05] = chars([_carrier]); // ਅ
  table[0x0A06] = chars([_carrier, _kanna]); // ਆ
  for (final unit in [0x0A07, 0x0A08, 0x0A0F, 0x0A10]) {
    table[unit] = chars([_carrier, _sihari]); // ਇ ਈ ਏ ਐ
  }
  for (final unit in [0x0A09, 0x0A0A, 0x0A13, 0x0A14]) {
    table[unit] = chars([_carrier, _aunkar]); // ਉ ਊ ਓ ਔ
  }
  table[0x0A72] = chars([_carrier]); // ੲ
  table[0x0A73] = chars([_carrier]); // ੳ

  // Gurmukhi digits are digits.
  for (var i = 0; i < 10; i++) {
    table[0x0A66 + i] = '$i';
  }
  return table;
}

/// Folds 1 word of already-folded characters. The Latin sound rules need the
/// letters around a letter, so they run on the whole word.
String _foldWord(String word) {
  // An h after a consonant goes. "chhor": the first h follows the c, and the
  // second follows an h that went, so both go.
  final noH = StringBuffer();
  var previous = 0;
  for (var i = 0; i < word.length; i++) {
    final c = word.codeUnitAt(i);
    if (c == _h && _isConsonant(previous)) {
      previous = c;
      continue;
    }
    noH.writeCharCode(c);
    previous = c;
  }
  final s = noH.toString();

  final out = <int>[];
  for (var i = 0; i < s.length; i++) {
    var c = s.codeUnitAt(i);
    switch (c) {
      case 0x76 || 0x77: // v w
        c = 0x62; // b
      case 0x7A: // z
        c = 0x6A; // j
      case 0x66: // f
        c = 0x70; // p
      case 0x71: // q
        c = 0x6B; // k
      case 0x65: // e
        c = 0x69; // i
      case 0x6F: // o
        c = 0x75; // u
      case 0x79: // y
        final before = i > 0 ? s.codeUnitAt(i - 1) : 0;
        final after = i + 1 < s.length ? s.codeUnitAt(i + 1) : 0;
        if (_isVowel(before)) {
          c = 0x69; // Bhay is Bhai.
        } else if (_isConsonant(before) && _isVowel(after)) {
          continue; // Jyoti is Joti.
        } else if (_isConsonant(before)) {
          c = 0x69; // A y that ends a word or leads a consonant is an i.
        }
    }
    // "au" is u.
    if (c == 0x75 && out.isNotEmpty && out.last == 0x61) out.removeLast();
    // A doubled letter is 1 letter. Digits stay as typed.
    if (out.isNotEmpty && out.last == c && c >= 0x61 && c <= 0x7A) continue;
    out.add(c);
  }
  return String.fromCharCodes(out);
}

const _h = 0x68;

bool _isVowel(int c) =>
    c == 0x61 || c == 0x65 || c == 0x69 || c == 0x6F || c == 0x75;

bool _isConsonant(int c) => c >= 0x61 && c <= 0x7A && !_isVowel(c);
