import 'package:live_darbar/src/models/source_index.dart';

/// Words that ask for the Katha. Checked first.
///
/// The Katha is called "Mukhwak Katha" in places, which holds a Hukamnama
/// word as well. The longer ask must win, so this list is read before the
/// Hukamnama list.
///
/// Every list is written the way a person would write it and is normalised
/// with [normaliseQuery] once, so a word here matches however a speech engine
/// spells it.
const _kathaWords = <String>[
  'katha',
  'ਕਥਾ',
];

/// Words that ask for the daily Hukamnama.
const _hukamnamaWords = <String>[
  'hukam', // hukamnama, hukamnamah, hukam today
  'hukum', // hukumnama
  'hukm', // hukmnama
  'mukhwak', // also "mukh wak" and "mukhwaak"
  'mukhvak',
  'mukwak',
  'mukvak',
  'ਹੁਕਮ', // ਹੁਕਮਨਾਮਾ
  'ਮੁਖਵਾਕ', // also ਮੁੱਖਵਾਕ and "ਮੁੱਖ ਵਾਕ"
];

/// Words that ask for the live stream.
///
/// Live is also the answer to every query that [sourceForQuery] does not
/// understand, so these change nothing there. They matter to [matchQuery],
/// which reports a search that names live as a match and one that names
/// nothing as none.
const liveWords = <String>[
  'live',
  'kirtan',
  'keertan', // the common spelling of ਕੀਰਤਨ
  'darbar',
  'harmandir',
  'ਲਾਈਵ',
  'ਕੀਰਤਨ',
  'ਦਰਬਾਰ',
  'ਹਰਿਮੰਦਰ',
];

final _kathaKeys = _normaliseAll(_kathaWords);
final _hukamnamaKeys = _normaliseAll(_hukamnamaWords);
final _liveKeys = _normaliseAll(liveWords);

List<String> _normaliseAll(List<String> words) =>
    [for (final word in words) normaliseQuery(word)];

/// Spaces, punctuation and symbols, in any script. A speech engine splits
/// "mukhwak" into "mukh wak" and puts a full stop after a sentence, and
/// neither says anything about the source.
final _separators = RegExp(r'[\s\p{P}\p{S}]', unicode: true);

/// The Gurmukhi marks that spellings of the same word disagree on: candrabindu
/// (U+0A01), bindi (U+0A02), nukta (U+0A3C), tippi (U+0A70) and addak
/// (U+0A71). "ਮੁੱਖਵਾਕ" and "ਮੁਖਵਾਕ" are the same word to a listener.
final _gurmukhiVariance = RegExp('[ਁਂ਼ੰੱ]');

/// A run of the same Latin vowel, as in "mukhwaak" or "hukamnaama".
final _doubledVowel = RegExp(r'([aeiou])\1+');

/// [query] in the one form that every keyword is compared in.
///
/// Lower case, with no spaces or punctuation, no Gurmukhi addak, tippi or
/// bindi, and each run of a doubled Latin vowel cut to one. "Mukh-Waak!",
/// "mukh wak" and "mukhwak" all become "mukhwak", and "ਮੁੱਖ ਵਾਕ" becomes
/// "ਮੁਖਵਾਕ".
String normaliseQuery(String? query) {
  return (query ?? '')
      .toLowerCase()
      .replaceAll(_separators, '')
      .replaceAll(_gurmukhiVariance, '')
      .replaceAllMapped(_doubledVowel, (match) => match[1]!);
}

bool _mentionsAny(String text, List<String> keys) => keys.any(text.contains);

/// Which source a spoken or typed [query] names, or null when it names none.
///
/// Katha comes before Hukamnama, and both come before live. "Live Darbar" is
/// the name of the app, so Assistant can leave it inside the query, as in
/// "katha on Live Darbar". The specific word has to win over the app name.
///
/// A search uses this to tell a query it can answer from one it cannot.
/// [sourceForQuery] uses it to play something anyway.
int? matchQuery(String? query) {
  final text = normaliseQuery(query);
  if (text.isEmpty) return null;
  if (_mentionsAny(text, _kathaKeys)) return kKathaIndex;
  if (_mentionsAny(text, _hukamnamaKeys)) return kMukhwakIndex;
  if (_mentionsAny(text, _liveKeys)) return kLiveIndex;
  return null;
}

/// Which source a spoken or typed [query] asks to play.
///
/// Returns [kKathaIndex], [kMukhwakIndex] or [kLiveIndex].
///
/// - A query with a Katha word gives the Katha.
/// - A query with a Hukamnama word gives the Hukamnama.
/// - Every other query gives live, and so does an empty or null one. A
///   driver who says "play Live Darbar" should hear kirtan, not an error.
///
/// The words are compared after [normaliseQuery], so "mukhwaak", "mukh wak"
/// and "ਮੁੱਖ ਵਾਕ" all give the Hukamnama.
int sourceForQuery(String? query) => matchQuery(query) ?? kLiveIndex;

/// Which source a media id names.
///
/// The ids the app publishes are the source indexes as strings, "0", "1" and
/// "2". Anything else goes through [sourceForQuery], so the readable ids
/// "live", "hukamnama" and "katha" work, and an id nobody knows plays live.
int sourceForMediaId(String? mediaId) {
  final id = (mediaId ?? '').trim();
  final index = int.tryParse(id);
  if (index != null && kSourceIndexes.contains(index)) return index;
  return sourceForQuery(id);
}
