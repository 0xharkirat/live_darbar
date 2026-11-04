/// Today's Hukamnama from Darbar Sahib, as text.
///
/// The Hukamnama is the shabad that opens at random from Sri Guru Granth Sahib
/// Ji at Sri Harmandir Sahib each morning. The app already plays the Mukhwak
/// audio and shows SGPC's PDF; this is the same shabad as text, from the same
/// SGPC feed.
library;

import 'package:live_darbar/src/core/display_text.dart';
import 'package:live_darbar/src/models/sgpc_day.dart';

/// Name of the body that publishes the text. A screen that shows it should say
/// where it comes from near the text.
const kHukamnamaSourceName = 'SGPC';

/// See [kHukamnamaSourceName]. The credit under the text links here, and the
/// web app links here when its copy of the text cannot be loaded.
const kHukamnamaSourceUrl = 'https://www.sgpc.net';

/// One line of the shabad.
///
/// SGPC gives the meanings as whole blocks and not line by line, so for now
/// only [gurmukhi] is set and the three translations stay null. They stay on
/// the class so a screen can already show a line with or without them.
class HukamnamaLine {
  const HukamnamaLine({
    required this.gurmukhi,
    this.punjabi,
    this.english,
    this.transliteration,
  });

  /// The line in Unicode Gurmukhi, with its `॥` and verse number.
  final String gurmukhi;

  /// The Punjabi meaning of this line. Null: SGPC does not split it by line.
  /// See [Hukamnama.punjabiMeaning].
  final String? punjabi;

  /// The English meaning of this line. Null: SGPC does not split it by line.
  /// See [Hukamnama.englishMeaning].
  final String? english;

  /// The line in Roman letters. Null: SGPC does not give one.
  final String? transliteration;

  Map<String, dynamic> toJson() => {
        'gurmukhi': gurmukhi,
        if (punjabi != null) 'punjabi': punjabi,
        if (english != null) 'english': english,
        if (transliteration != null) 'transliteration': transliteration,
      };

  factory HukamnamaLine.fromJson(Map<String, dynamic> json) {
    final gurmukhi = displayText(json['gurmukhi']);
    if (gurmukhi == null) {
      throw const FormatException('A Hukamnama line has no Gurmukhi.');
    }
    return HukamnamaLine(
      gurmukhi: gurmukhi,
      punjabi: displayText(json['punjabi']),
      english: displayText(json['english']),
      transliteration: displayText(json['transliteration']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HukamnamaLine &&
      other.gurmukhi == gurmukhi &&
      other.punjabi == punjabi &&
      other.english == english &&
      other.transliteration == transliteration;

  @override
  int get hashCode => Object.hash(gurmukhi, punjabi, english, transliteration);
}

/// The Hukamnama for one day, as SGPC publishes it.
class Hukamnama {
  const Hukamnama({
    required this.date,
    required this.lines,
    this.ang,
    this.headingGurmukhi,
    this.headingEnglish,
    this.punjabiMeaning,
    this.englishMeaning,
    this.footerGurmukhi,
    this.footerEnglish,
  });

  /// The SGPC day this text belongs to, as UTC midnight (the shape
  /// `sgpcDayOf` returns). This is the day of the text, which is not always
  /// today. Before SGPC publishes in the morning, and while the phone is
  /// offline, the best text on hand is an earlier day's. A screen must label
  /// it with this date and never present it as today's: compare with [isFor].
  final DateTime date;

  /// The page of Sri Guru Granth Sahib Ji where the shabad starts (its Ang).
  /// Null when SGPC gives none that is a page from 1 to 1430.
  final int? ang;

  /// The title of the shabad in Gurmukhi, for example `ਧਨਾਸਰੀ ਮਹਲਾ ੪॥`.
  ///
  /// SGPC keeps up to 2 heading lines (the raag and mahalla, and often
  /// `ੴ ਸਤਿਗੁਰ ਪ੍ਰਸਾਦਿ ॥`). When there are 2, they are joined with a newline,
  /// in the order SGPC gives them. Null when SGPC gives neither.
  final String? headingGurmukhi;

  /// The title in English capitals, for example `DHANAASAREE, FOURTH MEHL:`.
  /// Joined as [headingGurmukhi] is. Null when SGPC gives none.
  final String? headingEnglish;

  /// The shabad line by line, in reading order. Never empty. See
  /// [splitHukamnamaLines] for where the lines break.
  final List<HukamnamaLine> lines;

  /// The Punjabi meaning (viakhya) of the whole shabad, as SGPC prints it. One
  /// block, with `।੧।` style verse numbers. Null when SGPC gives none.
  final String? punjabiMeaning;

  /// The English meaning of the whole shabad, as SGPC prints it. One block,
  /// with `|| 1 ||` style verse numbers. Null when SGPC gives none.
  final String? englishMeaning;

  /// The Nanakshahi date line in Gurmukhi, for example
  /// `ਸੋਮਵਾਰ, ੧੭ ਕੱਤਕ (ਸੰਮਤ ੫੫੮ ਨਾਨਕਸ਼ਾਹੀ)`. Null when SGPC gives none.
  final String? footerGurmukhi;

  /// The Nanakshahi date line in English, for example
  /// `Monday, 17th Katak (Samvat 558 Nanakshahi)`. Null when SGPC gives none.
  final String? footerEnglish;

  /// Whether this is the text for [sgpcDay] (as returned by `sgpcDayOf`).
  bool isFor(DateTime sgpcDay) =>
      date == DateTime.utc(sgpcDay.year, sgpcDay.month, sgpcDay.day);

  /// Reads the `hs.sgpc.net` archive response for one day.
  ///
  /// Throws [FormatException] unless the body is a full Hukamnama: `supported`
  /// must be true, and the text must have a date that is a real day and some
  /// Gurmukhi. A response that is empty, has no text, or cannot say which day
  /// it is for must not be stored or shown as today's. The caller compares
  /// [date] with the day it asked for.
  ///
  /// SGPC's fields, and where they go:
  /// - `ang` (a string such as "668"): [ang].
  /// - `ghukamnama` (the whole Gurmukhi text): [lines].
  /// - `gheading1` and `gheading2`, `eheading1` and `eheading2`:
  ///   [headingGurmukhi] and [headingEnglish].
  /// - `ghukamnamadesc` and `ehukamnamadesc`: [punjabiMeaning] and
  ///   [englishMeaning].
  /// - `gfooter1` and `efooter1`: [footerGurmukhi] and [footerEnglish]. The
  ///   `footer2` fields only repeat the Ang, so they are not used.
  factory Hukamnama.fromSgpc(Map<String, dynamic> json) {
    if (json['supported'] != true) {
      throw const FormatException('SGPC has no Hukamnama for that day.');
    }
    final body = _map(json['hukamnama']);
    if (body == null) {
      throw const FormatException('The response has no Hukamnama.');
    }

    final date = _parseDay(body['date']);
    if (date == null) {
      throw const FormatException('The Hukamnama response has no valid date.');
    }

    final gurmukhi = displayText(body['ghukamnama']);
    if (gurmukhi == null) {
      throw const FormatException('The Hukamnama response has no Gurmukhi.');
    }
    final lines = splitHukamnamaLines(gurmukhi);
    if (lines.isEmpty) {
      throw const FormatException('The Hukamnama response has no lines.');
    }

    final ang = body['ang'];
    return Hukamnama(
      date: date,
      ang: _validAng(ang is int ? ang : int.tryParse(displayText(ang) ?? '')),
      headingGurmukhi: _joinLines([body['gheading1'], body['gheading2']]),
      headingEnglish: _joinLines([body['eheading1'], body['eheading2']]),
      lines: List.unmodifiable([
        for (final line in lines) HukamnamaLine(gurmukhi: line),
      ]),
      punjabiMeaning: displayText(body['ghukamnamadesc']),
      englishMeaning: displayText(body['ehukamnamadesc']),
      footerGurmukhi: displayText(body['gfooter1']),
      footerEnglish: displayText(body['efooter1']),
    );
  }

  /// The shape written to the on-disk cache. Read back with [fromJson].
  Map<String, dynamic> toJson() => {
        'version': _cacheVersion,
        'date': sgpcDayIso(date),
        if (ang != null) 'ang': ang,
        if (headingGurmukhi != null) 'headingGurmukhi': headingGurmukhi,
        if (headingEnglish != null) 'headingEnglish': headingEnglish,
        'lines': [for (final l in lines) l.toJson()],
        if (punjabiMeaning != null) 'punjabiMeaning': punjabiMeaning,
        if (englishMeaning != null) 'englishMeaning': englishMeaning,
        if (footerGurmukhi != null) 'footerGurmukhi': footerGurmukhi,
        if (footerEnglish != null) 'footerEnglish': footerEnglish,
      };

  /// Throws [FormatException] for anything [toJson] did not write, so a file
  /// from a future version of the app, or an early build's version 1, is a
  /// cache miss and not a crash.
  factory Hukamnama.fromJson(Map<String, dynamic> json) {
    if (json['version'] != _cacheVersion) {
      throw FormatException(
          'Unknown Hukamnama cache version ${json['version']}.');
    }
    final date = _parseDay(json['date']);
    if (date == null) {
      throw const FormatException('The cached Hukamnama has no date.');
    }
    final rows = json['lines'];
    if (rows is! List || rows.isEmpty) {
      throw const FormatException('The cached Hukamnama has no lines.');
    }
    final ang = json['ang'];
    return Hukamnama(
      date: date,
      ang: ang is int ? _validAng(ang) : null,
      headingGurmukhi: displayText(json['headingGurmukhi']),
      headingEnglish: displayText(json['headingEnglish']),
      lines: List.unmodifiable([
        for (final row in rows)
          if (row is Map<String, dynamic>)
            HukamnamaLine.fromJson(row)
          else
            throw const FormatException('A cached line is not an object.'),
      ]),
      punjabiMeaning: displayText(json['punjabiMeaning']),
      englishMeaning: displayText(json['englishMeaning']),
      footerGurmukhi: displayText(json['footerGurmukhi']),
      footerEnglish: displayText(json['footerEnglish']),
    );
  }

  @override
  String toString() => 'Hukamnama(${sgpcDayIso(date)}, ang $ang, '
      '${lines.length} lines)';
}

/// Version 2 is the shape of SGPC's text. Version 1 was an early build's shape,
/// with a raag and a writer and a meaning on each line, and is not read.
const _cacheVersion = 2;

/// The end of a verse, which is where a display line ends.
///
/// A `॥` starts it. It then takes in what SGPC prints straight after it as
/// part of the same ending, so the line keeps its markers and numbers:
/// - a verse number and `॥`, as in `॥੧॥` and the run `॥੪॥੫॥` (the verse, then
///   the shabad number);
/// - the pause, as in `॥ ਰਹਾਉ ॥` and `॥ ਰਹਾਉ ਦੂਜਾ ॥`.
/// These can chain, as in `॥੧॥ ਰਹਾਉ ॥` and `॥ ਰਹਾਉ ਦੂਜਾ ॥੧॥੩॥`.
final _verseEnd = RegExp(r'॥(?:\s*[੦-੯]+\s*॥|\s*ਰਹਾਉ(?:\s+ਦੂਜਾ)?\s*॥)*');

/// Splits SGPC's one-block Gurmukhi text into display lines.
///
/// A line ends at each `॥` that ends a verse, and keeps its verse number and
/// pause marker (see `_verseEnd`). Runs of white space become one space, and
/// the lines are trimmed. Text after the last `॥` becomes a last line, so
/// nothing is dropped. Blank input gives no lines.
///
/// Section labels that SGPC places inside the text (`ਸਲੋਕੁ ॥`, `ਛੰਤੁ ॥`) end in
/// `॥` and so come out as lines of their own.
List<String> splitHukamnamaLines(String text) {
  final lines = <String>[];
  var start = 0;
  void add(String raw) {
    final line = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (line.isNotEmpty) lines.add(line);
  }

  for (final end in _verseEnd.allMatches(text)) {
    add(text.substring(start, end.end));
    start = end.end;
  }
  add(text.substring(start));
  return lines;
}

/// The line to show when there is room for one: a card on the home screen, a
/// home screen widget.
///
/// The Rahao line if there is one, because it is the line the whole shabad
/// turns on. Otherwise the first real verse, skipping short labels such as
/// `ਸਲੋਕੁ ॥`. A shabad of short lines only gives its first line, and null means
/// [Hukamnama.lines] is empty, which a parsed Hukamnama never is.
HukamnamaLine? hukamnamaPreviewLine(Hukamnama hukamnama) {
  for (final line in hukamnama.lines) {
    if (line.gurmukhi.contains('ਰਹਾਉ')) return line;
  }
  for (final line in hukamnama.lines) {
    if (line.gurmukhi.length > 20) return line;
  }
  return hukamnama.lines.isEmpty ? null : hukamnama.lines.first;
}

/// [ang] when it is a page of Sri Guru Granth Sahib Ji (1 to 1430), else null.
int? _validAng(int? ang) => ang != null && ang >= 1 && ang <= 1430 ? ang : null;

/// A real calendar day written `yyyy-MM-dd`, as UTC midnight, or null.
///
/// `2026-13-45` has the right shape and is not a day, so the parsed date is
/// written back and compared.
DateTime? _parseDay(Object? value) {
  if (value is! String) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value.trim());
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final parsed = DateTime.utc(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return null;
  }
  return parsed;
}

Map<String, dynamic>? _map(Object? value) =>
    value is Map<String, dynamic> ? value : null;

/// The [values] that are fit to show (see [displayText]), each with its white
/// space collapsed, joined by a newline. Null when none is left.
String? _joinLines(List<Object?> values) {
  final parts = <String>[
    for (final value in values)
      if (displayText(value) case final text?) text.replaceAll(RegExp(r'\s+'), ' '),
  ];
  return parts.isEmpty ? null : parts.join('\n');
}
