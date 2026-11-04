import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/src/controllers/sgpc_events_controller.dart';
import 'package:live_darbar/src/controllers/sikh_date_controller.dart';
import 'package:live_darbar/src/core/clock.dart';
import 'package:live_darbar/src/core/history_calendar.dart';
import 'package:live_darbar/src/models/sikh_date.dart';

/// The whole Nanakshahi year of Sikh history, for the screen that Home opens.
///
/// "Today" is the same day the Sikh date and the line on Home use (see
/// [everydayDateFor]), so the screen and the line always agree. This provider
/// watches [sikhDateProvider], which moves to the next day by itself at
/// midnight in Amritsar, and so does this one. Null when no event file covers
/// the year.
final historyYearProvider = FutureProvider<HistoryYear?>((ref) async {
  final now = ref.read(clockProvider)();
  final sikh = await ref.watch(sikhDateProvider.future);
  final table = await ref.watch(sgpcEventsProvider.future);
  return buildHistoryYear(table, everydayDateFor(sikh, now));
});
