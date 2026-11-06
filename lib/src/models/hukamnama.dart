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

/// How long a pause (vishraam) is. Shabad OS writes them in the Gurmukhi text
/// as `;` (heavy), `,` (medium) and `.` (light).
enum HukamnamaPause { heavy, medium, light }

/// One pause in a line: it comes after the word at [after].
class HukamnamaVishraam {
  const HukamnamaVishraam(this.after, this.weight);

  /// The index of the word that the pause follows, counting from 0 over the
  /// white space separated parts of [HukamnamaLine.gurmukhi].
  final int after;

  final HukamnamaPause weight;

  Map<String, dynamic> toJson() => {'after': after, 'weight': weight.name};

  /// Null when [json] is not a pause that this version knows.
  static HukamnamaVishraam? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final after = json['after'];
    final weight = HukamnamaPause.values
        .where((w) => w.name == json['weight'])
        .firstOrNull;
    if (after is! int || after < 0 || weight == null) return null;
    return HukamnamaVishraam(after, weight);
  }

  @override
  bool operator ==(Object other) =>
      other is HukamnamaVishraam &&
      other.after == after &&
      other.weight == weight;

  @override
  int get hashCode => Object.hash(after, weight);
}

/// One line of the shabad.
///
/// SGPC gives the meanings as whole blocks and not line by line, so the lines
/// that come from SGPC's text set only [gurmukhi]. The lines of a
/// [HukamnamaShabad] (from Shabad OS) carry the rest.
class HukamnamaLine {
  const HukamnamaLine({
    required this.gurmukhi,
    this.punjabi,
    this.english,
    this.transliteration,
    this.id,
    this.ang,
    this.vishraam = const [],
  });

  /// The line in Unicode Gurmukhi, with its `॥` and verse number.
  final String gurmukhi;

  /// The Punjabi meaning of this line. Null: SGPC does not split it by line,
  /// and Shabad OS has none for this line. See [Hukamnama.punjabiMeaning].
  final String? punjabi;

  /// The English meaning of this line. Null: SGPC does not split it by line,
  /// and Shabad OS has none for this line. See [Hukamnama.englishMeaning].
  final String? english;

  /// The line in Roman letters. Null: neither SGPC nor the Shabad OS release
  /// that the mirror uses gives one.
  final String? transliteration;

  /// The Shabad OS id of the line. Null for a line from SGPC's text.
  final String? id;

  /// The Ang (page) that the line is on. Null for a line from SGPC's text.
  final int? ang;

  /// The pauses of the line, in order. Empty for a line from SGPC's text, and
  /// for a line with no pause.
  final List<HukamnamaVishraam> vishraam;

  Map<String, dynamic> toJson() => {
        'gurmukhi': gurmukhi,
        if (punjabi != null) 'punjabi': punjabi,
        if (english != null) 'english': english,
        if (transliteration != null) 'transliteration': transliteration,
        if (id != null) 'id': id,
        if (ang != null) 'ang': ang,
        if (vishraam.isNotEmpty)
          'vishraam': [for (final v in vishraam) v.toJson()],
      };

  factory HukamnamaLine.fromJson(Map<String, dynamic> json) {
    final gurmukhi = displayText(json['gurmukhi']);
    if (gurmukhi == null) {
      throw const FormatException('A Hukamnama line has no Gurmukhi.');
    }
    final ang = json['ang'];
    final pauses = json['vishraam'];
    return HukamnamaLine(
      gurmukhi: gurmukhi,
      punjabi: displayText(json['punjabi']),
      english: displayText(json['english']),
      transliteration: displayText(json['transliteration']),
      id: displayText(json['id']),
      ang: ang is int ? _validAng(ang) : null,
      // A pause that this version cannot read is left out. It is only a mark.
      vishraam: pauses is List
          ? List.unmodifiable([
              for (final pause in pauses)
                if (HukamnamaVishraam.tryParse(pause) case final v?) v,
            ])
          : const [],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HukamnamaLine &&
      other.gurmukhi == gurmukhi &&
      other.punjabi == punjabi &&
      other.english == english &&
      other.transliteration == transliteration &&
      other.id == id &&
      other.ang == ang &&
      _sameList(other.vishraam, vishraam);

  @override
  int get hashCode => Object.hash(
        gurmukhi,
        punjabi,
        english,
        transliteration,
        id,
        ang,
        Object.hashAll(vishraam),
      );
}

/// A name from Shabad OS, such as a writer or a section. It has the Roman
/// spelling, the Gurmukhi spelling, or both.
class HukamnamaName {
  const HukamnamaName({this.roman, this.gurmukhi});

  /// For example `Guru Ramdas` or `Raag Dhanaasree`.
  final String? roman;

  /// For example `ਗੁਰੂ ਰਾਮਦਾਸ`.
  final String? gurmukhi;

  Map<String, dynamic> toJson() => {
        if (roman != null) 'roman': roman,
        if (gurmukhi != null) 'gurmukhi': gurmukhi,
      };

  static HukamnamaName? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final name = HukamnamaName(
      roman: displayText(json['roman']),
      gurmukhi: displayText(json['gurmukhi']),
    );
    return name.roman == null && name.gurmukhi == null ? null : name;
  }

  @override
  bool operator ==(Object other) =>
      other is HukamnamaName &&
      other.roman == roman &&
      other.gurmukhi == gurmukhi;

  @override
  int get hashCode => Object.hash(roman, gurmukhi);
}

/// The Hukamnama shabad line by line, with facts about it, from the Shabad OS
/// database (shabados.com).
///
/// The mirror job adds it to a day's file as the optional `shabad` and `lines`
/// keys (tool/hukamnama_data_README.md has the shape). It is there only when
/// the job matched SGPC's text to the database with high confidence. So
/// [Hukamnama.shabad] is null for a day with no match, for a day that was
/// mirrored before this existed, for every answer read from SGPC itself, and
/// when the keys cannot be read. Nothing here is needed to show the Hukamnama.
///
/// The Gurmukhi of these [lines] is the database's. It can differ from SGPC's
/// text by a letter or two, where the two sources print a word differently.
class HukamnamaShabad {
  const HukamnamaShabad({
    required this.lines,
    required this.ids,
    required this.ang,
    required this.angEnd,
    this.sections = const [],
    this.writers = const [],
    this.credits = const {},
    this.source,
    this.version,
    this.similarity,
  });

  /// The lines, in reading order. Never empty.
  final List<HukamnamaLine> lines;

  /// The Shabad OS ids of the shabad (a Hukamnama can cover more than one).
  final List<String> ids;

  /// The Ang (page) where the shabad starts.
  final int ang;

  /// The Ang where it ends. The same as [ang] for a shabad on one page.
  final int angEnd;

  /// The raag or other section of Sri Guru Granth Sahib Ji, for example
  /// `Raag Dhanaasree`.
  final List<HukamnamaName> sections;

  /// The writers (Gurus and Bhagats) of the shabad.
  final List<HukamnamaName> writers;

  /// Who made each kind of data, for the credit on a screen. The keys are
  /// `gurmukhi`, `vishraam`, `english` and `punjabi`.
  final Map<String, String> credits;

  /// `Shabad OS`.
  final String? source;

  /// The database release, for example `5.0.0-next.0`.
  final String? version;

  /// How much of SGPC's letters the lines match, from 0.985 to 1.
  final double? similarity;

  Map<String, dynamic> toJson() => {
        if (source != null) 'source': source,
        if (version != null) 'version': version,
        'matched': true,
        if (similarity != null) 'similarity': similarity,
        'ids': ids,
        'ang': ang,
        'angEnd': angEnd,
        'sections': [for (final s in sections) s.toJson()],
        'writers': [for (final w in writers) w.toJson()],
        'credits': credits,
        'lines': [for (final l in lines) l.toJson()],
      };

  /// Reads the `shabad` object and the `lines` array of a mirror file.
  /// Returns null, and never throws, when the day has no matched shabad or
  /// when anything in it cannot be read: lines that are half right are worse
  /// than none.
  static HukamnamaShabad? tryParse(Object? shabad, Object? lines) {
    try {
      if (shabad is! Map<String, dynamic> || shabad['matched'] != true) {
        return null;
      }
      if (lines is! List || lines.isEmpty) return null;
      final ang = shabad['ang'];
      final angEnd = shabad['angEnd'];
      final ids = shabad['ids'];
      final credits = shabad['credits'];
      if (ang is! int || _validAng(ang) == null) return null;
      final end = angEnd is int ? _validAng(angEnd) : null;
      final similarity = shabad['similarity'];
      return HukamnamaShabad(
        lines: List.unmodifiable([
          for (final line in lines)
            line is Map<String, dynamic>
                ? HukamnamaLine.fromJson(line)
                : throw const FormatException('A line is not an object.'),
        ]),
        ids:
            ids is List ? List.unmodifiable(ids.whereType<String>()) : const [],
        ang: ang,
        angEnd: end != null && end >= ang ? end : ang,
        sections: _names(shabad['sections']),
        writers: _names(shabad['writers']),
        credits: credits is Map
            ? Map.unmodifiable({
                for (final entry in credits.entries)
                  if (entry.key is String && displayText(entry.value) != null)
                    entry.key as String: displayText(entry.value)!,
              })
            : const {},
        source: displayText(shabad['source']),
        version: displayText(shabad['version']),
        similarity: similarity is num ? similarity.toDouble() : null,
      );
    } on FormatException {
      return null;
    }
  }

  static List<HukamnamaName> _names(Object? json) => json is List
      ? List.unmodifiable([
          for (final item in json)
            if (HukamnamaName.tryParse(item) case final name?) name,
        ])
      : const [];
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
    this.shabad,
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

  /// The shabad line by line from Shabad OS: the Gurmukhi, the pauses, an
  /// English and a Punjabi meaning, and facts about the shabad. Null when the
  /// mirror has none for the day. The reader shows these lines when it has
  /// them, and [lines] is unchanged by it.
  final HukamnamaShabad? shabad;

  /// This day with [shabad] in place of its own. Every other field stays.
  Hukamnama withShabad(HukamnamaShabad? shabad) => Hukamnama(
        date: date,
        lines: lines,
        ang: ang,
        headingGurmukhi: headingGurmukhi,
        headingEnglish: headingEnglish,
        punjabiMeaning: punjabiMeaning,
        englishMeaning: englishMeaning,
        footerGurmukhi: footerGurmukhi,
        footerEnglish: footerEnglish,
        shabad: shabad,
      );

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
  ///
  /// The mirror's files hold two keys next to SGPC's own: `shabad` and
  /// `lines`. They fill [shabad] when they can be read in full, and are ignored
  /// when they cannot. See [HukamnamaShabad.tryParse].
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
      shabad: HukamnamaShabad.tryParse(json['shabad'], json['lines']),
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
        if (shabad != null) 'shabad': shabad!.toJson(),
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
      shabad: switch (json['shabad']) {
        final Map<String, dynamic> shabad =>
          HukamnamaShabad.tryParse(shabad, shabad['lines']),
        _ => null,
      },
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

bool _sameList<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
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
      if (displayText(value) case final text?)
        text.replaceAll(RegExp(r'\s+'), ' '),
  ];
  return parts.isEmpty ? null : parts.join('\n');
}
