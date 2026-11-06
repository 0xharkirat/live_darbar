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
  Future<void> pump(
    WidgetTester tester,
    Hukamnama day, {
    String locale = 'en',
  }) async {
    SharedPreferences.setMockInitialValues({'locale': locale});
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

  testWidgets('puts the Punjabi meaning under each line in Punjabi', (
    tester,
  ) async {
    final day = _mirrorDay();
    await pump(tester, day, locale: 'pa');

    final first = day.shabad!.lines.first;
    expect(find.text(first.punjabi!), findsOneWidget);
    expect(find.text(first.english!), findsNothing);
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
    await tester.scrollUntilVisible(
      find.textContaining('Dr. Sant Singh Khalsa'),
      400,
      // Each SelectableText scrolls too, so name the page.
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.textContaining('Jaswant S. Dauder'), findsOneWidget);
  });

  testWidgets('shows SGPC\'s lines as before when the mirror had none', (
    tester,
  ) async {
    final day = _sgpcDay();
    await pump(tester, day);

    expect(find.text(day.lines.first.gurmukhi), findsOneWidget);
    expect(find.textContaining('Dr. Sant Singh Khalsa'), findsNothing);
  });
}
