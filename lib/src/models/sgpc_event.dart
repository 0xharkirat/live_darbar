/// Days of Sikh history, from SGPC's calendar.
///
/// SGPC prints one calendar a year. The app bundles it as
/// `assets/data/sgpc_events_<year>.json`, 1 file for each Nanakshahi year, and
/// the file says where each part came from. [SgpcEventTable] answers "what
/// falls on this day".
///
/// ## Which day
///
/// An event belongs to an SGPC day: the Gregorian day at Amritsar, as
/// `sgpcDayOf` returns it (UTC midnight). The table never looks at a time of
/// day or a zone.
///
/// ## A range
///
/// A joor mela can run for days. An event with `gregorianEnd` falls on every
/// day from `gregorian` to `gregorianEnd`, both included.
///
/// ## Failing soft
///
/// A day that no file covers has no events. That is the normal state in the
/// weeks before a new year's file ships, so it is not an error.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:live_darbar/src/models/sgpc_day.dart';

/// The longest an event may run. The longest in the 558 calendar is 3 days. A
/// bigger number in a file is a typo, and the table would spend a long time
/// walking it.
const _maxEventDays = 31;

/// One entry of the calendar.
@immutable
class SgpcEvent {
  const SgpcEvent({
    required this.id,
    required this.first,
    required this.last,
    required this.titlePa,
    this.titleEn,
    this.needsReview = false,
  });

  factory SgpcEvent.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final titlePa = json['titlePa'];
    final titleEn = json['titleEn'];
    final end = json['gregorianEnd'];
    if (id is! String || titlePa is! String || titlePa.trim().isEmpty) {
      throw FormatException('An event needs an id and a Punjabi title: $json');
    }
    final gregorian = json['gregorian'];
    if (gregorian is! String) {
      throw FormatException('Event $id has no date.');
    }
    final first = parseSgpcDay(gregorian);
    final last = end is String ? parseSgpcDay(end) : first;
    final days = last.difference(first).inDays + 1;
    if (days < 1 || days > _maxEventDays) {
      throw FormatException('Event $id runs $days days.');
    }
    return SgpcEvent(
      id: id,
      first: first,
      last: last,
      titlePa: titlePa.trim(),
      titleEn: titleEn is String && titleEn.trim().isNotEmpty
          ? titleEn.trim()
          : null,
      needsReview: json['needsReview'] == true,
    );
  }

  /// Stable across years, for example `ns558-004`.
  final String id;

  /// The first SGPC day, and the last. They are equal for an event of 1 day.
  final DateTime first;
  final DateTime last;

  final String titlePa;

  /// Null where the calendar has no English title.
  final String? titleEn;

  /// The file flags the event: it was read from 1 source only, and nobody has
  /// checked the date and the Punjabi title yet.
  final bool needsReview;

  /// The title in the app's language. English falls back to the Punjabi title
  /// when the calendar has no English one.
  String title({required bool punjabi}) =>
      punjabi ? titlePa : (titleEn ?? titlePa);

  @override
  bool operator ==(Object other) =>
      other is SgpcEvent &&
      other.id == id &&
      other.first == first &&
      other.last == last &&
      other.titlePa == titlePa &&
      other.titleEn == titleEn &&
      other.needsReview == needsReview;

  @override
  int get hashCode =>
      Object.hash(id, first, last, titlePa, titleEn, needsReview);

  @override
  String toString() => 'SgpcEvent($id, ${sgpcDayIso(first)}, $titlePa)';
}

/// The events of 1 year's file, or of every file together.
class SgpcEventTable {
  SgpcEventTable(Iterable<SgpcEvent> events)
      : this._(List<SgpcEvent>.unmodifiable(events));

  SgpcEventTable._(this.events) : _byDay = _index(events);

  /// No events at all: the answer when no file can be read.
  static final empty = SgpcEventTable(const []);

  /// Reads 1 file. Throws a [FormatException] if the file is not one.
  ///
  /// An event with `needsReview` is left out, unless [includeUnreviewed] is
  /// set. Its date or its words came from 1 source and no Punjabi reader has
  /// checked them. A wrong name on a shaheedi day is worse than a missing
  /// day.
  factory SgpcEventTable.fromJsonString(
    String source, {
    bool includeUnreviewed = false,
  }) {
    final decoded = jsonDecode(source);
    final list = decoded is Map ? decoded['events'] : null;
    if (list is! List) {
      throw const FormatException('An events file has no "events" list.');
    }
    final events = <SgpcEvent>[];
    for (final entry in list) {
      if (entry is! Map<String, dynamic>) {
        throw FormatException('Not an event: $entry');
      }
      final event = SgpcEvent.fromJson(entry);
      if (includeUnreviewed || !event.needsReview) events.add(event);
    }
    return SgpcEventTable(events);
  }

  /// All the tables as 1. A day that more than one table covers lists the
  /// events of the first table first.
  factory SgpcEventTable.merge(Iterable<SgpcEventTable> tables) =>
      SgpcEventTable([for (final t in tables) ...t.events]);

  /// Every event, in file order.
  final List<SgpcEvent> events;

  final Map<DateTime, List<SgpcEvent>> _byDay;

  bool get isEmpty => events.isEmpty;

  /// The events that fall on [day], an SGPC day, in the order of the calendar.
  /// Empty when there are none.
  List<SgpcEvent> on(DateTime day) {
    final d = day.toUtc();
    return _byDay[DateTime.utc(d.year, d.month, d.day)] ?? const [];
  }

  static Map<DateTime, List<SgpcEvent>> _index(Iterable<SgpcEvent> events) {
    final byDay = <DateTime, List<SgpcEvent>>{};
    for (final event in events) {
      for (var day = event.first;
          !day.isAfter(event.last);
          day = DateTime.utc(day.year, day.month, day.day + 1)) {
        (byDay[day] ??= []).add(event);
      }
    }
    return {
      for (final entry in byDay.entries)
        entry.key: List<SgpcEvent>.unmodifiable(entry.value),
    };
  }
}
