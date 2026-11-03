import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'
    show AssetBundle, AssetManifest, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/src/controllers/sikh_date_controller.dart';
import 'package:live_darbar/src/core/clock.dart';
import 'package:live_darbar/src/models/sgpc_event.dart';
import 'package:live_darbar/src/models/sikh_date.dart';

/// The bundled event files: `assets/data/sgpc_events_558.json`, one for each
/// Nanakshahi year. See the files for their sources.
final _eventFile = RegExp(r'^assets/data/sgpc_events_(\d+)\.json$');

/// Reads every events file in [bundle] and joins them, oldest year first.
///
/// The files are found by name, not listed here. Next March's calendar is a
/// new `sgpc_events_559.json` in `assets/data/`, and the app needs no other
/// change: `pubspec.yaml` bundles that whole folder.
///
/// A file that cannot be read or does not parse is left out and the others
/// stay. Events are a courtesy, and a broken file is a build mistake that a
/// test catches, not something a listener can fix. With no usable file the
/// table is empty.
Future<SgpcEventTable> loadSgpcEvents(AssetBundle bundle) async {
  final tables = <SgpcEventTable>[];
  try {
    final manifest = await AssetManifest.loadFromAssetBundle(bundle);
    final paths = manifest.listAssets().where(_eventFile.hasMatch).toList()
      ..sort((a, b) => _yearOf(a).compareTo(_yearOf(b)));
    for (final path in paths) {
      try {
        tables
            .add(SgpcEventTable.fromJsonString(await bundle.loadString(path)));
      } catch (e) {
        if (!kReleaseMode) debugPrint('[sikh history] $path unusable: $e');
      }
    }
  } catch (e) {
    if (!kReleaseMode) debugPrint('[sikh history] no asset list: $e');
  }
  return SgpcEventTable.merge(tables);
}

int _yearOf(String path) => int.parse(_eventFile.firstMatch(path)!.group(1)!);

/// Every bundled event, or an empty table when none can be read.
final sgpcEventsProvider = FutureProvider<SgpcEventTable>(
  (ref) => loadSgpcEvents(rootBundle),
);

/// What happened on today's SGPC day, for the home screen. Empty on a day with
/// no event.
///
/// The day is the one the Sikh date is for (see [everydayDateFor]), so the
/// date and the events always name the same day. This provider watches
/// [sikhDateProvider], which moves to the next day by itself at midnight in
/// Amritsar, and so does this one.
final todaysEventsProvider = FutureProvider<List<SgpcEvent>>((ref) async {
  final now = ref.read(clockProvider)();
  final sikh = await ref.watch(sikhDateProvider.future);
  final table = await ref.watch(sgpcEventsProvider.future);
  return table.on(everydayDateFor(sikh, now));
});
