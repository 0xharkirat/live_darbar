import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:live_darbar/src/controllers/hukamnama_controller.dart';
import 'package:live_darbar/src/controllers/locale_controller.dart';
import 'package:live_darbar/src/controllers/now_playing_controller.dart';
import 'package:live_darbar/src/controllers/sikh_date_controller.dart';
import 'package:live_darbar/src/core/app_theme.dart';
import 'package:live_darbar/src/core/clock.dart';
import 'package:live_darbar/src/models/hukamnama.dart';
import 'package:live_darbar/src/models/live_playback_state.dart';
import 'package:live_darbar/src/models/sikh_date.dart';
import 'package:live_darbar/src/views/screens/hukamnama_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The real Hukamnama for 2 November 2026, as SGPC's feed served it.
class _Fixture extends HukamnamaController {
  @override
  Future<Hukamnama> build() async {
    final json =
        File('test/fixtures/sgpc_hukamnama_2026_11_02.json').readAsStringSync();
    return Hukamnama.fromSgpc(jsonDecode(json) as Map<String, dynamic>);
  }
}

class _Locale extends LocaleController {
  _Locale(this.locale);

  final String locale;

  @override
  String build() => locale;
}

/// The table the app ships, read straight from the asset file.
SangrandTable _shippedTable() => SangrandTable.fromJsonString(
      File('assets/data/sgpc_sangrands.json').readAsStringSync(),
    );

/// The line under the title, which SGPC's footer used to fill with
/// "Monday, 17th Katak (Samvat 558 Nanakshahi)".
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(
    WidgetTester tester, {
    required String locale,
    SangrandTable? table,
    DateTime? now,
  }) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (now != null) clockProvider.overrideWithValue(() => now),
          hukamnamaProvider.overrideWith(_Fixture.new),
          localeController.overrideWith(() => _Locale(locale)),
          sangrandTableProvider.overrideWith((ref) async => table),
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

  testWidgets('English: ang, Sikh date, everyday date', (tester) async {
    await pump(tester, locale: 'en', table: _shippedTable());

    expect(find.text('Ang 668 · 17 Katak 558 · 2 November'), findsOneWidget);
    expect(find.textContaining('Monday'), findsNothing);
    expect(find.textContaining('Nanakshahi'), findsNothing);
  });

  testWidgets('Punjabi: Gurmukhi digits for the Sikh date', (tester) async {
    await pump(tester, locale: 'pa', table: _shippedTable());

    // One numeral system on the whole line: the ang, the Sikh date and the
    // day of the month are all in Gurmukhi digits.
    expect(find.text('ਅੰਗ ੬੬੮ · ੧੭ ਕੱਤਕ ੫੫੮ · ੨ ਨਵੰਬਰ'), findsOneWidget);
    expect(find.textContaining('ਨਾਨਕਸ਼ਾਹੀ'), findsNothing);
  });

  testWidgets('Punjabi: the older-Hukamnama note names its day in Gurmukhi', (
    tester,
  ) async {
    // 3 November in Amritsar, so the Hukamnama of 2 November is yesterday's.
    await pump(
      tester,
      locale: 'pa',
      table: _shippedTable(),
      now: DateTime.utc(2026, 11, 3, 6),
    );

    expect(
      find.text('ਅੱਜ ਦਾ ਹੁਕਮਨਾਮਾ ਅਜੇ ਨਹੀਂ ਆਇਆ। ਇਹ ੨ ਨਵੰਬਰ ਦਾ ਹੈ।'),
      findsOneWidget,
    );
  });

  testWidgets('English: the older-Hukamnama note keeps Latin digits', (
    tester,
  ) async {
    await pump(
      tester,
      locale: 'en',
      table: _shippedTable(),
      now: DateTime.utc(2026, 11, 3, 6),
    );

    expect(
      find.text(
        'Today’s Hukamnama is not out yet. This is the one from 2 November.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('without a Sikh date, shows the ang and the date only', (
    tester,
  ) async {
    await pump(tester, locale: 'en');

    expect(find.text('Ang 668 · 2 November'), findsOneWidget);
  });
}
