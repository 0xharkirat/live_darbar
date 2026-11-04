@Tags(['screens'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:live_darbar/src/controllers/connectivity_controller.dart';
import 'package:live_darbar/src/controllers/hukamnama_controller.dart';
import 'package:live_darbar/src/controllers/locale_controller.dart';
import 'package:live_darbar/src/controllers/now_playing_controller.dart';
import 'package:live_darbar/src/controllers/quality_mode_controller.dart';
import 'package:live_darbar/src/controllers/sikh_date_controller.dart';
import 'package:live_darbar/src/controllers/update_controller.dart';
import 'package:live_darbar/src/core/app_theme.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/clock.dart';
import 'package:live_darbar/src/core/app_version.dart';
import 'package:live_darbar/src/models/app_update.dart';
import 'package:live_darbar/src/models/audio_progress_state.dart';
import 'package:live_darbar/src/models/hukamnama.dart';
import 'package:live_darbar/src/models/live_playback_state.dart';
import 'package:live_darbar/src/models/quality_policy.dart';
import 'package:live_darbar/src/models/sikh_date.dart';
import 'package:live_darbar/src/models/stream_quality.dart';
import 'package:live_darbar/src/services/reminder_platform.dart';
import 'package:live_darbar/src/views/screens/about_screen.dart';
import 'package:live_darbar/src/views/screens/home_screen.dart';
import 'package:live_darbar/src/views/screens/hukamnama_screen.dart';
import 'package:live_darbar/src/views/screens/now_playing_screen.dart';
import 'package:live_darbar/src/views/widgets/quality_sheet.dart';
import 'package:live_darbar/src/views/widgets/reminder_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_reminder_platform.dart';

/// Renders every main screen to PNG, at iPhone 17 Pro size, with the real
/// fonts and paintings.
///
///     flutter test test/screens --tags screens
///
/// The images land in build/screens/. They are for looking at, in review and
/// for store screenshots; nothing is compared, so they never fail a build.
void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await _loadFonts();
  });

  for (final locale in ['en', 'pa']) {
    testWidgets('home, idle, $locale', (tester) async {
      await _pump(tester, const HomeScreen(), locale: locale);
      await _shot(tester, 'home_idle_$locale');
    });
  }

  testWidgets('home, live playing', (tester) async {
    await _pump(tester, const HomeScreen(), now: _livePlaying);
    await _shot(tester, 'home_live_playing_en');
  });

  testWidgets('home, scrolled to the end', (tester) async {
    await _pump(tester, const HomeScreen(), now: _hukamnamaPlaying);
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -900));
    await tester.pump(const Duration(seconds: 1));
    await _shot(tester, 'home_scrolled_en');
  });

  for (final (name, now) in [
    ('live', _livePlaying),
    ('hukamnama', _hukamnamaPlaying),
  ]) {
    testWidgets('now playing, $name', (tester) async {
      await _pump(tester, const HomeScreen(), now: now);
      showNowPlaying(tester.element(find.byType(HomeScreen)));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await _precache(tester);
      await _shot(tester, 'now_playing_${name}_en');
    });
  }

  testWidgets('now playing, live, data saver', (tester) async {
    await _pump(
      tester,
      const HomeScreen(),
      now: const NowPlaying(
        index: kLiveIndex,
        action: PlayAction.stop,
        started: true,
        live: LivePlaybackState(
          status: LiveStatus.playing,
          quality: StreamQuality.low,
        ),
      ),
      quality: QualityMode.dataSaver,
    );
    showNowPlaying(tester.element(find.byType(HomeScreen)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await _precache(tester);
    await _shot(tester, 'now_playing_live_datasaver_en');
  });

  // The darbar.live landing page shows this one in Punjabi.
  testWidgets('now playing, live, pa', (tester) async {
    await _pump(tester, const HomeScreen(), now: _livePlaying, locale: 'pa');
    showNowPlaying(tester.element(find.byType(HomeScreen)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await _precache(tester);
    await _shot(tester, 'now_playing_live_pa');
  });

  for (final locale in ['en', 'pa']) {
    testWidgets('hukamnama reader, $locale', (tester) async {
      await _pump(tester, const HukamnamaScreen(), locale: locale);
      await _shot(tester, 'hukamnama_$locale');
    });
  }

  for (final locale in ['en', 'pa']) {
    testWidgets('hukamnama meaning, $locale', (tester) async {
      await _pump(tester, const HukamnamaScreen(), locale: locale);
      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -3000),
      );
      await tester.pump(const Duration(seconds: 1));
      await _shot(tester, 'hukamnama_meaning_$locale');
    });
  }

  for (final locale in ['en', 'pa']) {
    testWidgets('quality sheet, $locale', (tester) async {
      await _pump(tester, const HomeScreen(), now: _livePlaying, locale: locale);
      showQualitySheet(tester.element(find.byType(HomeScreen)));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await _shot(tester, 'quality_$locale');
    });
  }

  for (final locale in ['en', 'pa']) {
    testWidgets('about, $locale', (tester) async {
      await _pump(tester, const AboutScreen(), locale: locale);
      await _shot(tester, 'about_$locale');
    });
  }

  // The daily reminder: the question, the setting when it is on, and the
  // sheet where the time is picked.
  for (final locale in ['en', 'pa']) {
    testWidgets('reminder prompt, $locale', (tester) async {
      await _pump(tester, const HomeScreen(), locale: locale);
      showReminderPrompt(tester.element(find.byType(HomeScreen)));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await _precache(tester);
      await _shot(tester, 'reminder_prompt_$locale');
    });

    testWidgets('about with the reminder on, $locale', (tester) async {
      _reminderOn();
      await _pump(tester, const AboutScreen(), locale: locale);
      await _shot(tester, 'about_reminder_on_$locale');
    });

    testWidgets('reminder time, $locale', (tester) async {
      _reminderOn();
      await _pump(tester, const AboutScreen(), locale: locale);
      await tester.tap(
        find.text(lookupAppLocalizations(Locale(locale)).reminder_time),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await _shot(tester, 'reminder_time_$locale');
    });
  }

  testWidgets('about with the reminder blocked, en', (tester) async {
    await _pump(
      tester,
      const AboutScreen(),
      reminders: FakeReminderPlatform(allowed: false),
    );
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.tap(find.text(l10n.reminder_setting));
    await tester.pump(const Duration(seconds: 1));
    await _shot(tester, 'about_reminder_blocked_en');
  });
}

/// The reminder as it is after the listener said yes at 7:00.
void _reminderOn() {
  SharedPreferences.setMockInitialValues({
    'reminder_asked': true,
    'reminder_enabled': true,
    'reminder_minutes': 7 * 60,
  });
  addTearDown(() => SharedPreferences.setMockInitialValues({}));
}

final _shotKey = GlobalKey();

/// Which screen to render for. Pick one with
/// `flutter test test/screens --dart-define=SHOT=play`.
///
/// - `iphone17pro` (default): for review, into build/screens/.
/// - `play`: Google Play phone screenshots, 9:16 at 1080 x 1920.
/// - `appstore`: the App Store's 6.9-inch iPhone size, 1290 x 2796.
/// - `ipad13`: the App Store's 13-inch iPad size, 2064 x 2752, at 2x. The
///   app runs on iPad, so the App Store asks for these too.
const _shotTarget = String.fromEnvironment('SHOT', defaultValue: 'iphone17pro');

const _targets = {
  'iphone17pro': (size: Size(1206, 2622), dpr: 3.0, top: 186.0, bottom: 102.0),
  'play': (size: Size(1080, 1920), dpr: 3.0, top: 72.0, bottom: 48.0),
  'appstore': (size: Size(1290, 2796), dpr: 3.0, top: 177.0, bottom: 102.0),
  'ipad13': (size: Size(2064, 2752), dpr: 2.0, top: 48.0, bottom: 40.0),
};

String get _shotDir => _shotTarget == 'iphone17pro'
    ? 'build/screens'
    : 'build/screens/$_shotTarget';

const _idle = NowPlaying(
  index: kLiveIndex,
  action: PlayAction.play,
  started: false,
  live: LivePlaybackState(),
);

const _livePlaying = NowPlaying(
  index: kLiveIndex,
  action: PlayAction.stop,
  started: true,
  live: LivePlaybackState(status: LiveStatus.playing),
);

const _hukamnamaPlaying = NowPlaying(
  index: kMukhwakIndex,
  action: PlayAction.pause,
  started: true,
  live: LivePlaybackState(status: LiveStatus.playing, isLiveSource: false),
);

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  String locale = 'en',
  NowPlaying now = _idle,
  QualityMode? quality,
  FakeReminderPlatform? reminders,
  List<Override> overrides = const [],
}) async {
  // The app shell does this in the real app; see AppType.tracking.
  AppType.tracking = locale != 'pa';
  final target = _targets[_shotTarget]!;
  tester.view.physicalSize = target.size;
  tester.view.devicePixelRatio = target.dpr;
  tester.view.padding = FakeViewPadding(top: target.top, bottom: target.bottom);
  addTearDown(tester.view.reset);

  final progress = AudioProgressState(
    position: const Duration(minutes: 3, seconds: 12),
    bufferedPosition: const Duration(minutes: 6),
    totalDuration: now.isLive ? null : const Duration(minutes: 9, seconds: 40),
    isLive: now.isLive,
  );

  await tester.pumpWidget(
    RepaintBoundary(
      key: _shotKey,
      child: ProviderScope(
        // Riverpod retries a provider whose build throws and shows it as
        // loading meanwhile; a screenshot of an error needs the error.
        retry: (_, __) => null,
        overrides: [
          nowPlayingProvider.overrideWithValue(now),
          livePlaybackProvider.overrideWith((ref) => Stream.value(now.live!)),
          audioProgressProvider.overrideWith((ref) => Stream.value(progress)),
          connectivityController.overrideWith(_Online.new),
          updateController.overrideWith(_NoUpdate.new),
          localeController.overrideWith(() => _Locale(locale)),
          appVersionProvider.overrideWith((ref) async => '3.0.0 (10)'),
          // The renders show the reminder, which a phone offers.
          reminderPlatformProvider
              .overrideWithValue(reminders ?? FakeReminderPlatform()),
          // The renders show 2 November in Amritsar, whatever day they run on.
          clockProvider.overrideWithValue(() => DateTime.utc(2026, 11, 2, 6)),
          sikhDateProvider.overrideWith(
            (ref) async => SikhDate(
              day: 17,
              monthIndex: 7,
              year: 558,
              gregorian: DateTime.utc(2026, 11, 2),
            ),
          ),
          hukamnamaProvider.overrideWith(_Fixture.new),
          sangrandTableProvider.overrideWith(
            (ref) async => SangrandTable.fromJsonString(
              File('assets/data/sgpc_sangrands.json').readAsStringSync(),
            ),
          ),
          if (quality != null)
            qualityModeProvider.overrideWith(() => _Quality(quality)),
          ...overrides,
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.material,
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      ),
    ),
  );
  await tester.pump();
  await _precache(tester);
}

/// Decodes every image on screen for real. Widget tests run in fake time, so
/// image decoding has to be let out into real async to finish.
Future<void> _precache(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final image = element.widget as Image;
      await precacheImage(image.image, element);
    }
  });
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _shot(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_shotKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _targets[_shotTarget]!.dpr);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_shotDir/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Future<void> _loadFonts() async {
  Future<void> family(String name, List<String> assets) async {
    final loader = FontLoader(name);
    for (final asset in assets) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }

  await family('Geist', [
    'assets/fonts/Geist-400.ttf',
    'assets/fonts/Geist-500.ttf',
    'assets/fonts/Geist-700.ttf',
  ]);
  await family('NotoSansGurmukhi', [
    'assets/fonts/NotoSansGurmukhi-400.ttf',
    'assets/fonts/NotoSansGurmukhi-500.ttf',
    'assets/fonts/NotoSansGurmukhi-700.ttf',
  ]);
  await family('GeistSerif', ['assets/fonts/GeistSerif-400.ttf']);
  await family('TiroGurmukhi', ['assets/fonts/TiroGurmukhi-400.ttf']);
  await family('packages/cupertino_icons/CupertinoIcons', [
    'packages/cupertino_icons/assets/CupertinoIcons.ttf',
  ]);
}

/// The real Hukamnama for 2 November 2026, as SGPC's feed served it.
class _Fixture extends HukamnamaController {
  @override
  Future<Hukamnama> build() async {
    final json =
        File('test/fixtures/sgpc_hukamnama_2026_11_02.json').readAsStringSync();
    return Hukamnama.fromSgpc(jsonDecode(json) as Map<String, dynamic>);
  }
}

class _Quality extends QualityModeController {
  _Quality(this.mode);

  final QualityMode mode;

  @override
  QualityMode build() {
    ready = Future.value();
    return mode;
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
