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
import 'package:live_darbar/src/models/hukamnama.dart';
import 'package:live_darbar/src/models/live_playback_state.dart';
import 'package:live_darbar/src/views/screens/hukamnama_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// The real Hukamnama for 2 November 2026, as SGPC's feed served it.
class _Fixture extends HukamnamaController {
  @override
  Future<Hukamnama> build() async {
    final json =
        File('test/fixtures/sgpc_hukamnama_2026_11_02.json').readAsStringSync();
    return Hukamnama.fromSgpc(jsonDecode(json) as Map<String, dynamic>);
  }
}

/// Stands in for the platform behind `url_launcher` and records each launch.
///
/// [inAppResult] and [inAppError] decide how the in-app browser answers. The
/// external browser always opens, so a test can see the fallback land there.
class _FakeLauncher extends UrlLauncherPlatform {
  _FakeLauncher({this.inAppResult = true, this.inAppError});

  final bool inAppResult;
  final Object? inAppError;
  final launches = <({String url, PreferredLaunchMode mode})>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launches.add((url: url, mode: options.mode));
    if (options.mode == PreferredLaunchMode.inAppBrowserView) {
      if (inAppError != null) throw inAppError!;
      return inAppResult;
    }
    return true;
  }
}

void main() {
  const sgpcPdfPage = 'https://hs.sgpc.net/hspdf.php';
  late UrlLauncherPlatform original;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    original = UrlLauncherPlatform.instance;
  });
  tearDown(() => UrlLauncherPlatform.instance = original);

  Future<void> tapSgpcPdf(WidgetTester tester, _FakeLauncher launcher) async {
    UrlLauncherPlatform.instance = launcher;
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hukamnamaProvider.overrideWith(_Fixture.new),
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
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HukamnamaScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('SGPC PDF'));
    await tester.pump();
  }

  testWidgets('SGPC PDF opens the SGPC page in the in-app browser, once', (
    tester,
  ) async {
    final launcher = _FakeLauncher();
    await tapSgpcPdf(tester, launcher);

    expect(launcher.launches, hasLength(1));
    expect(launcher.launches.single.url, sgpcPdfPage);
    expect(launcher.launches.single.mode, PreferredLaunchMode.inAppBrowserView);
  });

  testWidgets('falls back to the browser when the in-app one will not open', (
    tester,
  ) async {
    final launcher = _FakeLauncher(inAppResult: false);
    await tapSgpcPdf(tester, launcher);

    expect(launcher.launches.map((l) => (l.url, l.mode)), [
      (sgpcPdfPage, PreferredLaunchMode.inAppBrowserView),
      (sgpcPdfPage, PreferredLaunchMode.externalApplication),
    ]);
  });

  testWidgets('falls back to the browser when the in-app one throws', (
    tester,
  ) async {
    final launcher = _FakeLauncher(inAppError: Exception('no custom tabs'));
    await tapSgpcPdf(tester, launcher);

    expect(launcher.launches.map((l) => (l.url, l.mode)), [
      (sgpcPdfPage, PreferredLaunchMode.inAppBrowserView),
      (sgpcPdfPage, PreferredLaunchMode.externalApplication),
    ]);
    expect(tester.takeException(), isNull);
  });
}
