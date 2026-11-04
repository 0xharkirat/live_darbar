@Tags(['screens'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import 'package:live_darbar/src/controllers/sgpc_events_controller.dart';
import 'package:live_darbar/src/controllers/sikh_date_controller.dart';
import 'package:live_darbar/src/controllers/update_controller.dart';
import 'package:live_darbar/src/controllers/widget_card_controller.dart';
import 'package:live_darbar/src/core/amritsar_time.dart';
import 'package:live_darbar/src/core/widget_card_rules.dart';
import 'package:live_darbar/src/home_screen_widget/widget_install.dart';
import 'package:live_darbar/src/core/app_theme.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/clock.dart';
import 'package:live_darbar/src/core/app_version.dart';
import 'package:live_darbar/src/models/app_update.dart';
import 'package:live_darbar/src/models/audio_progress_state.dart';
import 'package:live_darbar/src/models/hukamnama.dart';
import 'package:live_darbar/src/models/live_playback_state.dart';
import 'package:live_darbar/src/models/quality_policy.dart';
import 'package:live_darbar/src/models/sgpc_day.dart';
import 'package:live_darbar/src/models/sgpc_event.dart';
import 'package:live_darbar/src/models/sikh_date.dart';
import 'package:live_darbar/src/models/stream_quality.dart';
import 'package:live_darbar/src/services/reminder_platform.dart';
import 'package:live_darbar/src/services/screen_awake.dart';
import 'package:live_darbar/src/views/launch_failure_app.dart';
import 'package:live_darbar/src/views/screens/about_screen.dart';
import 'package:live_darbar/src/views/screens/history_screen.dart';
import 'package:live_darbar/src/views/screens/home_screen.dart';
import 'package:live_darbar/src/views/screens/hukamnama_screen.dart';
import 'package:live_darbar/src/views/screens/now_playing_screen.dart';
import 'package:live_darbar/src/views/widgets/quality_sheet.dart';
import 'package:live_darbar/src/views/widgets/reminder_sheet.dart';
import 'package:live_darbar/src/views/widgets/demo_film.dart';
import 'package:live_darbar/src/views/widgets/widget_steps_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_reminder_platform.dart';
import '../support/fake_film_player.dart';
import '../support/fake_widget_install.dart';
import '../support/load_fonts.dart';

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
    await loadAppFonts();
  });

  for (final locale in ['en', 'pa']) {
    testWidgets('home, idle, $locale', (tester) async {
      await _pump(tester, const HomeScreen(), locale: locale);
      await _shot(tester, 'home_idle_$locale');
    });
  }

  // Today in Sikh history: 3 November 2026 has 3 events, the most of any day.
  for (final locale in ['en', 'pa']) {
    testWidgets('home, 3 November with 3 events, $locale', (tester) async {
      await _pump(
        tester,
        const HomeScreen(),
        locale: locale,
        at: DateTime.utc(2026, 11, 3, 6),
      );
      await _shot(tester, 'home_history_$locale');
    });
  }

  // The whole Nanakshahi year of Sikh history, opened on today. The first
  // render is 3 November, a day with 3 events. The second is a day with none,
  // so it opens on the next day to come.
  for (final locale in ['en', 'pa']) {
    testWidgets('history, 3 November, $locale', (tester) async {
      await _pump(
        tester,
        const HistoryScreen(),
        locale: locale,
        at: DateTime.utc(2026, 11, 3, 6),
      );
      await tester.pump(const Duration(seconds: 1));
      await _shot(tester, 'history_$locale');
    });
  }

  testWidgets('history, with the notification on, en', (tester) async {
    SharedPreferences.setMockInitialValues({'history_enabled': true});
    addTearDown(() => SharedPreferences.setMockInitialValues({}));
    await _pump(
      tester,
      const HistoryScreen(),
      at: DateTime.utc(2026, 11, 3, 6),
    );
    await tester.pump(const Duration(seconds: 1));
    await _shot(tester, 'history_notification_on_en');
  });

  // Today in Sikh history on a quiet day: 4 November has no event, so the line
  // shows the next one, 8 November. It is the same row as on 3 November.
  for (final locale in ['en', 'pa']) {
    testWidgets('home, 4 November, next event, $locale', (tester) async {
      await _pump(
        tester,
        const HomeScreen(),
        locale: locale,
        at: DateTime.utc(2026, 11, 4, 6),
      );
      await _shot(tester, 'home_history_next_$locale');
    });
  }

  // With the real fonts, the line is 1 row of the same height on every kind of
  // day, so live kirtan below it never moves. This includes the longest titles,
  // which the line cuts after 2 lines.
  testWidgets('home, the history line is the same height on every day', (
    tester,
  ) async {
    final table = SgpcEventTable.fromJsonString(
      File('assets/data/sgpc_events_558.json').readAsStringSync(),
    );
    final longest = [...table.events]
      ..sort((a, b) => b.titleEn!.length.compareTo(a.titleEn!.length));
    final days = <DateTime>{
      for (final e in longest.take(6)) e.first,
      DateTime.utc(2026, 11, 3),
      DateTime.utc(2026, 11, 4),
      DateTime.utc(2027, 2, 21),
    };
    for (final locale in ['en', 'pa']) {
      final tops = <String, double>{};
      for (final day in days) {
        await _pump(
          tester,
          const HomeScreen(),
          locale: locale,
          at: DateTime.utc(day.year, day.month, day.day, 6),
        );
        tops[day.toIso8601String()] =
            tester.getTopLeft(find.text(locale == 'pa' ? 'ਲਾਈਵ ਦਰਬਾਰ' : 'Live Darbar')).dy;
      }
      expect(tops.values.toSet(), hasLength(1), reason: '$locale: $tops');
    }
  });

  testWidgets('home, live playing', (tester) async {
    await _pump(tester, const HomeScreen(), now: _livePlaying);
    await _shot(tester, 'home_live_playing_en');
  });

  // The loading ring, after its delay: on the live hero, the 2 tiles' buttons
  // and the mini player (live is the source that is opening).
  testWidgets('home, live kirtan is opening', (tester) async {
    await _pump(tester, const HomeScreen(), now: _liveOpening);
    await tester.pump(const Duration(seconds: 1));
    await _shot(tester, 'home_live_opening_en');
  });

  // The largest text size the app lays out for (2x), with the player up.
  testWidgets('home, text at 2x', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pump(tester, const HomeScreen(), now: _livePlaying);
    await _shot(tester, 'home_text_2x_en');
  });

  testWidgets('about, text at 2x', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pump(tester, const AboutScreen());
    await _shot(tester, 'about_text_2x_en');
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

  // The reader asks about the reminder the first time it opens, and the bell
  // opens the same sheet after that.
  for (final locale in ['en', 'pa']) {
    testWidgets('hukamnama first-open question, $locale', (tester) async {
      await _pump(
        tester,
        const HukamnamaScreen(),
        locale: locale,
        reminderSettle: Duration.zero,
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await _precache(tester);
      await _shot(tester, 'hukamnama_question_$locale');
    });

    testWidgets('hukamnama, reminder on, bell sheet, $locale', (tester) async {
      _reminderOn();
      await _pump(tester, const HukamnamaScreen(), locale: locale);
      await tester.tap(find.byIcon(CupertinoIcons.bell_fill));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await _shot(tester, 'hukamnama_bell_sheet_$locale');
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

  // "Today in Sikh history" in About, off and on.
  for (final locale in ['en', 'pa']) {
    testWidgets('about with the history switch off, $locale', (tester) async {
      await _pump(tester, const AboutScreen(), locale: locale);
      await _shot(tester, 'about_history_off_$locale');
    });

    testWidgets('about with the history switch on, $locale', (tester) async {
      SharedPreferences.setMockInitialValues({'history_enabled': true});
      addTearDown(() => SharedPreferences.setMockInitialValues({}));
      await _pump(tester, const AboutScreen(), locale: locale);
      await _shot(tester, 'about_history_on_$locale');
    });
  }

  // The "add the widget" card, for a listener who played the Hukamnama on an
  // earlier visit, and the steps for an iPhone, where no call can add it.
  for (final locale in ['en', 'pa']) {
    testWidgets('home with the widget card, $locale', (tester) async {
      _widgetCardDue();
      await _pump(tester, const HomeScreen(), locale: locale);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -900),
      );
      await tester.pump(const Duration(seconds: 1));
      // The card's picture arrives after the first frames.
      await _precache(tester);
      await _shot(tester, 'home_widget_card_$locale');
    });

    testWidgets('widget steps, iPhone, $locale', (tester) async {
      await _pump(
        tester,
        const HomeScreen(),
        locale: locale,
        widgetInstall: FakeWidgetInstall(iphone: true),
      );
      showWidgetStepsSheet(tester.element(find.byType(HomeScreen)));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await _precache(tester);
      await _shot(tester, 'widget_steps_iphone_$locale');
    });

    // The film at the moment of a tap, to look at the dot and its ring over
    // the poster. The film itself is not drawn in a test.
    testWidgets('widget steps, iPhone, a tap on the film, $locale', (
      tester,
    ) async {
      final films = FakeFilmPlayers();
      await _pump(
        tester,
        const HomeScreen(),
        locale: locale,
        widgetInstall: FakeWidgetInstall(iphone: true),
        films: films,
      );
      showWidgetStepsSheet(tester.element(find.byType(HomeScreen)));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      films.last!.playAt(DemoFilm.iphone.marks[3].t + 0.12);
      await tester.pump(const Duration(milliseconds: 100));
      await _precache(tester);
      await _shot(tester, 'widget_steps_iphone_tap_$locale');
    });

    testWidgets('widget steps, Android, $locale', (tester) async {
      await _pump(tester, const HomeScreen(), locale: locale);
      showWidgetStepsSheet(tester.element(find.byType(HomeScreen)));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await _precache(tester);
      await _shot(tester, 'widget_steps_android_$locale');
    });

    // The permanent row in About, before and after the widget is added.
    testWidgets('about with the widget row, $locale', (tester) async {
      await _pump(tester, const AboutScreen(), locale: locale);
      await tester.pump(const Duration(milliseconds: 300));
      await _shot(tester, 'about_widget_row_$locale');
    });

    testWidgets('about with the widget added, $locale', (tester) async {
      await _pump(
        tester,
        const AboutScreen(),
        locale: locale,
        widgetInstall: FakeWidgetInstall(placementNow: WidgetPlacement.added),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await _shot(tester, 'about_widget_added_$locale');
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

  // The screen that replaces the app when start-up fails.
  testWidgets('launch failure', (tester) async {
    await _pump(tester, const LaunchFailureApp(onRetry: _noop));
    await _shot(tester, 'launch_failure');
  });
}

void _noop() {}

/// A listener who played the Hukamnama recording on an earlier visit, so the
/// card is due.
void _widgetCardDue() {
  SharedPreferences.setMockInitialValues({WidgetCardController.playedKey: true});
  addTearDown(() => SharedPreferences.setMockInitialValues({}));
}

/// The reminder as it is after the listener said yes, at the default: 7:00 in
/// Amritsar.
void _reminderOn() {
  SharedPreferences.setMockInitialValues({
    'reminder_asked': true,
    'reminder_enabled': true,
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

const _liveOpening = NowPlaying(
  index: kLiveIndex,
  action: PlayAction.working,
  started: true,
  live: LivePlaybackState(status: LiveStatus.connecting),
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
  FakeWidgetInstall? widgetInstall,
  DateTime? at,
  FakeFilmPlayers? films,
  Duration reminderSettle = const Duration(hours: 1),
  List<Override> overrides = const [],
}) async {
  // The renders show 2 November in Amritsar, whatever day they run on, unless
  // a render asks for another moment.
  final moment = at ?? DateTime.utc(2026, 11, 2, 6);
  final sgpcDay = sgpcDayOf(moment);
  final sikhDay = 17 + sgpcDay.difference(DateTime.utc(2026, 11, 2)).inDays;
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
          // The renders show the widget card and its row, which a phone offers.
          widgetInstallProvider
              .overrideWithValue(widgetInstall ?? FakeWidgetInstall()),
          widgetCardSettleProvider.overrideWithValue(Duration.zero),
          // A render holds no screen timeout.
          screenAwakeProvider.overrideWithValue(ScreenAwake((_) async {})),
          // The film in the steps sheet shows its poster: no film plays.
          filmPlayerFactoryProvider
              .overrideWithValue((films ?? FakeFilmPlayers()).call),
          // A render of the reader is not the first open, unless it says so.
          reminderSettleProvider.overrideWithValue(reminderSettle),
          // The renders show a listener in Sydney in summer: 12:30 for 7:00 in
          // Amritsar.
          localOffsetProvider.overrideWithValue(
            (_) => const Duration(hours: 11),
          ),
          clockProvider.overrideWithValue(() => moment),
          sikhDateProvider.overrideWith(
            (ref) async => SikhDate(
              day: sikhDay,
              monthIndex: 7,
              year: 558,
              gregorian: sgpcDay,
            ),
          ),
          sgpcEventsProvider.overrideWith(
            (ref) async => SgpcEventTable.fromJsonString(
              File('assets/data/sgpc_events_558.json').readAsStringSync(),
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
///
/// An animated image (the add-widget clip) finishes its first frame only when
/// the app draws a frame, and no frame comes inside this wait, so waiting for
/// it here would never end. It gets a real moment to decode instead, and the
/// frames that follow show its first picture.
Future<void> _precache(WidgetTester tester) async {
  var animated = false;
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final provider = (element.widget as Image).image;
      if (provider is AssetImage && provider.assetName.endsWith('.webp')) {
        // Starts the decode and does not wait for it.
        unawaited(precacheImage(provider, element));
        animated = true;
        continue;
      }
      await precacheImage(provider, element);
    }
    if (animated) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }
  });
  await tester.pump(const Duration(milliseconds: 600));
  if (animated) await tester.pump(const Duration(milliseconds: 600));
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

/// The real Hukamnama for 2 November 2026, as SGPC's feed served it.
class _Fixture extends HukamnamaController {
  @override
  Future<Hukamnama> build() async {
    final json =
        File('test/fixtures/sgpc_hukamnama_2026_11_02.json').readAsStringSync();
    return Hukamnama.fromSgpc(jsonDecode(json) as Map<String, dynamic>);
  }

  /// Nothing goes to SGPC when the app comes back to the front.
  @override
  Future<void> refresh() async {}
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
