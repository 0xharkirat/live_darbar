import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:live_darbar/src/controllers/hukamnama_controller.dart';
import 'package:live_darbar/src/controllers/now_playing_controller.dart';
import 'package:live_darbar/src/controllers/sikh_date_controller.dart';
import 'package:live_darbar/src/core/app_theme.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/models/hukamnama.dart';
import 'package:live_darbar/src/models/sikh_date.dart';
import 'package:live_darbar/src/core/clock.dart';
import 'package:live_darbar/src/models/live_playback_state.dart';
import 'package:live_darbar/src/services/reminder_platform.dart';
import 'package:live_darbar/src/views/screens/hukamnama_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_reminder_platform.dart';

/// 2 November 2026 as the mirror holds it: SGPC's answer, plus the lines with
/// a meaning under each and the pause marks.
Hukamnama _mirrorDay() => Hukamnama.fromSgpc(
      jsonDecode(
        File('test/fixtures/mirror_hukamnama_2026_11_02.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>,
    );

/// The same day as SGPC alone gives it, with no lines from the mirror.
Hukamnama _sgpcDay() => Hukamnama.fromSgpc(
      jsonDecode(
        File('test/fixtures/sgpc_hukamnama_2026_11_02.json').readAsStringSync(),
      ) as Map<String, dynamic>,
    );

class _Feed extends HukamnamaController {
  _Feed(this.day);

  final Hukamnama day;

  @override
  Future<Hukamnama> build() async => day;
}

/// Hark, 6 November: "I thought we were going to have line by line meaning",
/// with Chet's colours so the Gurbani is not "a big boring wall of text".
void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  Future<void> pump(
    WidgetTester tester,
    Hukamnama day, {
    String locale = 'en',
    Map<String, Object> saved = const {},
    DateTime? now,
    SikhDate? sikh,
  }) async {
    SharedPreferences.setMockInitialValues({'locale': locale, ...saved});
    // Tall, so the first lines are all built at once: the list is lazy.
    tester.view.physicalSize = const Size(1206, 6000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderPlatformProvider.overrideWithValue(
            FakeReminderPlatform(supported: false),
          ),
          hukamnamaProvider.overrideWith(() => _Feed(day)),
          sangrandTableProvider.overrideWith((ref) async => null),
          if (now != null) clockProvider.overrideWithValue(() => now),
          if (sikh != null) sikhDateProvider.overrideWith((ref) async => sikh),
          nowPlayingProvider.overrideWithValue(
            const NowPlaying(
              index: kLiveIndex,
              action: PlayAction.play,
              started: false,
              live: LivePlaybackState(),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.material,
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HukamnamaScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// The Gurmukhi of a line, as the spans the reader draws it with.
  List<TextSpan> spansOf(WidgetTester tester, String gurmukhi) {
    final text = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .where((t) => t.textSpan?.toPlainText() == gurmukhi)
        .single;
    return [
      for (final span in text.textSpan!.children!)
        if (span is TextSpan && span.text!.trim().isNotEmpty) span,
    ];
  }

  /// Opens the reading options, the Aa button in the top bar.
  Future<void> openOptions(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('reader-options')));
    await tester.pumpAndSettle();
  }

  /// Closes the reading options with the back gesture.
  Future<void> closeOptions(WidgetTester tester) async {
    Navigator.of(tester.element(find.byKey(const ValueKey('reader-sheet'))))
        .pop();
    await tester.pumpAndSettle();
  }

  /// Scrolls the page to its last line, the source link.
  Future<void> scrollToEnd(WidgetTester tester) => tester.scrollUntilVisible(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              (w.data == en.text_source(kHukamnamaSourceName) ||
                  w.data == en.hukamnama_source(kHukamnamaSourceName)),
        ),
        400,
        // Each SelectableText scrolls too, so name the page.
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );

  testWidgets('puts the English meaning under each line', (tester) async {
    final day = _mirrorDay();
    await pump(tester, day);

    final lines = day.shabad!.lines;
    for (final i in [0, 1]) {
      final line = tester.getTopLeft(find.text(lines[i].gurmukhi));
      final meaning = tester.getTopLeft(find.text(lines[i].english!));
      final next = tester.getTopLeft(find.text(lines[i + 1].gurmukhi));
      expect(meaning.dy, greaterThan(line.dy), reason: 'under its line');
      expect(meaning.dy, lessThan(next.dy), reason: 'before the next line');
    }
  });

  // Hark, 7 November: "punjabi meaning as well line by line", Punjabi and
  // English by default, and a choice for the listener.
  for (final locale in ['en', 'pa']) {
    testWidgets(
        'puts the Punjabi, then the English meaning under each line '
        '($locale)', (tester) async {
      final day = _mirrorDay();
      await pump(tester, day, locale: locale);

      final lines = day.shabad!.lines;
      for (final i in [0, 1]) {
        final line = tester.getTopLeft(find.text(lines[i].gurmukhi)).dy;
        final punjabi = tester.getTopLeft(find.text(lines[i].punjabi!)).dy;
        final english = tester.getTopLeft(find.text(lines[i].english!)).dy;
        final next = tester.getTopLeft(find.text(lines[i + 1].gurmukhi)).dy;
        expect(punjabi, greaterThan(line), reason: 'Punjabi under its line');
        expect(english, greaterThan(punjabi), reason: 'English under Punjabi');
        expect(english, lessThan(next), reason: 'both before the next line');
      }
    });
  }

  testWidgets('turns a meaning off, and remembers it', (tester) async {
    final day = _mirrorDay();
    final first = day.shabad!.lines.first;
    await pump(tester, day);

    await openOptions(tester);
    await tester.tap(find.byKey(const ValueKey('reader-meaning-english')));
    await tester.pump(const Duration(milliseconds: 400));
    await closeOptions(tester);
    expect(find.text(first.english!), findsNothing);
    expect(find.text(first.punjabi!), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('reader_meaning_english'), isFalse);

    // The next visit opens the same way.
    await pump(tester, day, saved: {'reader_meaning_english': false});
    expect(find.text(first.english!), findsNothing);
    expect(find.text(first.punjabi!), findsOneWidget);

    await openOptions(tester);
    await tester.tap(find.byKey(const ValueKey('reader-meaning-english')));
    await tester.pump(const Duration(milliseconds: 400));
    await closeOptions(tester);
    expect(find.text(first.english!), findsOneWidget);
  });

  // Hark, 7 November: the reader "looks so crowded with so many buttons".
  group('fewer controls', () {
    testWidgets('the top bar has the bell and Aa, and no A− or A+', (
      tester,
    ) async {
      await pump(tester, _mirrorDay());
      expect(find.byKey(const ValueKey('reader-options')), findsOneWidget);
      expect(find.text('A+'), findsNothing);
      expect(find.text('A−'), findsNothing);
    });

    testWidgets('under the date: Listen and Share only, on 1 row', (
      tester,
    ) async {
      await pump(tester, _mirrorDay());
      final listen = tester.getRect(find.text(en.listen));
      final share = tester.getRect(find.text(en.share));
      expect((listen.center.dy - share.center.dy).abs(), lessThan(2));
      expect(find.byKey(const ValueKey('reader-meaning-english')), findsNothing,
          reason: 'the meanings are in the reading options');
    });

    testWidgets('SGPC PDF is at the end, after the last line', (tester) async {
      final day = _mirrorDay();
      await pump(tester, day);
      await scrollToEnd(tester);
      final last = tester.getRect(find.text(day.shabad!.lines.last.gurmukhi));
      final pdf = tester.getRect(find.text(en.sgpc_pdf));
      expect(pdf.top, greaterThan(last.bottom));
    });

    testWidgets('Aa opens the text size and the meanings', (tester) async {
      await pump(tester, _mirrorDay());
      await openOptions(tester);
      expect(find.text(en.reader_text_size), findsOneWidget);
      expect(find.text('A+'), findsOneWidget);
      expect(find.text(en.reader_meanings), findsOneWidget);
      expect(
          find.byKey(const ValueKey('reader-meaning-punjabi')), findsOneWidget);
    });

    testWidgets('Aa makes the text larger, and the lines follow', (
      tester,
    ) async {
      final day = _mirrorDay();
      await pump(tester, day);
      double size() => tester
          .widget<SelectableText>(find
              .ancestor(
                of: find.text(day.shabad!.lines.first.gurmukhi),
                matching: find.byType(SelectableText),
              )
              .first)
          .textSpan!
          .style!
          .fontSize!;
      final before = size();

      await openOptions(tester);
      await tester.tap(find.text('A+'));
      await tester.pump();
      await closeOptions(tester);
      expect(size(), greaterThan(before));
    });
  });

  testWidgets('shows the Gurbani alone with both meanings off', (
    tester,
  ) async {
    final day = _mirrorDay();
    final first = day.shabad!.lines.first;
    await pump(
      tester,
      day,
      saved: {'reader_meaning_punjabi': false, 'reader_meaning_english': false},
    );

    expect(find.text(first.gurmukhi), findsOneWidget);
    expect(find.text(first.punjabi!), findsNothing);
    expect(find.text(first.english!), findsNothing);
  });

  // Hark, 7 November: the title should be Sidh Gosht's, and "ik onkar also
  // have meanings".
  group('the title', () {
    Hukamnama nov7() => Hukamnama.fromSgpc(
          jsonDecode(
            File('test/fixtures/mirror_hukamnama_2026_11_07.json')
                .readAsStringSync(),
          ) as Map<String, dynamic>,
        );

    testWidgets('is the Granth\'s title from the mirror, not SGPC\'s', (
      tester,
    ) async {
      await pump(tester, nov7());
      expect(find.text('ਰਾਮਕਲੀ ਮਹਲਾ ੧ ਸਿਧ ਗੋਸਟਿ ॥'), findsOneWidget);
      expect(find.text('ੴ ਸਤਿਗੁਰ ਪ੍ਰਸਾਦਿ ॥'), findsOneWidget);
      expect(find.textContaining('ਦਖਣੀ ਓਅੰਕਾਰ'), findsNothing);
    });

    testWidgets('has its meanings under each title line', (tester) async {
      final day = nov7();
      await pump(tester, day);
      final onkar = tester.getTopLeft(find.text('ੴ ਸਤਿਗੁਰ ਪ੍ਰਸਾਦਿ ॥')).dy;
      final english = tester
          .getTopLeft(find.text(
              'One Universal Creator God. By The Grace Of The True Guru:'))
          .dy;
      final firstLine =
          tester.getTopLeft(find.text(day.shabad!.lines.first.gurmukhi)).dy;
      expect(english, greaterThan(onkar));
      expect(english, lessThan(firstLine));
      expect(find.textContaining('ਅਕਾਲ ਪੁਰਖ ਇੱਕ ਹੈ'), findsOneWidget);
    });

    testWidgets('follows the meaning switches', (tester) async {
      await pump(tester, nov7(), saved: {'reader_meaning_english': false});
      expect(
        find.text('One Universal Creator God. By The Grace Of The True Guru:'),
        findsNothing,
      );
      expect(find.textContaining('ਅਕਾਲ ਪੁਰਖ ਇੱਕ ਹੈ'), findsOneWidget);
    });
  });

  // Hark, 7 November: "as tradition, whenever it is Sangrand, after the
  // normal Hukamnama, there is Sangrand Hukamnama recited". The reader reads
  // the month's pauri of Barah Maha after today's Hukamnama on Sangrand day.
  group('on Sangrand day', () {
    // 10:00 IST on 2 November 2026, which these tests treat as 1 Katak.
    final morning = DateTime.utc(2026, 11, 2, 4, 30);
    SikhDate katak(int day) => SikhDate(
          day: day,
          monthIndex: 7,
          year: 558,
          gregorian: DateTime.utc(2026, 11, 2),
        );
    const pauri = 'ਕਤਿਕਿ ਕਰਮ ਕਮਾਵਣੇ ਦੋਸੁ ਨ ਕਾਹੂ ਜੋਗੁ ॥';
    final page = find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first;

    testWidgets('reads the month\'s pauri after the Hukamnama', (tester) async {
      final day = _mirrorDay();
      await pump(tester, day, now: morning, sikh: katak(1));
      // To the Hukamnama's last line, then only down to the pauri: it comes
      // after. The list is lazy, so the 2 may not be built at once.
      await tester.scrollUntilVisible(
        find.text(day.shabad!.lines.last.gurmukhi),
        400,
        scrollable: page,
      );
      await tester.scrollUntilVisible(
        find.text(en.sangrand_title),
        200,
        scrollable: page,
      );
      await tester.scrollUntilVisible(find.text(pauri), 200, scrollable: page);
      await tester.pumpAndSettle();
      expect(find.text(pauri), findsOneWidget);
      expect(
        find.textContaining('In the month of Katak, do good deeds.'),
        findsOneWidget,
      );
    });

    testWidgets('reads nothing more on another day of the month', (
      tester,
    ) async {
      await pump(tester, _mirrorDay(), now: morning, sikh: katak(22));
      await scrollToEnd(tester);
      expect(find.text(pauri), findsNothing);
      expect(find.text(en.sangrand_title), findsNothing);
    });

    testWidgets('reads nothing more over an earlier day\'s Hukamnama', (
      tester,
    ) async {
      // Before SGPC posts on Sangrand day, the reader shows yesterday's.
      await pump(
        tester,
        _mirrorDay(),
        now: DateTime.utc(2026, 11, 3, 0, 30),
        sikh: katak(1),
      );
      await scrollToEnd(tester);
      expect(find.text(pauri), findsNothing);
    });
  });

  testWidgets('drops the meaning of the whole shabad at the end', (
    tester,
  ) async {
    // The meanings under the lines take its place. Hark, 7 November: "remove
    // the punjabi and english para blob at the end".
    final day = _mirrorDay();
    await pump(tester, day);
    await scrollToEnd(tester);

    expect(find.text(en.meaning), findsNothing);
    expect(find.textContaining(day.englishMeaning!.substring(0, 40)),
        findsNothing);
  });

  testWidgets('colours the word before a long pause and a short pause', (
    tester,
  ) async {
    await pump(tester, _mirrorDay());

    // ਹਰਿ ਬਿਨੁ ਰਹਿ ਨ ਸਕਉ ਇਕ ਰਾਤੀ ॥ has a short pause after ਬਿਨੁ and a long
    // one after ਸਕਉ.
    final spans = spansOf(tester, 'ਹਰਿ ਬਿਨੁ ਰਹਿ ਨ ਸਕਉ ਇਕ ਰਾਤੀ ॥');
    Color? colourOf(String word) =>
        spans.singleWhere((s) => s.text!.trim() == word).style?.color;

    expect(colourOf('ਬਿਨੁ'), Palette.pauseShort);
    expect(colourOf('ਸਕਉ'), Palette.pauseLong);
    expect(colourOf('ਰਹਿ'), isNull,
        reason: 'the other words keep the text colour');
  });

  testWidgets('names who wrote the meanings and the pauses', (tester) async {
    await pump(tester, _mirrorDay());
    await scrollToEnd(tester);
    final credit = find.textContaining('Jaswant S. Dauder');
    expect(credit, findsOneWidget);
    final text = tester.widget<Text>(credit).data!;
    expect(text, contains('Prof. Sahib Singh'));
    expect(text, contains('Dr. Sant Singh Khalsa'));
  });

  // Hark, 7 November: "why does it still say text and meaning from SGPC?"
  // The meanings under the lines are Shabad OS's, so SGPC is named for the
  // Hukamnama and its text only.
  testWidgets('names SGPC for the Hukamnama, not for the meanings', (
    tester,
  ) async {
    await pump(tester, _mirrorDay());
    await scrollToEnd(tester);
    expect(
        find.text(en.hukamnama_source(kHukamnamaSourceName)), findsOneWidget);
    expect(find.text(en.text_source(kHukamnamaSourceName)), findsNothing);
  });

  testWidgets('names only the meanings it shows', (tester) async {
    await pump(tester, _mirrorDay(), saved: {'reader_meaning_english': false});
    await scrollToEnd(tester);
    final text =
        tester.widget<Text>(find.textContaining('Jaswant S. Dauder')).data!;
    expect(text, contains('Prof. Sahib Singh'));
    expect(text, isNot(contains('Dr. Sant Singh Khalsa')));
  });

  testWidgets('shows SGPC\'s lines as before when the mirror had none', (
    tester,
  ) async {
    final day = _sgpcDay();
    await pump(tester, day);

    expect(find.text(day.lines.first.gurmukhi), findsOneWidget);
    expect(find.textContaining('Dr. Sant Singh Khalsa'), findsNothing);
    // No meanings under the lines to choose, so the options have no choice.
    await openOptions(tester);
    expect(find.text(en.reader_text_size), findsOneWidget);
    expect(find.byKey(const ValueKey('reader-meaning-english')), findsNothing);
    await closeOptions(tester);

    // SGPC's meaning of the whole shabad is then the only meaning, so it stays,
    // and SGPC is named for it.
    await scrollToEnd(tester);
    expect(find.text(en.meaning), findsOneWidget);
    expect(find.text(en.text_source(kHukamnamaSourceName)), findsOneWidget);
  });
}
