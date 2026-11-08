import 'package:live_darbar/src/models/hukamnama.dart';

/// Barah Maha Maajh, Mahala 5 (Guru Arjan Dev Ji, Ang 133 to 136), line by
/// line, as assets/data/barah_maha.json holds it.
///
/// On each Sangrand, the 1st day of a Sikh month, the sangat reads the pauri
/// of this bani for the new month. The app shows it as the Sangrand
/// Hukamnama. tool/barah_maha.dart wrote the file from the Shabad OS
/// database, so each line has the shape of a line in the Hukamnama mirror:
/// the Gurmukhi, its pauses, and the Punjabi and English meanings.
class BarahMaha {
  const BarahMaha({
    required this.heading,
    required this.pauris,
    this.credits = const {},
  });

  /// Throws [FormatException] for a file that does not hold the whole bani:
  /// a missing pauri would show the wrong month.
  factory BarahMaha.fromJson(Map<String, dynamic> json) {
    List<HukamnamaLine> lines(Object? rows) {
      if (rows is! List || rows.isEmpty) {
        throw const FormatException('Barah Maha has an empty part.');
      }
      return List.unmodifiable([
        for (final row in rows)
          row is Map<String, dynamic>
              ? HukamnamaLine.fromJson(row)
              : throw const FormatException(
                  'A Barah Maha line is not an object.'),
      ]);
    }

    final pauris = json['pauris'];
    if (pauris is! List || pauris.length != kPauris) {
      throw FormatException(
          'Barah Maha has ${pauris is List ? pauris.length : 0} pauris, '
          'not $kPauris.');
    }
    final credits = json['credits'];
    return BarahMaha(
      heading: lines(json['heading']),
      pauris: List.unmodifiable([for (final p in pauris) lines(p)]),
      credits: credits is Map
          ? Map.unmodifiable({
              for (final e in credits.entries)
                if (e.key is String && e.value is String)
                  e.key as String: e.value as String,
            })
          : const {},
    );
  }

  /// The opening, the 12 months from Chet to Phagun, and the closing.
  static const kPauris = 14;

  /// The title lines: "ਬਾਰਹ ਮਾਹਾ ਮਾਂਝ ਮਹਲਾ ੫ ਘਰੁ ੪ ॥" and ੴ.
  final List<HukamnamaLine> heading;

  /// The 14 pauris, in order.
  final List<List<HukamnamaLine>> pauris;

  /// Who made each kind of data, by the keys of [HukamnamaShabad.credits].
  final Map<String, String> credits;

  /// The pauri of the Sikh month [monthIndex]: 0 is Chet and 11 is Phagun,
  /// as in `SikhDate.monthIndex`. Pauri 1 opens the bani, so Chet is pauri 2.
  List<HukamnamaLine> pauriFor(int monthIndex) => pauris[monthIndex + 1];
}
