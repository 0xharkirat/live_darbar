/// Addressing SGPC's daily content by the day it belongs to.
///
/// SGPC publishes each day's Hukamnama and Katha twice over. There is a fixed
/// URL that is overwritten in place every morning, and there is a dated archive
/// URL that is written once and then never changes. Everything here is about
/// the second kind, because the first kind cannot be cached correctly by
/// anybody.
///
/// That is not a theoretical worry. Every layer between the app and Amritsar
/// keys on the URL: the on-device file cache in `MukhwakController`,
/// ExoPlayer's and AVPlayer's own caches, the browser on web, and Cloudflare in
/// front of hs.sgpc.net. Ask any of them for `uploadhukamnama/hukamnama.mp3`
/// and a copy from last week is a *correct* answer, because as far as they can
/// tell the resource never changed. Putting the date in the path makes
/// yesterday's bytes unreachable rather than merely unlikely.
library;

import 'dart:convert';

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
/// shabad, its Nanakshahi date, and the id of the generated PDF. Only the PDF
/// id is used here. It answers HTTP 200 either way: a day it does not have
/// comes back as `{"supported": false, ..., "pdfFiles": []}`, so the status
/// code alone tells you nothing.
const kHukamnamaArchiveUrl =
    'https://hs.sgpc.net/hssearchhukmanamaTestCalender.php';

/// The PDF SGPC regenerates on every request, for whatever day is current.
///
/// Kept only as a last resort. It is server-rendered rather than served from
/// disk, which shows: measured from Sydney on 2026-08-12 it took a median
/// 4.1 s to produce its first byte across five runs, against 0.37 s for the
/// dated file holding the same document. Under load that gap is where the
/// hang comes from.
const kLatestHukamnamaPdfUrl = 'https://hs.sgpc.net/hukamnamapdf.php';

/// Where the already-generated PDF for one archive entry lives.
String hukamnamaPdfUrl(int fileId) =>
    'https://hs.sgpc.net/intdep/pdfdownload.php?id=$fileId';

/// The PDF id in an archive response, or null when SGPC has no entry.
///
/// Every branch here is a real answer the endpoint gives, not defensive
/// padding. It replies HTTP 200 for a day it does not have, so `supported` is
/// the only thing separating "here is the Hukamnama" from "that day has not
/// happened yet", and the latter is the normal state of affairs for several
/// hours after midnight in Amritsar rather than a fault worth reporting.
int? hukamnamaPdfIdFrom(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return null;
    if (decoded['supported'] != true) return null;

    final files = decoded['pdfFiles'];
    if (files is! List || files.isEmpty) return null;
    final first = files.first;
    return first is Map ? first['id'] as int? : null;
  } on FormatException {
    return null;
  }
}

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

/// The day currently being observed at Darbar Sahib.
///
/// Deliberately not the user's local day. A listener in Vancouver opening the
/// app at 20:00 on Tuesday is asking for Wednesday's Hukamnama, because that
/// is the one being read. Keying off their calendar would ask for a file
/// published eight hours ago and label it tomorrow's.
DateTime sgpcDayNow() => sgpcDayOf(DateTime.now());

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
