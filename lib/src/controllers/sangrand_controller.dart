import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/src/controllers/sikh_date_controller.dart';
import 'package:live_darbar/src/models/barah_maha.dart';
import 'package:live_darbar/src/models/hukamnama.dart';
import 'package:live_darbar/src/models/sikh_date.dart';

/// The bundled Barah Maha. See [BarahMaha] and tool/barah_maha.dart.
const kBarahMahaAsset = 'assets/data/barah_maha.json';

/// Barah Maha, or null when the asset cannot be read. A broken asset is a
/// build mistake; the Sangrand row and page then do not show.
final barahMahaProvider = FutureProvider<BarahMaha?>((ref) async {
  try {
    // The bytes, decoded here: loadString hands a file over 50 KB to another
    // isolate, which costs more than this 95 KB file takes to decode.
    final bytes = await rootBundle.load(kBarahMahaAsset);
    return BarahMaha.fromJson(
      jsonDecode(utf8.decode(bytes.buffer.asUint8List()))
          as Map<String, dynamic>,
    );
  } catch (e) {
    if (!kReleaseMode) debugPrint('[sangrand] no Barah Maha: $e');
    return null;
  }
});

/// The Sangrand Hukamnama of the Sikh month it is now: the month's pauri of
/// Barah Maha.
class Sangrand {
  const Sangrand({
    required this.date,
    required this.heading,
    required this.lines,
    required this.credits,
  });

  /// The Sikh date of the day. Its month names the pauri. Today's for
  /// [sangrandProvider], the day asked for by [sangrandForDayProvider].
  final SikhDate date;

  /// Barah Maha's title lines.
  final List<HukamnamaLine> heading;

  /// The month's pauri.
  final List<HukamnamaLine> lines;

  final Map<String, String> credits;

  /// Whether the day is Sangrand, the 1st of the Sikh month.
  bool get isSangrandDay => date.day == 1;

  /// Whether today is the Sangrand. The day of [sangrandProvider] is today.
  bool get isToday => isSangrandDay;

  /// The Ang of the pauri.
  int? get ang => lines.first.ang;
}

/// The Sangrand Hukamnama for today's Sikh month, or null while the Sikh
/// date or Barah Maha is not known. It changes with the month, at SGPC
/// midnight, as the Sikh date does.
final sangrandProvider = FutureProvider<Sangrand?>((ref) async {
  final date = await ref.watch(sikhDateProvider.future);
  final bani = await ref.watch(barahMahaProvider.future);
  if (date == null || bani == null) return null;
  return _sangrandOf(date, bani);
});

Sangrand _sangrandOf(SikhDate date, BarahMaha bani) => Sangrand(
      date: date,
      heading: bani.heading,
      lines: bani.pauriFor(date.monthIndex),
      credits: bani.credits,
    );

/// The Sangrand Hukamnama for the Sikh month that [day] is in, for the reader
/// of an earlier day. [day] is an SGPC day, as UTC midnight. The reader shows
/// it only when [Sangrand.isSangrandDay].
///
/// Null while the table or Barah Maha is not known, and for a day the table of
/// month starts does not reach (see [SangrandTable.sikhDateFor]): the Sikh
/// date of an old day is not guessed, so a Sangrand before it is not shown.
final sangrandForDayProvider =
    FutureProvider.family<Sangrand?, DateTime>((ref, day) async {
  final table = await ref.watch(sangrandTableProvider.future);
  final bani = await ref.watch(barahMahaProvider.future);
  final date = table?.sikhDateFor(day);
  if (date == null || bani == null) return null;
  return _sangrandOf(date, bani);
});
