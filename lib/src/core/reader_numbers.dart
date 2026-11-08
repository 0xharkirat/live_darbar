import 'package:intl/intl.dart';
import 'package:live_darbar/src/models/sikh_date.dart';

/// Numbers and dates as the reader sees them: Gurmukhi digits in Punjabi,
/// Latin digits in English.
///
/// SGPC prints "ਅੰਗ: ੬੬੮", and the Sikh date already uses Gurmukhi digits.
/// A line that mixed the 2 systems ("ਅੰਗ 668 · ੧੭ ਕੱਤਕ ੫੫੮") put a Latin digit,
/// 14% taller than the Gurmukhi body, beside Gurmukhi ones.
///
/// The timecode and the version stay in Latin digits. They change while you
/// look at them, and the Gurmukhi face has no tabular figures.
String readerNumber(int n, {required bool punjabi}) =>
    punjabi ? toGurmukhiNumerals(n) : '$n';

/// [date] as day and month, for example "2 November" or "੨ ਨਵੰਬਰ", with the
/// weekday in front when [weekday] is true.
///
/// `package:intl` writes the Punjabi day in Latin digits, so it supplies only
/// the month and the weekday names. The day comes from [readerNumber].
String readerDate(
  DateTime date, {
  required bool punjabi,
  bool weekday = false,
  bool year = false,
}) {
  final locale = punjabi ? 'pa' : 'en';
  final dayAndMonth =
      '${readerNumber(date.day, punjabi: punjabi)} ${DateFormat('MMMM', locale).format(date)}'
      '${year ? ' ${readerNumber(date.year, punjabi: punjabi)}' : ''}';
  return weekday
      ? '${DateFormat('EEEE', locale).format(date)}, $dayAndMonth'
      : dayAndMonth;
}
