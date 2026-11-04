import 'package:flutter/foundation.dart';
import 'package:live_darbar/src/models/sgpc_event.dart';

/// The Nanakshahi year that holds [day]. The year starts on 14 March: 14 March
/// 2026 is the first day of 558.
int nanakshahiYearOf(DateTime day) {
  final d = day.toUtc();
  final afterNewYear = d.month > 3 || (d.month == 3 && d.day >= 14);
  return d.year - (afterNewYear ? 1468 : 1469);
}

/// Where [day] stands against today.
enum HistoryTense { past, today, upcoming }

/// The events that start on 1 day of the calendar.
///
/// An event of several days (a joor mela) is listed once, on its first day.
/// The row runs to the last day of its longest event, so it counts as today
/// on each day it covers.
@immutable
class HistoryDay {
  const HistoryDay({
    required this.first,
    required this.last,
    required this.events,
  });

  /// The first SGPC day, as UTC midnight.
  final DateTime first;

  /// The last day of the longest event that starts on [first]. Equal to
  /// [first] for events of 1 day.
  final DateTime last;

  /// In the order of the calendar.
  final List<SgpcEvent> events;

  bool get isRange => last.isAfter(first);

  HistoryTense tense(DateTime today) {
    if (last.isBefore(today)) return HistoryTense.past;
    if (first.isAfter(today)) return HistoryTense.upcoming;
    return HistoryTense.today;
  }
}

/// The days of 1 month that have an event, oldest first.
@immutable
class HistoryMonth {
  const HistoryMonth({
    required this.year,
    required this.month,
    required this.days,
  });

  /// The Gregorian year and month, such as 2026 and 11.
  final int year;
  final int month;

  final List<HistoryDay> days;
}

/// A whole Nanakshahi year of Sikh history, grouped by month, with today
/// marked.
@immutable
class HistoryYear {
  const HistoryYear({
    required this.number,
    required this.today,
    required this.months,
  });

  /// The Nanakshahi year, such as 558.
  final int number;

  /// The SGPC day that the screen calls today.
  final DateTime today;

  /// From March on, so the months read in the order of the year.
  final List<HistoryMonth> months;

  Iterable<HistoryDay> get days => months.expand((m) => m.days);

  /// The row the screen opens on: today's, or the next one to come, or the
  /// last one when the year has run out. Null when the year has no days.
  HistoryDay? get focus {
    HistoryDay? last;
    for (final day in days) {
      if (day.tense(today) != HistoryTense.past) return day;
      last = day;
    }
    return last;
  }
}

/// The year of [today] from [table]: each event on its first day, in month
/// groups. Null when no event falls in that year.
///
/// [today] is an SGPC day. An event that the table already left out (one that
/// needs a review) is not here either.
HistoryYear? buildHistoryYear(SgpcEventTable table, DateTime today) {
  final number = nanakshahiYearOf(today);
  final start = DateTime.utc(number + 1468, 3, 14);
  final end = DateTime.utc(number + 1469, 3, 14);

  final byDay = <DateTime, List<SgpcEvent>>{};
  for (final event in table.events) {
    if (event.first.isBefore(start) || !event.first.isBefore(end)) continue;
    (byDay[event.first] ??= []).add(event);
  }
  if (byDay.isEmpty) return null;

  final firsts = byDay.keys.toList()..sort();
  // Insertion order is date order, so the months come out in the year's order.
  final byMonth = <(int, int), List<HistoryDay>>{};
  for (final first in firsts) {
    final events = byDay[first]!;
    final last =
        events.map((e) => e.last).reduce((a, b) => a.isAfter(b) ? a : b);
    (byMonth[(first.year, first.month)] ??= []).add(
      HistoryDay(first: first, last: last, events: List.unmodifiable(events)),
    );
  }
  final months = [
    for (final entry in byMonth.entries)
      HistoryMonth(
        year: entry.key.$1,
        month: entry.key.$2,
        days: List.unmodifiable(entry.value),
      ),
  ];

  return HistoryYear(
    number: number,
    today: DateTime.utc(today.year, today.month, today.day),
    months: months,
  );
}
