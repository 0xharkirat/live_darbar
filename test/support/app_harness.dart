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
import 'package:live_darbar/src/core/app_version.dart';
import 'package:live_darbar/src/core/platform.dart';
import 'package:live_darbar/src/models/app_update.dart';
import 'package:live_darbar/src/models/audio_progress_state.dart';
import 'package:live_darbar/src/models/hukamnama.dart';
import 'package:live_darbar/src/models/live_playback_state.dart';
import 'package:live_darbar/src/views/app_router.dart';
import 'package:live_darbar/src/views/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app as `main.dart` builds it, with every network and platform
/// dependency replaced, so a test can open pages, sheets and the back button.

/// Nothing has played yet.
const idle = NowPlaying(
  index: kLiveIndex,
  action: PlayAction.play,
  started: false,
  live: LivePlaybackState(),
);

/// Live kirtan, playing: the state in which the mini player is on screen.
const livePlaying = NowPlaying(
  index: kLiveIndex,
  action: PlayAction.stop,
  started: true,
  live: LivePlaybackState(status: LiveStatus.playing),
);

/// Today's Hukamnama recording, playing: the player then offers Read.
const recordingPlaying = NowPlaying(
  index: kMukhwakIndex,
  action: PlayAction.pause,
  started: true,
  live: LivePlaybackState(status: LiveStatus.playing, isLiveSource: false),
);

/// The real Hukamnama for 2 November 2026, as SGPC's feed served it.
class FixtureHukamnama extends HukamnamaController {
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

class NoUpdate extends UpdateController {
  @override
  Future<AppUpdate?> build() async => null;
}

class _Locale extends LocaleController {
  _Locale(this.locale);

  final String locale;

  @override
  String build() => locale;
}

/// Phone sized: 402 x 874 points, an iPhone 17 Pro.
const phone = Size(1206, 2622);

/// A laptop window: 1280 x 800 points.
const desktop = Size(1280, 800);

/// Pumps the app on [size] ([phone] or [desktop]).
///
/// [web] picks the page transition and the web's layout, the way `kIsWeb`
/// does in the app.
/// [initialRoute] is what a browser hands the app after the `#`.
Future<void> pumpApp(
  WidgetTester tester, {
  String locale = 'en',
  Size size = phone,
  bool web = false,
  String initialRoute = AppRoutes.home,
  NowPlaying now = idle,
}) async {
  SharedPreferences.setMockInitialValues({});
  AppType.tracking = locale != 'pa';
  addTearDown(() => AppType.tracking = true);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = size == phone ? 3 : 1;
  addTearDown(tester.view.reset);

  final overrides = <Override>[
    nowPlayingProvider.overrideWithValue(now),
    livePlaybackProvider.overrideWith(
      (ref) => Stream.value(now.live ?? const LivePlaybackState()),
    ),
    audioProgressProvider.overrideWith(
      (ref) => Stream.value(
        AudioProgressState(
          position: const Duration(minutes: 3),
          bufferedPosition: const Duration(minutes: 6),
          totalDuration: now.isLive ? null : const Duration(minutes: 9),
          isLive: now.isLive,
        ),
      ),
    ),
    connectivityController.overrideWith(_Online.new),
    updateController.overrideWith(NoUpdate.new),
    localeController.overrideWith(() => _Locale(locale)),
    sangrandTableProvider.overrideWith((ref) async => null),
    sikhDateProvider.overrideWith((ref) async => null),
    hukamnamaProvider.overrideWith(FixtureHukamnama.new),
    appVersionProvider.overrideWith((ref) async => '2.2.1 (9)'),
    isWebProvider.overrideWithValue(web),
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
        initialRoute: initialRoute,
        home: const HomeScreen(),
        onGenerateRoute: AppRoutes.generator(web: web),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Stands in for Reduce Motion, the way the operating system sets it.
void reduceMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}
