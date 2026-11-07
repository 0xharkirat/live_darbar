/// A small search that forgives how Punjabi is spelled, for a list of a few
/// hundred names. Pure Dart, no Flutter.
///
/// [FuzzyIndex] holds the names of each item, in any script, and answers a
/// query with the items that fit, best first. The query and the names go
/// through the same folding (see `search_fold.dart`), so "bandhi chor" meets
/// "Bandi Chhor" and "ਬਦੀ ਛੋਡ" meets "ਬੰਦੀ ਛੋੜ". An item is found by any of its
/// names, so a list of events with an English and a Punjabi title is searched
/// in both whatever language the app is in.
///
/// ## Which items fit
///
/// Every word of the query has to fit a word of the name, in any order:
///
/// - the same word, or a word that begins with it (a word still being typed);
/// - a word 1 or 2 letters off, for a word of 4 or more letters (a typo). The
///   last word also fits the beginning of a longer word with a typo in it
///   while it is typed, from 5 letters.
///
/// The words of the query may also run together or come apart ("bandichor" for
/// "Bandi Chhor"), as long as the letters are in a row in the name.
///
/// A query of Gurmukhi consonants only, such as "ਬਛਦ", also fits a name whose
/// words begin with those letters, the way Chet's first letter search does:
/// ਬੰਦੀ ਛੋੜ ਦਿਵਸ.
///
/// ## The order
///
/// In this order, and by the calendar's order for items that tie:
///
/// 1. The name begins with the query.
/// 2. Every word of the query is a whole word or a beginning of a word of the
///    name, or the first letters begin the name's words.
/// 3. The letters of the query are inside the name, or the first letters are
///    inside the name's words.
/// 4. Some word of the query is a typo.
///
/// Inside a step: fewer letters missing or off first, then words that stand
/// side by side in the name, then a match nearer the start of the name.
library;

import 'package:live_darbar/src/core/search_fold.dart';

/// The items of a list, ready to be searched.
///
/// Build it once for a list, then call [search] for every query. A search
/// walks the whole list: for a few hundred items that costs less than a frame.
class FuzzyIndex<T> {
  /// [texts] gives the names of 1 item: its title in each language. A name that
  /// is null or has no letter is left out.
  FuzzyIndex(
    Iterable<T> items, {
    required Iterable<String?> Function(T item) texts,
  }) : _entries = [
          for (final item in items)
            _Entry(item, [
              for (final text in texts(item))
                if (_Name.tryParse(text) case final name?) name,
            ]),
        ];

  final List<_Entry<T>> _entries;

  /// The items that fit [query], best first. Empty when the query has no
  /// letter or digit in it, and when nothing fits.
  ///
  /// An item that fits by more than 1 of its names is listed once.
  List<T> search(String query) {
    final parsed = _Query.tryParse(query);
    if (parsed == null) return const [];

    final hits = <(_Rank, int, T)>[];
    for (final (order, entry) in _entries.indexed) {
      _Rank? best;
      for (final name in entry.names) {
        final rank = parsed.rank(name);
        if (rank != null && (best == null || rank.compareTo(best) < 0)) {
          best = rank;
        }
      }
      if (best != null) hits.add((best, order, entry.item));
    }
    hits.sort((a, b) {
      final byRank = a.$1.compareTo(b.$1);
      return byRank != 0 ? byRank : a.$2.compareTo(b.$2);
    });
    return [for (final hit in hits) hit.$3];
  }
}

class _Entry<T> {
  _Entry(this.item, this.names);

  final T item;
  final List<_Name> names;
}

/// One name of an item, folded.
class _Name {
  _Name._(this.words, this.compact, this.wordEnds, this.initials);

  static _Name? tryParse(String? text) {
    if (text == null) return null;
    final words = searchWords(text);
    if (words.isEmpty) return null;

    final ends = <int>{};
    var end = 0;
    for (final word in words) {
      end += word.length;
      ends.add(end);
    }
    // The first letter of each Gurmukhi word. A word that starts with a digit
    // or a Latin letter has none.
    final initials = StringBuffer();
    for (final word in words) {
      if (isGurmukhiLetter(word.codeUnitAt(0))) initials.write(word[0]);
    }
    return _Name._(words, words.join(), ends, initials.toString());
  }

  final List<String> words;

  /// The words with no space between.
  final String compact;

  /// Where a word ends in [compact].
  final Set<int> wordEnds;

  final String initials;
}

/// A query, folded.
class _Query {
  _Query._(this.words, this.compact, this.initials);

  static _Query? tryParse(String text) {
    final words = searchWords(text);
    if (words.isEmpty) return null;
    final compact = words.join();

    // First letters: 2 or more consonants, and no vowel sign, digit or Latin
    // letter. One letter is just the beginning of a word.
    final onlyLetters = compact.codeUnits.every(isGurmukhiLetter);
    return _Query._(
        words, compact, onlyLetters && compact.length >= 2 ? compact : null);
  }

  final List<String> words;
  final String compact;

  /// The first letters to look for, or null when the query is not that.
  final String? initials;

  /// How well [name] fits, or null if it does not.
  _Rank? rank(_Name name) {
    _Rank? best;
    void offer(_Rank? rank) {
      if (rank != null && (best == null || rank.compareTo(best!) < 0)) {
        best = rank;
      }
    }

    // 1. The name begins with the query. A query that ends where a word of the
    // name ends is better than one that stops inside a word.
    if (name.compact.startsWith(compact)) {
      offer(_Rank(
        _Step.begins,
        name.wordEnds.contains(compact.length) ? 0 : _prefixCost,
        0,
        0,
      ));
    }

    // 2 and 4. Each word of the query fits a word of the name.
    offer(_rankWords(name));

    // 3. The letters are inside the name, across the gaps between words.
    if (compact.length >= _minInside) {
      final at = name.compact.indexOf(compact);
      if (at > 0) offer(_Rank(_Step.inside, at / name.compact.length, 0, at));
    }

    // 2 and 3. The first letters of the name's words.
    final wanted = initials;
    if (wanted != null) {
      final at = name.initials.indexOf(wanted);
      if (at == 0) offer(_Rank(_Step.whole, _initialsCost, 0, 0));
      if (at > 0) offer(_Rank(_Step.inside, 0.5 + at / 100, 0, at));
    }
    return best;
  }

  _Rank? _rankWords(_Name name) {
    var cost = 0.0;
    var typo = false;
    var breaks = 0;
    var firstAt = 0;
    int? previousAt;

    for (final (i, word) in words.indexed) {
      _WordMatch? best;
      var bestAt = 0;
      for (final (j, candidate) in name.words.indexed) {
        final match = _matchWord(word, candidate, last: i == words.length - 1);
        if (match != null && (best == null || match.cost < best.cost)) {
          best = match;
          bestAt = j;
        }
      }
      if (best == null) return null;
      cost += best.cost;
      typo |= best.typo;
      if (previousAt == null) {
        firstAt = bestAt;
      } else if (bestAt != previousAt + 1) {
        breaks++;
      }
      previousAt = bestAt;
    }
    return _Rank(typo ? _Step.typo : _Step.whole, cost, breaks, firstAt);
  }
}

/// The steps of the order, best first.
enum _Step { begins, whole, inside, typo }

/// How well a name fits: the lower, the better. Compared by the step, then the
/// cost, then the words that stand apart, then how far from the start.
class _Rank implements Comparable<_Rank> {
  const _Rank(this.step, this.cost, this.breaks, this.firstAt);

  final _Step step;
  final double cost;
  final int breaks;
  final int firstAt;

  @override
  int compareTo(_Rank other) {
    if (step != other.step) return step.index.compareTo(other.step.index);
    if ((cost - other.cost).abs() > 1e-9) return cost.compareTo(other.cost);
    if (breaks != other.breaks) return breaks.compareTo(other.breaks);
    return firstAt.compareTo(other.firstAt);
  }
}

/// A word of the query that fits a word of the name.
class _WordMatch {
  const _WordMatch(this.cost, {required this.typo});

  final double cost;
  final bool typo;
}

/// The cost of a word that is only the beginning of a longer one.
const _prefixCost = 0.2;

/// Added to the typos in the beginning of a word, so a whole word with the
/// same typos comes first.
const _typoPrefixCost = 0.5;

/// The cost of first letters that begin the name.
const _initialsCost = 0.1;

/// The fewest letters for a query to count as inside a name.
const _minInside = 4;

/// The fewest letters of the last word for a typo in the beginning of a longer
/// word.
const _minTypoPrefix = 5;

/// How many letters may be off in a word of [length] letters.
int _allowedTypos(int length) {
  if (length <= 3) return 0;
  return length <= 7 ? 1 : 2;
}

/// How [word] of the query fits [candidate] of the name, or null.
///
/// [last] is the word that is still being typed.
_WordMatch? _matchWord(String word, String candidate, {required bool last}) {
  if (word == candidate) return const _WordMatch(0, typo: false);
  if (candidate.startsWith(word)) {
    return const _WordMatch(_prefixCost, typo: false);
  }

  // A number is not a word to forgive: 1984 is not 1948.
  if (_hasDigit(word)) return null;
  final allowed = _allowedTypos(word.length);
  if (allowed == 0) return null;

  final prefix = last && word.length >= _minTypoPrefix;
  // Too far apart in length to be within the typos.
  if (!prefix && (word.length - candidate.length).abs() > allowed) return null;
  if (prefix && word.length - candidate.length > allowed) return null;

  final distances = _distances(word, candidate);
  double? cost;
  if (distances.whole <= allowed) cost = distances.whole.toDouble();
  if (prefix && distances.prefix <= allowed) {
    final inPrefix = distances.prefix + _typoPrefixCost;
    if (cost == null || inPrefix < cost) cost = inPrefix;
  }
  return cost == null ? null : _WordMatch(cost, typo: true);
}

bool _hasDigit(String s) => s.codeUnits.any((c) => c >= 0x30 && c <= 0x39);

/// The edit distance from [a] to all of [b] (`whole`), and to the closest
/// beginning of [b] (`prefix`).
///
/// An edit is a letter added, dropped or changed, or 2 letters swapped. This is
/// the optimal string alignment distance.
({int whole, int prefix}) _distances(String a, String b) {
  final m = a.length;
  final n = b.length;
  final width = n + 1;
  final d = List<int>.filled((m + 1) * width, 0);
  for (var j = 0; j <= n; j++) {
    d[j] = j;
  }
  for (var i = 1; i <= m; i++) {
    d[i * width] = i;
    for (var j = 1; j <= n; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      var best = d[(i - 1) * width + j] + 1; // a letter dropped
      final added = d[i * width + j - 1] + 1;
      if (added < best) best = added;
      final changed = d[(i - 1) * width + j - 1] + cost;
      if (changed < best) best = changed;
      if (i > 1 &&
          j > 1 &&
          a.codeUnitAt(i - 1) == b.codeUnitAt(j - 2) &&
          a.codeUnitAt(i - 2) == b.codeUnitAt(j - 1)) {
        final swapped = d[(i - 2) * width + j - 2] + 1;
        if (swapped < best) best = swapped;
      }
      d[i * width + j] = best;
    }
  }
  var prefix = d[m * width];
  for (var j = 1; j <= n; j++) {
    final here = d[m * width + j];
    if (here < prefix) prefix = here;
  }
  return (whole: d[m * width + n], prefix: prefix);
}
