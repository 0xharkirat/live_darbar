/// How far back the Hukamnama archive reaches, and the picker's days.
library;

/// The first day the phone apps offer in the Hukamnama archive.
///
/// SGPC's archive answers days back to 2000, but not every day. On 7 November
/// 2026 a sample of 1 day in 6 found gaps in every year before 2012, and none
/// from 2012 to the present. A date picker that starts where the answers are
/// whole means a listener rarely lands on a day with no text. A day with none
/// still gets a calm note.
final kHukamnamaArchiveStart = DateTime.utc(2012, 1, 1);

/// How many days back the web offers.
///
/// The web reads a copy of SGPC's answer, not SGPC (`kHukamnamaMirrorUrl`),
/// and the copy keeps the last 31 days: today and the 30 before it
/// (`kKeepDays` in tool/hukamnama_mirror.dart).
const kHukamnamaWebArchiveDays = 30;

/// The earliest day the archive sheet offers, when [today] is the SGPC day.
DateTime hukamnamaArchiveFloor(DateTime today, {required bool web}) => web
    ? DateTime.utc(
        today.year,
        today.month,
        today.day - kHukamnamaWebArchiveDays,
      )
    : kHukamnamaArchiveStart;

/// [day], an SGPC day (UTC midnight), as the plain calendar day that a date
/// picker holds. A local midnight names the same day on every device.
DateTime pickerDayOf(DateTime day) => DateTime(day.year, day.month, day.day);

/// The SGPC day (UTC midnight) that the picker's [picked] names.
DateTime sgpcDayFromPicker(DateTime picked) =>
    DateTime.utc(picked.year, picked.month, picked.day);
