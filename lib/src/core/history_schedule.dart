import 'package:flutter/foundation.dart';
import 'package:live_darbar/src/models/sgpc_event.dart';

/// How many days ahead "Today in Sikh history" is scheduled, counting today.
///
/// The phone keeps 1 notification for each day with an event. A day has at
/// most 1, so this is also the most the feature can hold. iOS keeps 64 pending
/// notifications and drops the rest, and the daily Hukamnama reminder holds 1,
/// so 30 leaves a wide margin.
const kHistoryDays = 30;

/// The notification for 1 SGPC day: what happened that day, in the app's
/// language.
@immutable
class HistoryNotice {
  const HistoryNotice({required this.day, required this.body});

  /// The SGPC day, as UTC midnight. The notification fires on this date on
  /// the phone's own clock.
  final DateTime day;

  /// The title of each event, one to a line.
  final String body;

  @override
  bool operator ==(Object other) =>
      other is HistoryNotice && other.day == day && other.body == body;

  @override
  int get hashCode => Object.hash(day, body);

  @override
  String toString() => 'HistoryNotice($day, $body)';
}

/// The notifications for the [days] days from [today], counting [today]: 1 for
/// each day that has an event, none for a day that has not.
///
/// [today] is an SGPC day. The text follows the app's language: Punjabi
/// titles when [punjabi], and English titles otherwise, with the Punjabi title
/// where the calendar has no English one.
List<HistoryNotice> planHistory({
  required SgpcEventTable table,
  required DateTime today,
  required bool punjabi,
  int days = kHistoryDays,
}) {
  final notices = <HistoryNotice>[];
  for (var i = 0; i < days; i++) {
    final day = DateTime.utc(today.year, today.month, today.day + i);
    final events = table.on(day);
    if (events.isEmpty) continue;
    notices.add(
      HistoryNotice(
        day: day,
        body: events.map((e) => e.title(punjabi: punjabi)).join('\n'),
      ),
    );
  }
  return notices;
}
