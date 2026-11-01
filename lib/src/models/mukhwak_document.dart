import 'dart:typed_data';

import 'package:live_darbar/src/models/daily_edition.dart';
import 'package:live_darbar/src/models/sgpc_day.dart';

/// A Mukhwak PDF on disk, and which day it is.
class MukhwakDocument {
  const MukhwakDocument({
    required this.filePath,
    required this.freshness,
    this.day,
  });

  final String filePath;

  final DailyFreshness freshness;

  /// The SGPC day the document belongs to, or null when it came from the
  /// undated endpoint and there is nothing honest to claim.
  final DateTime? day;

  bool get isStale => freshness == DailyFreshness.previousDay;

  /// Shared by every cached PDF, so the sweep can find them all.
  ///
  /// Note that this deliberately also matches the old `mukhwak_{date}.pdf`
  /// names written before the cache was keyed on SGPC's day rather than the
  /// device's. Those held whatever `hukamnamapdf.php` happened to return, so
  /// they cannot be trusted to be the day their filename claims, and the sweep
  /// clearing them out on first run is the point.
  static const filePrefix = 'mukhwak_';

  /// Cache name for content known to belong to [day].
  static String datedFileName(DateTime day) =>
      '${filePrefix}day_${sgpcDayFileStamp(day)}.pdf';

  /// Cache name for content from the undated endpoint, keyed on the day it was
  /// fetched rather than the day it contains, because that is all we know.
  ///
  /// Keeping it under a separate name is what stops it from being mistaken for
  /// a confirmed copy of today. It is shown immediately on the next launch so
  /// nobody waits, and the dated fetch still runs and replaces it.
  static String latestFileName(DateTime fetchedOn) =>
      '${filePrefix}latest_${sgpcDayFileStamp(fetchedOn)}.pdf';

  /// Whether [bytes] actually open with the PDF magic number.
  ///
  /// Needed because `intdep/pdfdownload.php` answers an unknown id with HTTP
  /// 200 and a 403-byte HTML error page rather than a 404, so the status code
  /// on its own would have the app cache an error message as a Mukhwak.
  static bool looksLikePdf(Uint8List bytes) =>
      bytes.length > 4 &&
      bytes[0] == 0x25 && // %
      bytes[1] == 0x50 && // P
      bytes[2] == 0x44 && // D
      bytes[3] == 0x46; // F
}
