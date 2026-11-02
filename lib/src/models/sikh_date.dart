/// The Nanakshahi date that Sri Harmandir Sahib and SGPC print each day.
///
/// ## Which calendar
///
/// This is the calendar on the wall at Darbar Sahib, not Pal Singh Purewal's
/// original 2003 fixed-solar one. SGPC's months start on the sangrand, the day
/// the sun enters the next sidereal sign, and that day moves from year to
/// year. A fixed-date algorithm (month 8 always starts on 15 October, and so
/// on) disagrees with SGPC's own website on 213 of 365 days, and it only looks
/// right in the months where the two happen to coincide: Chet, Harh, Savan and
/// Phagun. So the month starts come from a table, [SangrandTable], loaded from
/// `assets/data/sgpc_sangrands.json`. The file says where each row came from.
///
/// The year and the day of the month follow from the month starts:
/// the year changes on 1 Chet, and the day is the distance from the start.
///
/// ## Failing soft
///
/// A date outside the table has no honest answer, so [SangrandTable.sikhDateFor]
/// returns null and the screen shows only the Gregorian date. The same holds
/// for a month whose start is flagged `uncertain` in the file, because a wrong
/// day of the month is worse than none.
library;

import 'dart:convert';

import 'package:live_darbar/src/models/sgpc_day.dart';

/// Month names in the order the year runs, Chet first.
///
/// The Gurmukhi spellings are the ones SGPC prints in its own date footer.
/// The English column is a plain transliteration. SGPC's English footer
/// spells the same months several ways ("Chayt", "Jayt'h", "Assaar", ...), so
/// it is not used as the source of names.
const List<String> kSikhMonthsGurmukhi = [
  'ਚੇਤ',
  'ਵੈਸਾਖ',
  'ਜੇਠ',
  'ਹਾੜ',
  'ਸਾਵਣ',
  'ਭਾਦੋਂ',
  'ਅੱਸੂ',
  'ਕੱਤਕ',
  'ਮੱਘਰ',
  'ਪੋਹ',
  'ਮਾਘ',
  'ਫੱਗਣ',
];

/// See [kSikhMonthsGurmukhi].
const List<String> kSikhMonthsEnglish = [
  'Chet',
  'Vaisakh',
  'Jeth',
  'Harh',
  'Savan',
  'Bhadon',
  'Assu',
  'Katak',
  'Maghar',
  'Poh',
  'Magh',
  'Phagun',
];

const List<String> _gurmukhiDigits = [
  '੦',
  '੧',
  '੨',
  '੩',
  '੪',
  '੫',
  '੬',
  '੭',
  '੮',
  '੯',
];

/// [n] written in Gurmukhi digits, as SGPC prints it.
///
/// `package:intl` formats Punjabi dates in Latin digits, so the digits are
/// mapped by hand.
String toGurmukhiNumerals(int n) => n
    .toString()
    .split('')
    .map((c) => c == '-' ? c : _gurmukhiDigits[int.parse(c)])
    .join();

/// One day in the Nanakshahi calendar as SGPC prints it.
/// The everyday date that sits under the Sikh date.
///
/// Both lines must name the same day: the SGPC day in Amritsar, which is
/// the day [sikh] was computed for. The phone's local day can differ. In
/// Canada at 8 pm, Amritsar is already on the next morning. When the Sikh
/// date is not known, the SGPC day of [now] is used, for the same reason.
DateTime everydayDateFor(SikhDate? sikh, DateTime now) =>
    sikh?.gregorian ?? sgpcDayOf(now);

class SikhDate {
  SikhDate({
    required this.day,
    required this.monthIndex,
    required this.year,
    required this.gregorian,
  })  : assert(day >= 1 && day <= 32, 'No Nanakshahi month has $day days.'),
        assert(monthIndex >= 0 && monthIndex < 12),
        monthGurmukhi = kSikhMonthsGurmukhi[monthIndex],
        monthEnglish = kSikhMonthsEnglish[monthIndex];

  /// Day of the month, from 1. A month runs 29 to 32 days.
  final int day;

  /// Zero based position in the year: 0 is Chet, 4 is Savan, 11 is Phagun.
  final int monthIndex;

  /// The month in Gurmukhi, as SGPC prints it. For example ਸਾਵਣ.
  final String monthGurmukhi;

  /// The month transliterated into English. For example Savan.
  final String monthEnglish;

  /// The Nanakshahi year (Samvat), for example 558. It changes on 1 Chet.
  final int year;

  /// The same day on the Gregorian calendar, for display next to the Sikh
  /// date. This is SGPC's day at Amritsar, as UTC midnight, the shape that
  /// `sgpcDayOf` returns. Read `year`, `month` and `day` from it and ignore
  /// the time and the zone.
  final DateTime gregorian;

  /// [day] in Gurmukhi digits.
  String get dayGurmukhi => toGurmukhiNumerals(day);

  /// [year] in Gurmukhi digits.
  String get yearGurmukhi => toGurmukhiNumerals(year);

  /// The date the way SGPC's footer ends: `੧੭ ਕੱਤਕ (ਸੰਮਤ ੫੫੮ ਨਾਨਕਸ਼ਾਹੀ)`.
  ///
  /// The weekday and the Gregorian date are left to the screen, which knows
  /// the locale.
  String get gurmukhiLabel =>
      '$dayGurmukhi $monthGurmukhi (ਸੰਮਤ $yearGurmukhi ਨਾਨਕਸ਼ਾਹੀ)';

  /// The English counterpart: `17 Katak (Samvat 558 Nanakshahi)`.
  String get englishLabel => '$day $monthEnglish (Samvat $year Nanakshahi)';

  /// Day, month and year with no era, for a tight line: `੧੭ ਕੱਤਕ ੫੫੮`.
  String get shortGurmukhi => '$dayGurmukhi $monthGurmukhi $yearGurmukhi';

  /// The English counterpart of [shortGurmukhi]: `17 Katak 558`.
  String get shortEnglish => '$day $monthEnglish $year';

  @override
  bool operator ==(Object other) =>
      other is SikhDate &&
      other.day == day &&
      other.monthIndex == monthIndex &&
      other.year == year &&
      other.gregorian == gregorian;

  @override
  int get hashCode => Object.hash(day, monthIndex, year, gregorian);

  @override
  String toString() => 'SikhDate($englishLabel, $gregorian)';
}

/// Where a row of the table came from. Shown in the file for the maintainer;
/// nothing reads it at runtime except [SangrandMonth.uncertain].
class SangrandMonth {
  const SangrandMonth({
    required this.start,
    required this.monthIndex,
    required this.year,
    required this.source,
    this.uncertain = false,
  });

  /// The first day of the month, as UTC midnight.
  final DateTime start;

  /// 0 for Chet to 11 for Phagun.
  final int monthIndex;

  /// The Nanakshahi year this month belongs to.
  final int year;

  /// `sgpc-archive`, `jantri-558` or `computed`. See the file header.
  final String source;

  /// True when the start could be a day out, so every date in the month is
  /// reported as unknown.
  final bool uncertain;
}

/// The month starts SGPC prints, and the arithmetic over them.
class SangrandTable {
  /// Builds a table from rows already in order.
  ///
  /// Throws [FormatException] when the rows are not usable. A table that is
  /// wrong in the middle would give wrong dates silently, so it is refused
  /// whole rather than trusted in part.
  factory SangrandTable(List<SangrandMonth> months) {
    if (months.length < 2) {
      throw const FormatException('A sangrand table needs at least 2 rows.');
    }
    for (var i = 0; i < months.length; i++) {
      final m = months[i];
      if (m.monthIndex < 0 || m.monthIndex > 11) {
        throw FormatException('Row $i has month ${m.monthIndex}.');
      }
      if (i == 0) continue;
      final prev = months[i - 1];
      final length = m.start.difference(prev.start).inDays;
      if (length < 28 || length > 33) {
        throw FormatException('Row $i starts $length days after row ${i - 1}.');
      }
      final wantMonth = (prev.monthIndex + 1) % 12;
      final wantYear = wantMonth == 0 ? prev.year + 1 : prev.year;
      if (m.monthIndex != wantMonth || m.year != wantYear) {
        throw FormatException(
            'Row $i is month ${m.monthIndex} of ${m.year}, expected month '
            '$wantMonth of $wantYear.');
      }
    }
    return SangrandTable._(List.unmodifiable(months));
  }

  const SangrandTable._(this.months);

  /// Reads the JSON asset. Throws [FormatException] on a bad file.
  factory SangrandTable.fromJsonString(String source) {
    final Object? decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The sangrand file is not a JSON object.');
    }
    final rows = decoded['months'];
    if (rows is! List) {
      throw const FormatException('The sangrand file has no "months" list.');
    }
    try {
      return SangrandTable([
        for (final row in rows)
          if (row is Map<String, dynamic>)
            SangrandMonth(
              start: _parseDay(row['start']),
              monthIndex: row['month'] as int,
              year: row['year'] as int,
              source: row['source'] as String? ?? 'unknown',
              uncertain: row['uncertain'] == true,
            )
          else
            throw const FormatException('A sangrand row is not an object.'),
      ]);
    } on TypeError catch (e) {
      throw FormatException('A sangrand row has a wrong field type: $e');
    }
  }

  /// Every month start in order. The last row only ends the one before it.
  final List<SangrandMonth> months;

  /// The first day the table answers for.
  DateTime get firstDay => months.first.start;

  /// The first day after the table, which it does not answer for.
  DateTime get endExclusive => months.last.start;

  /// The Nanakshahi date for [day], or null when the table cannot say.
  ///
  /// Only the year, month and day of [day] are read, so pass the SGPC day
  /// (`sgpcDayOf`) and not a local midnight in a far time zone.
  /// Null means: before the first row, on or after the last row, or inside a
  /// month flagged uncertain.
  SikhDate? sikhDateFor(DateTime day) {
    final date = DateTime.utc(day.year, day.month, day.day);
    if (date.isBefore(firstDay) || !date.isBefore(endExclusive)) return null;

    // The table is short, 49 rows for 4 years, so a scan is plenty.
    var found = months.length - 2;
    for (var i = 1; i < months.length; i++) {
      if (months[i].start.isAfter(date)) {
        found = i - 1;
        break;
      }
    }
    final month = months[found];
    if (month.uncertain) return null;
    return SikhDate(
      day: date.difference(month.start).inDays + 1,
      monthIndex: month.monthIndex,
      year: month.year,
      gregorian: date,
    );
  }
}

DateTime _parseDay(Object? value) {
  if (value is! String) {
    throw const FormatException('A sangrand row has no start date.');
  }
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) {
    throw FormatException('Bad sangrand start "$value".');
  }
  return DateTime.utc(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
}
