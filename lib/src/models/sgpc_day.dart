/// Addressing SGPC's daily content by the day it belongs to.
///
/// SGPC publishes each day's Hukamnama and Katha twice over. There is a fixed
/// URL that is overwritten in place every morning, and there is a dated archive
/// URL that is written once and then never changes. Everything here is about
/// the second kind, because the first kind cannot be cached correctly by
/// anybody.
///
/// That is not a theoretical worry. Every layer between the app and Amritsar
/// keys on the URL: the on-device Hukamnama text cache, ExoPlayer's and
/// AVPlayer's own caches, the browser on web, and Cloudflare in front of
/// hs.sgpc.net. Ask any of them for `uploadhukamnama/hukamnama.mp3` and a copy
/// from last week is a *correct* answer, because as far as they can tell the
/// resource never changed. Putting the date in the path makes yesterday's
/// bytes unreachable rather than merely unlikely.
library;

/// India Standard Time, as a fixed offset from UTC.
///
/// A constant rather than a timezone lookup because IST has had no daylight
/// saving and no offset change since 1945, so there is exactly one right
/// answer and `package:timezone` would be several hundred kilobytes of
/// database to produce it.
const kIndiaOffset = Duration(hours: 5, minutes: 30);

/// Base of the Hukamnama audio archive. Filenames are `SGPCNET{ddmmyy}.mp3`.
const _kHukamnamaAudioPrefix = 'https://hs.sgpc.net/hukamnamaaudio/SGPCNET';

/// Base of the Katha audio archive. Filenames are `katha{ddmmyy}.mp3`.
const _kKathaAudioPrefix = 'https://hs.sgpc.net/kathaaudio/katha';

/// The undocumented JSON endpoint behind SGPC's archive calendar.
///
/// Takes `selected_date=yyyy-MM-dd` as a form post and answers with the day's
/// shabad and its Nanakshahi date. It answers HTTP 200 either way: a day it
/// does not have comes back as `{"supported": false, ...}`, so the status code
/// alone tells you nothing.
const kHukamnamaArchiveUrl =
    'https://hs.sgpc.net/hssearchhukmanamaTestCalender.php';

/// The SGPC page that builds the Hukamnama PDF in the reader's browser.
///
/// SGPC no longer serves a PDF file: its own script (html2pdf.js) turns the
/// day's JSON into the PDF, so there is nothing for the app to download. The
/// app opens this page in the system's in-app browser, where the page has a
/// "Download & View Hukamnama PDF" button.
const kHukamnamaPdfPageUrl = 'https://hs.sgpc.net/hspdf.php';

/// The Gregorian day at Sri Harmandir Sahib containing [instant].
///
/// Returned as UTC midnight rather than local midnight, for two reasons. It
/// makes the value unambiguous when it is compared or stored, and it makes
/// `subtract(const Duration(days: 1))` exact. Duration arithmetic on a local
/// `DateTime` measures elapsed time, not calendar days, so subtracting 24
/// hours across a daylight-saving boundary lands on 23:00 the day you started
/// and truncating back to midnight repeats the date. UTC has no such boundary.
DateTime sgpcDayOf(DateTime instant) {
  final india = instant.toUtc().add(kIndiaOffset);
  return DateTime.utc(india.year, india.month, india.day);
}

/// The day before [day], as another UTC midnight.
DateTime previousSgpcDay(DateTime day) =>
    day.toUtc().subtract(const Duration(days: 1));

String _two(int n) => n.toString().padLeft(2, '0');

/// `ddmmyy`, the stamp SGPC's archive filenames carry.
///
/// Zero-padded on both the day and the month, and the year is the last two
/// digits. Every other shape is a 404: `SGPCNET5826.mp3` and
/// `SGPCNET260812.mp3` were both checked against the live server.
String sgpcDayStamp(DateTime day) {
  final d = day.toUtc();
  return '${_two(d.day)}${_two(d.month)}${_two(d.year % 100)}';
}

/// `yyyy-MM-dd`, the shape the archive JSON endpoint takes.
String sgpcDayIso(DateTime day) {
  final d = day.toUtc();
  return '${d.year}-${_two(d.month)}-${_two(d.day)}';
}

/// `yyyy_MM_dd`, safe to put in a filename.
String sgpcDayFileStamp(DateTime day) {
  final d = day.toUtc();
  return '${d.year}_${_two(d.month)}_${_two(d.day)}';
}

/// The two recordings SGPC replaces once a day.
///
/// They do not arrive together, which is the whole reason freshness has to be
/// resolved per asset rather than once for the app. Measured from the
/// `Last-Modified` headers on the archive files, the Hukamnama lands between
/// about 05:15 and 06:05 IST and the Katha between about 09:25 and 09:55 IST.
/// So there is a window every morning, roughly four hours wide, in which
/// today's Hukamnama exists and today's Katha does not.
enum DailyAsset {
  hukamnama(
    datedPrefix: _kHukamnamaAudioPrefix,
    latestUrl: 'https://hs.sgpc.net/uploadhukamnama/hukamnama.mp3',
  ),
  katha(
    datedPrefix: _kKathaAudioPrefix,
    latestUrl: 'https://hs.sgpc.net/uploadkatha/katha.mp3',
  );

  const DailyAsset({required this.datedPrefix, required this.latestUrl});

  final String datedPrefix;

  /// The fixed URL, overwritten in place every morning.
  ///
  /// Worth keeping despite everything above, because it is the one address
  /// that is always populated. When the dated scheme cannot be reached, or is
  /// changed out from under us, playing the newest thing SGPC has beats
  /// playing nothing. What is lost is only the ability to say which day it is.
  final String latestUrl;

  String urlFor(DateTime day) => '$datedPrefix${sgpcDayStamp(day)}.mp3';
}
