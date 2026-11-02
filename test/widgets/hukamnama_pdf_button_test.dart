import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:live_darbar/src/controllers/hukamnama_controller.dart';
import 'package:live_darbar/src/controllers/now_playing_controller.dart';
import 'package:live_darbar/src/controllers/sikh_date_controller.dart';
import 'package:live_darbar/src/core/app_theme.dart';
import 'package:live_darbar/src/core/motion.dart';
import 'package:live_darbar/src/models/hukamnama.dart';
import 'package:live_darbar/src/models/live_playback_state.dart';
import 'package:live_darbar/src/views/screens/hukamnama_screen.dart';
import 'package:live_darbar/src/views/widgets/busy_icon.dart';
import 'package:live_darbar/src/views/widgets/pressable.dart';
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

/// A feed that never arrives, so the screen shows its failure state.
class _Failing extends HukamnamaController {
  @override
  Future<Hukamnama> build() async => throw Exception('offline');
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

  Future<void> pumpScreen(
    WidgetTester tester,
    _FakeLauncher launcher, {
    HukamnamaController Function() feed = _Fixture.new,
  }) async {
    UrlLauncherPlatform.instance = launcher;
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hukamnamaProvider.overrideWith(feed),
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
  }

  Future<void> tapSgpcPdf(WidgetTester tester, _FakeLauncher launcher) async {
    await pumpScreen(tester, launcher);
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

  /// Long enough for the 120 ms icon swap to finish and the old icon to go.
  const swapped = Duration(milliseconds: 160);

  group('while the browser opens', () {
    final spinner = find.byType(CupertinoActivityIndicator);
    final pill = find.ancestor(
      of: find.text('SGPC PDF'),
      matching: find.byType(Pressable),
    );

    testWidgets('the icon becomes a spinner on the first frame of the tap', (
      tester,
    ) async {
      final launcher = _FakeLauncher();
      await pumpScreen(tester, launcher);
      expect(spinner, findsNothing);
      expect(find.byIcon(CupertinoIcons.doc_text), findsOneWidget);

      await tester.tap(find.text('SGPC PDF'));
      await tester.pump();
      await tester.pump(Motion.press);
      expect(spinner, findsOneWidget, reason: 'there within 120 ms');

      await tester.pump(swapped);
      expect(find.byIcon(CupertinoIcons.doc_text), findsNothing);
    });

    testWidgets('a second tap does not open a second tab', (tester) async {
      final launcher = _FakeLauncher();
      await tapSgpcPdf(tester, launcher);

      await tester.tap(find.text('SGPC PDF'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('SGPC PDF'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(launcher.launches, hasLength(1));
    });

    testWidgets('the screen reader hears it is off, and hears the label once', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final launcher = _FakeLauncher();
      await pumpScreen(tester, launcher);
      expect(
        tester.getSemantics(pill),
        matchesSemantics(
          label: 'SGPC PDF',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      await tester.tap(find.text('SGPC PDF'));
      await tester.pump();

      expect(
        tester.getSemantics(pill),
        matchesSemantics(
          label: 'SGPC PDF',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      handle.dispose();
    });

    testWidgets('lets go after 1.5 seconds, and opens again', (tester) async {
      final launcher = _FakeLauncher();
      await tapSgpcPdf(tester, launcher);

      await tester.pump(const Duration(milliseconds: 1400));
      expect(spinner, findsOneWidget, reason: 'not yet');

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(swapped);
      expect(spinner, findsNothing);
      expect(find.byIcon(CupertinoIcons.doc_text), findsOneWidget);

      await tester.tap(find.text('SGPC PDF'));
      await tester.pump();
      expect(launcher.launches, hasLength(2));
    });

    testWidgets('lets go as soon as the browser covers the app', (
      tester,
    ) async {
      final launcher = _FakeLauncher();
      await tapSgpcPdf(tester, launcher);

      // The browser covers the app: inactive, then hidden, then paused. No
      // frames run while it does, so the reader comes back before the next one.
      void go(List<AppLifecycleState> states) {
        for (final state in states) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
      }

      go([AppLifecycleState.inactive]);
      await tester.pump(swapped);
      expect(spinner, findsOneWidget, reason: 'inactive alone is not enough');

      go([
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);
      await tester.pump();
      await tester.pump(swapped);
      await tester.pump();

      expect(spinner, findsNothing);
      expect(find.byIcon(CupertinoIcons.doc_text), findsOneWidget);
    });

    testWidgets('swaps with scale and blur, and Reduce Motion with a fade', (
      tester,
    ) async {
      final inIcon = find.descendant(
        of: find.byType(BusyIcon),
        matching: find.byType(ScaleTransition),
      );
      final blur = find.descendant(
        of: find.byType(BusyIcon),
        matching: find.byType(ImageFiltered),
      );
      await tapSgpcPdf(tester, _FakeLauncher());
      await tester.pump(const Duration(milliseconds: 40));
      expect(inIcon, findsWidgets);
      expect(blur, findsWidgets);
    });

    testWidgets('Reduce Motion cross-fades and does not scale or blur', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tapSgpcPdf(tester, _FakeLauncher());
      await tester.pump(const Duration(milliseconds: 1));

      expect(spinner, findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(BusyIcon),
          matching: find.byType(FadeTransition),
        ),
        findsWidgets,
      );
      expect(
        find.descendant(
          of: find.byType(BusyIcon),
          matching: find.byType(ScaleTransition),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(BusyIcon),
          matching: find.byType(ImageFiltered),
        ),
        findsNothing,
      );
    });

    testWidgets('the pill says it leaves the app, with an arrow', (
      tester,
    ) async {
      await pumpScreen(tester, _FakeLauncher());

      expect(
        find.descendant(
          of: pill,
          matching: find.byIcon(CupertinoIcons.arrow_up_right),
        ),
        findsOneWidget,
      );
    });
  });

  group('when the text fails to load', () {
    final spinner = find.byType(CupertinoActivityIndicator);
    final link = find.ancestor(
      of: find.text('SGPC PDF'),
      matching: find.byType(Pressable),
    );

    testWidgets(
        'the PDF link is a Pressable with an arrow, not a '
        'CupertinoButton', (tester) async {
      await pumpScreen(tester, _FakeLauncher(), feed: _Failing.new);

      expect(link, findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('SGPC PDF'),
          matching: find.byType(CupertinoButton),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: link,
          matching: find.byIcon(CupertinoIcons.arrow_up_right),
        ),
        findsOneWidget,
      );
    });

    testWidgets('it opens the PDF page once, with the arrow as a spinner', (
      tester,
    ) async {
      final launcher = _FakeLauncher();
      await pumpScreen(tester, launcher, feed: _Failing.new);

      await tester.tap(find.text('SGPC PDF'));
      await tester.pump();
      await tester.pump(swapped);
      expect(spinner, findsOneWidget);
      expect(
        find.descendant(
          of: link,
          matching: find.byIcon(CupertinoIcons.arrow_up_right),
        ),
        findsNothing,
      );

      await tester.tap(find.text('SGPC PDF'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(launcher.launches, hasLength(1));
      expect(launcher.launches.single.url, sgpcPdfPage);
    });
  });
}
