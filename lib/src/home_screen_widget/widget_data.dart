/// What the home screen widget shows, as plain strings.
///
/// The widget is drawn by the phone's launcher, outside this app, so it can
/// only be handed text. Flutter writes the text to a small store, and the
/// native side (`LiveDarbarWidgetProvider.kt`) reads the same keys back. The
/// Android store is a `SharedPreferences` file named `HomeWidgetPreferences`.
///
/// Everything a listener can read is made here, in the app's language, from
/// the app's own strings. The native side only picks between the parts.
///
/// The widget says what it is in its top line, `Hukamnama · 2 Nov · Ang 668`,
/// and its two buttons keep their names, Hukamnama and Live Kirtan, in every
/// state.
library;

import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/core/reader_numbers.dart';
import 'package:live_darbar/src/models/hukamnama.dart';
import 'package:live_darbar/src/models/sgpc_day.dart';

/// The fully qualified name of the Android `AppWidgetProvider`.
///
/// `HomeWidget.updateWidget` finds the widget by this name.
const kWidgetProviderClass =
    'com.hsi.harki.live_darbar.widget.LiveDarbarWidgetProvider';

/// The `kind` of the iPhone widget in LiveDarbarWidget.swift.
///
/// `HomeWidget.updateWidget` reloads the iPhone widget by this name.
const kIosWidgetKind = 'LiveDarbarWidget';

/// The App Group that the iPhone app and its widget share.
///
/// The widget runs in its own process, so it reads the store from here. Both
/// targets name it in their entitlements, and the App IDs at Apple carry it.
const kIosAppGroupId = 'group.com.hsiharki.liveDarbar';

/// How many days of dates are written ahead, today included.
///
/// A phone that has not run the app for days must still show the right date,
/// and the launcher draws the widget without asking the app. So a week of
/// dates is written at once, and the native side takes the one for the day
/// it is. The Hukamnama cannot be written ahead. It is posted each morning.
const kWidgetLookaheadDays = 7;

/// The keys of the store. Kotlin reads the same strings.
abstract final class WidgetKeys {
  /// `en` or `pa`.
  static const language = 'ld_language';

  /// The first word of the top line: `Hukamnama`.
  static const title = 'ld_title';

  /// A JSON object from an SGPC day (`2026-11-02`) to its date (`2 Nov`).
  /// The top line shows today's when there is no Hukamnama to show.
  static const dates = 'ld_dates';

  /// The Rahao line, or the first verse when there is no Rahao.
  static const line = 'ld_line';

  /// The pauses of [line], as JSON: the index of each word that comes before
  /// a pause, and its kind, `{"1": "short", "4": "long"}`. The widget colours
  /// those words as the reader does. `{}` when the line has none.
  static const linePauses = 'ld_line_pauses';

  /// The English meaning of [line], for 1 line under it. Empty when the
  /// line has none, so an earlier line's meaning never stays under this one.
  static const lineMeaning = 'ld_line_meaning';

  /// The rest of the top line beside [line]: its own day and Ang,
  /// `2 Nov · Ang 668`. So a line from an earlier day shows its own date.
  static const hukamnamaMeta = 'ld_hukamnama_meta';

  /// What a screen reader says for the rest of the widget.
  static const openLabel = 'ld_open_label';

  /// The words the buttons need in each state, as JSON. See [widgetLabels].
  static const labels = 'ld_labels';

  /// What the player is doing now, as JSON. Written by
  /// `WidgetPlaybackSync` in widget_playback.dart, never by [buildWidgetData],
  /// so that a new Hukamnama never undoes a playing state.
  static const playback = 'ld_playback';

  /// The keys that belong to the Hukamnama. When there is no text to write,
  /// these are left alone, so a good line from earlier is never replaced by
  /// an empty one.
  static const hukamnamaKeys = [line, linePauses, lineMeaning, hukamnamaMeta];
}

/// The language a widget is written in. Anything the app does not have is
/// English.
String widgetLanguage(String? locale) => locale == 'pa' ? 'pa' : 'en';

/// [day] as the widget writes it: `2 Nov`, or `੨ ਨਵੰ` in Punjabi.
///
/// The month follows the language, so `Intl` must hold the date data for it:
/// call `initializeDateFormatting` first. `Intl` writes the Punjabi day in
/// Latin digits, so the day is set by hand, in Gurmukhi digits as the Ang is.
String widgetDate(DateTime day, {required String language}) {
  final punjabi = language == 'pa';
  final month = DateFormat('MMM', language).format(day);
  return '${readerNumber(day.day, punjabi: punjabi)} $month';
}

/// The dates for [kWidgetLookaheadDays] days from the SGPC day of [now].
///
/// The key is the SGPC day, which is the day at Amritsar. A listener in
/// Vancouver at 20:00 is already in tomorrow there, and the Hukamnama and the
/// date must agree with each other.
Map<String, String> widgetDates({
  required DateTime now,
  required String language,
  int days = kWidgetLookaheadDays,
}) {
  final first = sgpcDayOf(now);
  final dates = <String, String>{};
  for (var i = 0; i < days; i++) {
    final day = DateTime.utc(first.year, first.month, first.day + i);
    dates[sgpcDayIso(day)] = widgetDate(day, language: language);
  }
  return dates;
}

/// The states a button has a description for, in the order of the store.
const kWidgetControlStates = ['idle', 'loading', 'playing', 'paused'];

/// The words the widget's buttons need, in the app's language.
///
/// The widget changes state while the app is closed, so the native side must
/// have every word in advance:
///
/// - `name`: the name on each button, the same in every state.
/// - `live` and `hukamnama`: what a screen reader says for each button in
///   each state, and always which tap comes next ("Double tap to stop").
///
/// The key names are the ones `WidgetStore.kt` reads.
Map<String, Object> widgetLabels(AppLocalizations l10n) => {
      'name': {
        'live': l10n.live_kirtan,
        'hukamnama': l10n.mukhwak,
      },
      'live': {
        for (final state in kWidgetControlStates)
          state: l10n.widget_live_control(state),
      },
      'hukamnama': {
        for (final state in kWidgetControlStates)
          state: l10n.widget_hukamnama_control(state),
      },
    };

/// Everything the widget shows, ready to store.
///
/// Every value is a string. [hukamnama] may be null, as it is until the first
/// text has loaded. Then the Hukamnama keys are left out and the store keeps
/// what it holds.
Map<String, String> buildWidgetData({
  required DateTime now,
  required String language,
  required AppLocalizations l10n,
  required Hukamnama? hukamnama,
}) {
  final data = <String, String>{
    WidgetKeys.language: language,
    WidgetKeys.title: l10n.mukhwak,
    WidgetKeys.dates: jsonEncode(widgetDates(now: now, language: language)),
    WidgetKeys.openLabel: l10n.read_hukamnama,
    WidgetKeys.labels: jsonEncode(widgetLabels(l10n)),
  };

  final line = hukamnama == null ? null : widgetLine(hukamnama);
  if (hukamnama == null || line == null) return data;

  final ang = hukamnama.ang == null
      ? null
      : l10n.hukamnama_ang(
          readerNumber(hukamnama.ang!, punjabi: language == 'pa'),
        );
  return data
    ..[WidgetKeys.line] = line.gurmukhi
    ..[WidgetKeys.linePauses] = jsonEncode(widgetPauses(line))
    ..[WidgetKeys.lineMeaning] = line.english ?? ''
    ..[WidgetKeys.hukamnamaMeta] = [
      widgetDate(hukamnama.date, language: language),
      if (ang != null) ang,
    ].join(' · ');
}

/// The line the widget shows: the Rahao line, by the rule of
/// [hukamnamaPreviewLine]. It comes from the mirror's lines when the day has
/// them, because those carry the pauses and the meanings.
HukamnamaLine? widgetLine(Hukamnama hukamnama) {
  final shabad = hukamnama.shabad;
  if (shabad != null) {
    return hukamnamaPreviewLine(
      Hukamnama(date: hukamnama.date, lines: shabad.lines),
    );
  }
  return hukamnamaPreviewLine(hukamnama);
}

/// The pauses of [line] for the widget: each word's index, and `short` for a
/// light pause or `long` for a medium or heavy one. The reader colours them
/// the same way (Palette.pauseShort and Palette.pauseLong).
Map<String, String> widgetPauses(HukamnamaLine line) => {
      for (final pause in line.vishraam)
        '${pause.after}':
            pause.weight == HukamnamaPause.light ? 'short' : 'long',
    };
