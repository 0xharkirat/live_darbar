import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:live_darbar/l10n/app_localizations_en.dart';
import 'package:live_darbar/l10n/app_localizations_pa.dart';
import 'package:live_darbar/src/home_screen_widget/widget_data.dart';
import 'package:live_darbar/src/models/hukamnama.dart';

/// The recorded 2 November 2026 Hukamnama: Dhanaasree, Ang 668.
Hukamnama recorded() => Hukamnama.fromSgpc(
      jsonDecode(
        File('test/fixtures/sgpc_hukamnama_2026_11_02.json').readAsStringSync(),
      ) as Map<String, dynamic>,
    );

Hukamnama onDay(Hukamnama h, DateTime day) => Hukamnama(
      date: day,
      ang: h.ang,
      lines: h.lines,
    );

/// The labels JSON of a built map, decoded.
Map<String, dynamic> labels(Map<String, String> data) =>
    jsonDecode(data[WidgetKeys.labels]!) as Map<String, dynamic>;

/// 10:00 IST on Monday 2 November 2026.
final monday = DateTime.utc(2026, 11, 2, 4, 30);

Map<String, String> build({
  String language = 'en',
  DateTime? now,
  Hukamnama? hukamnama,
}) =>
    buildWidgetData(
      now: now ?? monday,
      language: language,
      l10n: language == 'pa' ? AppLocalizationsPa() : AppLocalizationsEn(),
      hukamnama: hukamnama,
    );

Map<String, String> datesOf(Map<String, String> data) =>
    (jsonDecode(data[WidgetKeys.dates]!) as Map<String, dynamic>)
        .cast<String, String>();

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('pa');
  });

  group('the title', () {
    test('is the app\'s word for the Hukamnama, in its language', () {
      expect(build()[WidgetKeys.title], 'Hukamnama');
      expect(build(language: 'pa')[WidgetKeys.title], 'ਹੁਕਮਨਾਮਾ');
    });
  });

  group('the dates', () {
    test('read like "2 Nov" in English', () {
      expect(datesOf(build())['2026-11-02'], '2 Nov');
    });

    test('use Gurmukhi digits in Punjabi', () {
      final date = datesOf(build(language: 'pa'))['2026-11-02']!;
      expect(date, matches(RegExp(r'^੨ \S+$')));
      expect(date, isNot(matches(RegExp('[0-9]'))));
    });

    test('cover today and the days after it, once each', () {
      final dates = datesOf(build());
      expect(dates.keys.toList(), [
        '2026-11-02',
        '2026-11-03',
        '2026-11-04',
        '2026-11-05',
        '2026-11-06',
        '2026-11-07',
        '2026-11-08',
      ]);
      expect(dates['2026-11-03'], '3 Nov');
    });

    test('use the SGPC day, not the phone\'s', () {
      // 19:00 UTC on 1 November is already 2 November at Amritsar.
      final dates = datesOf(build(now: DateTime.utc(2026, 11, 1, 19)));
      expect(dates.keys.first, '2026-11-02');
      expect(dates.values.first, '2 Nov');
    });
  });

  group('the Hukamnama part', () {
    test('holds the Rahao line, and its own day and Ang for the top line', () {
      final h = recorded();
      final data = build(hukamnama: h);
      expect(data[WidgetKeys.line], hukamnamaPreviewLine(h)!.gurmukhi);
      expect(data[WidgetKeys.line], contains('ਰਹਾਉ'));
      expect(data[WidgetKeys.hukamnamaMeta], '2 Nov · Ang 668');
    });

    test('names its own day when the text is an earlier one', () {
      final h = onDay(recorded(), DateTime.utc(2026, 11, 1));
      expect(build(hukamnama: h)[WidgetKeys.hukamnamaMeta], '1 Nov · Ang 668');
    });

    test('is in Punjabi when the app is, with Gurmukhi digits', () {
      final data = build(language: 'pa', hukamnama: recorded());
      expect(data[WidgetKeys.language], 'pa');
      expect(data[WidgetKeys.hukamnamaMeta], matches(RegExp(r'^੨ \S+ · ਅੰਗ ੬੬੮$')));
    });

    test('leaves out the Ang when SGPC gave none', () {
      final h = Hukamnama(
        date: DateTime.utc(2026, 11, 1),
        lines: recorded().lines,
      );
      expect(build(hukamnama: h)[WidgetKeys.hukamnamaMeta], '1 Nov');
    });

    test('is left out entirely until a text has loaded', () {
      final data = build();
      for (final key in WidgetKeys.hukamnamaKeys) {
        expect(data.containsKey(key), isFalse, reason: key);
      }
      // The title, the dates and the labels are still written.
      expect(data.containsKey(WidgetKeys.title), isTrue);
      expect(data.containsKey(WidgetKeys.dates), isTrue);
      expect(data.containsKey(WidgetKeys.labels), isTrue);
    });
  });

  group('the labels', () {
    test('name the two buttons, the same in every state', () {
      expect(labels(build())['name'], {
        'live': 'Live Kirtan',
        'hukamnama': 'Hukamnama',
      });
      expect(labels(build(language: 'pa'))['name'], {
        'live': 'ਲਾਈਵ ਕੀਰਤਨ',
        'hukamnama': 'ਹੁਕਮਨਾਮਾ',
      });
    });

    test('say, for each button in each state, what the next tap does', () {
      final en = labels(build());
      expect(en['live'], {
        'idle': 'Play live kirtan',
        'loading': 'Live kirtan, starting. Double tap to cancel.',
        'playing': 'Live kirtan, playing. Double tap to stop.',
        'paused': 'Live kirtan, paused. Double tap to play.',
      });
      expect(en['hukamnama'], {
        'idle': 'Play today’s Hukamnama',
        'loading': 'Hukamnama, starting. Double tap to cancel.',
        'playing': 'Hukamnama, playing. Double tap to pause.',
        'paused': 'Hukamnama, paused. Double tap to resume.',
      });
      expect(build()[WidgetKeys.openLabel], 'Read today’s Hukamnama');
    });

    test('hold the visible name inside what a screen reader says', () {
      // A voice user says the name they see, so the spoken label contains it.
      for (final language in ['en', 'pa']) {
        final words = labels(build(language: language));
        final names = (words['name'] as Map).cast<String, String>();
        for (final button in ['live', 'hukamnama']) {
          final idle = (words[button] as Map)['idle'] as String;
          expect(
            idle.toLowerCase(),
            contains(names[button]!.toLowerCase()),
            reason: '$language $button',
          );
        }
      }
    });

    test('name every state in Punjabi too, with the state in the words', () {
      final pa = labels(build(language: 'pa'));
      for (final button in ['live', 'hukamnama']) {
        final words = (pa[button] as Map).cast<String, String>();
        expect(words.keys, kWidgetControlStates);
        // No state falls back to the English or to a copy of another state.
        expect(words.values.toSet().length, 4, reason: button);
        for (final text in words.values) {
          expect(text, matches(RegExp('[਀-੿]')), reason: button);
        }
      }
    });

    test('add no letter spacing to Gurmukhi', () {
      // Spacing is an Android view setting and the store holds text only.
      // This guards against anyone putting thin or zero-width spaces into the
      // strings to fake it, which splits Gurmukhi conjuncts.
      final data = build(language: 'pa', hukamnama: recorded());
      for (final value in data.values) {
        expect(value, isNot(contains(' ')));
        expect(value, isNot(contains(' ')));
        expect(value, isNot(contains('​')));
      }
    });

    test('every value is a string and the keys are the documented ones', () {
      final data = build(hukamnama: recorded());
      expect(data.keys.toSet(), {
        WidgetKeys.language,
        WidgetKeys.title,
        WidgetKeys.dates,
        WidgetKeys.openLabel,
        WidgetKeys.labels,
        ...WidgetKeys.hukamnamaKeys,
      });
    });
  });

  test('widgetLanguage falls back to English', () {
    expect(widgetLanguage('pa'), 'pa');
    expect(widgetLanguage('en'), 'en');
    expect(widgetLanguage('fr'), 'en');
    expect(widgetLanguage(null), 'en');
  });
}
