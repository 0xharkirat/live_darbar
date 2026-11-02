import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:live_darbar/src/controllers/connectivity_controller.dart';
import 'package:live_darbar/src/controllers/hukamnama_controller.dart';
import 'package:live_darbar/src/controllers/locale_controller.dart';
import 'package:live_darbar/src/controllers/now_playing_controller.dart';
import 'package:live_darbar/src/controllers/sikh_date_controller.dart';
import 'package:live_darbar/src/controllers/update_controller.dart';
import 'package:live_darbar/src/core/app_theme.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/clock.dart';
import 'package:live_darbar/src/models/app_update.dart';
import 'package:live_darbar/src/models/audio_progress_state.dart';
import 'package:live_darbar/src/models/hukamnama.dart';
import 'package:live_darbar/src/models/live_playback_state.dart';
import 'package:live_darbar/src/models/sikh_date.dart';
import 'package:live_darbar/src/views/screens/home_screen.dart';
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

class _Online extends ConnectivityController {
  @override
  Stream<bool> build() => Stream.value(true);
}

class _NoUpdate extends UpdateController {
  @override
  Future<AppUpdate?> build() async => null;
}

class _Locale extends LocaleController {
  _Locale(this.locale);

  final String locale;

  @override
  String build() => locale;
}

/// The date line at the top of home and the Hukamnama card, which carry the
/// day of the month and the ang. In Punjabi both are Gurmukhi digits, to
/// match the Sikh date beside them.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(
    WidgetTester tester, {
    required String locale,
    required DateTime now,
  }) async {
    AppType.tracking = locale != 'pa';
    addTearDown(() => AppType.tracking = true);
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    const idle = NowPlaying(
      index: kLiveIndex,
      action: PlayAction.play,
      started: false,
      live: LivePlaybackState(),
    );
    final overrides = <Override>[
      nowPlayingProvider.overrideWithValue(idle),
      livePlaybackProvider.overrideWith((ref) => Stream.value(idle.live!)),
      audioProgressProvider.overrideWith(
        (ref) => Stream.value(
          const AudioProgressState(
            position: Duration(minutes: 3),
            bufferedPosition: Duration(minutes: 6),
            totalDuration: null,
            isLive: true,
          ),
        ),
      ),
      connectivityController.overrideWith(_Online.new),
      updateController.overrideWith(_NoUpdate.new),
      localeController.overrideWith(() => _Locale(locale)),
      clockProvider.overrideWithValue(() => now),
      sikhDateProvider.overrideWith(
        (ref) async => SikhDate(
          day: 17,
          monthIndex: 7,
          year: 558,
          gregorian: DateTime.utc(2026, 11, 2),
        ),
      ),
      hukamnamaProvider.overrideWith(_Fixture.new),
    ];

    await tester.pumpWidget(
      ProviderScope(
        retry: (_, __) => null,
        overrides: overrides,
        child: MaterialApp(
          theme: AppTheme.material,
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  // 2 November 2026, 06:00 UTC: the morning in Amritsar, and a Monday.
  final today = DateTime.utc(2026, 11, 2, 6);
  // 3 November in Amritsar: the Hukamnama of 2 November is yesterday's.
  final nextDay = DateTime.utc(2026, 11, 3, 6);

  testWidgets('Punjabi: the day of the month is a Gurmukhi numeral', (
    tester,
  ) async {
    await pump(tester, locale: 'pa', now: today);

    expect(find.text('ਸੋਮਵਾਰ, ੨ ਨਵੰਬਰ'), findsOneWidget);
    expect(find.text('੧੭ ਕੱਤਕ ੫੫੮'), findsOneWidget);
  });

  testWidgets('English: the date line keeps Latin digits', (tester) async {
    await pump(tester, locale: 'en', now: today);

    expect(find.text('MONDAY, 2 NOVEMBER'), findsOneWidget);
    expect(find.text('17 KATAK 558'), findsOneWidget);
  });

  testWidgets('Punjabi: the Hukamnama card shows the ang in Gurmukhi', (
    tester,
  ) async {
    await pump(tester, locale: 'pa', now: today);

    expect(find.text('ਅੱਜ ਦਾ ਹੁਕਮਨਾਮਾ ਪੜ੍ਹੋ  ·  ਅੰਗ ੬੬੮'), findsOneWidget);
  });

  testWidgets('English: the Hukamnama card shows the ang in Latin digits', (
    tester,
  ) async {
    await pump(tester, locale: 'en', now: today);

    expect(find.text('READ TODAY’S HUKAMNAMA  ·  ANG 668'), findsOneWidget);
  });

  testWidgets('Punjabi: yesterday’s card names its day in Gurmukhi', (
    tester,
  ) async {
    await pump(tester, locale: 'pa', now: nextDay);

    expect(find.text('੨ ਨਵੰਬਰ ਦਾ ਹੁਕਮਨਾਮਾ  ·  ਅੰਗ ੬੬੮'), findsOneWidget);
  });

  testWidgets('English: yesterday’s card keeps Latin digits', (tester) async {
    await pump(tester, locale: 'en', now: nextDay);

    expect(find.text('HUKAMNAMA OF 2 NOVEMBER  ·  ANG 668'), findsOneWidget);
  });
}
