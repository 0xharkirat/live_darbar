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
import 'package:live_darbar/src/controllers/maintenance_controller.dart';
import 'package:live_darbar/src/controllers/locale_controller.dart';
import 'package:live_darbar/src/controllers/now_playing_controller.dart';
import 'package:live_darbar/src/controllers/sgpc_events_controller.dart';
import 'package:live_darbar/src/controllers/sikh_date_controller.dart';
import 'package:live_darbar/src/controllers/update_controller.dart';
import 'package:live_darbar/src/controllers/whats_new_controller.dart';
import 'package:live_darbar/src/controllers/widget_card_controller.dart';
import 'package:live_darbar/src/core/amritsar_time.dart';
import 'package:live_darbar/src/core/app_theme.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/app_version.dart';
import 'package:live_darbar/src/core/clock.dart';
import 'package:live_darbar/src/core/platform.dart';
import 'package:live_darbar/src/home_screen_widget/widget_install.dart';
import 'package:live_darbar/src/models/app_update.dart';
import 'package:live_darbar/src/models/audio_progress_state.dart';
import 'package:live_darbar/src/models/hukamnama.dart';
import 'package:live_darbar/src/models/live_playback_state.dart';
import 'package:live_darbar/src/models/maintenance.dart';
import 'package:live_darbar/src/models/sgpc_event.dart';
import 'package:live_darbar/src/models/sikh_date.dart';
import 'package:live_darbar/src/models/whats_new.dart';
import 'package:live_darbar/src/services/reminder_platform.dart';
import 'package:live_darbar/src/services/screen_awake.dart';
import 'package:live_darbar/src/views/app_builder.dart';
import 'package:live_darbar/src/views/app_scroll_behavior.dart';
import 'package:live_darbar/src/views/browser_title.dart';
import 'package:live_darbar/src/views/app_router.dart';
import 'package:live_darbar/src/views/screens/home_screen.dart';
import 'package:live_darbar/src/views/widgets/demo_film.dart';
import 'package:live_darbar/src/views/widgets/reminder_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_film_player.dart';
import 'fake_reminder_platform.dart';
import 'fake_screen_awake.dart';
import 'fake_widget_install.dart';

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

  /// Home asks for a fresh text each time the app comes back to the front.
  /// Here the fixture is the text, and nothing goes to SGPC.
  @override
  Future<void> refresh() async {}
}

class _Online extends ConnectivityController {
  @override
  Stream<bool> build() => Stream.value(true);
}

class NoUpdate extends UpdateController {
  @override
  Future<AppUpdate?> build() async => null;
}

/// Offers [offered] at launch, the way a newer release.json does.
class OfferUpdate extends UpdateController {
  OfferUpdate(this.offered);

  final AppUpdate offered;

  @override
  Future<AppUpdate?> build() async => offered;
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
/// [update] is a newer release, for the update sheet to offer at launch.
/// [clock] fixes the moment; the app otherwise reads the real one. [sikh] is
/// the Sikh date on home, and [events] is the calendar of Sikh history, which
/// is empty unless a test gives one.
/// [widgetInstall] is the phone behind the "add the widget" card. By default
/// the platform has no home screen widgets, so home and About show what they
/// showed before the card existed. [films] stands in for the video player
/// behind the film in the steps sheet. [prefs] are the saved settings at
/// launch.
/// The card decides at once, unless [cardSettle] makes it wait, as the app does
/// so that the sheets of a launch come first.
/// [reminders] is the phone behind the daily reminder. By default it cannot
/// remind, so About shows what it showed before the reminder existed, and the
/// reader asks nothing. The reader's question comes at once, with no wait for
/// the page to settle, unless [reminderSettle] says otherwise. [localOffset]
/// stands in for the listener's time zone, which is the phone's by default.
/// [screenAwake] is the phone's screen timeout, which a page can hold off.
/// [maintenance] is the message in release.json, for the banner. By default
/// there is none, and nothing asks the network.
/// [whatsNew] is the notes of each release, by release such as `2.2`. By
/// default no release has notes, so Home shows what it showed before the
/// notes existed. [whatsNewSettle] is how long Home must be calm before they
/// open: none, unless a test says otherwise.
Future<void> pumpApp(
  WidgetTester tester, {
  String locale = 'en',
  Size size = phone,
  bool web = false,
  String initialRoute = AppRoutes.home,
  NowPlaying now = idle,
  AppUpdate? update,
  DateTime? clock,
  SikhDate? sikh,
  SgpcEventTable? events,
  FakeWidgetInstall? widgetInstall,
  FakeFilmPlayers? films,
  Map<String, Object> prefs = const {},
  Duration cardSettle = Duration.zero,
  FakeReminderPlatform? reminders,
  Duration reminderSettle = Duration.zero,
  LocalOffset? localOffset,
  FakeScreenAwake? screenAwake,
  Map<String, WhatsNew> whatsNew = const {},
  Duration whatsNewSettle = Duration.zero,
  Maintenance? maintenance,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  AppType.tracking = locale != 'pa';
  addTearDown(() => AppType.tracking = true);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = size == phone ? 3 : 1;
  addTearDown(tester.view.reset);

  final allOverrides = <Override>[
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
    updateController.overrideWith(
      update == null ? NoUpdate.new : () => OfferUpdate(update),
    ),
    localeController.overrideWith(() => _Locale(locale)),
    sangrandTableProvider.overrideWith((ref) async => null),
    sgpcEventsProvider.overrideWith((ref) async => events ?? SgpcEventTable.empty),
    sikhDateProvider.overrideWith((ref) async => sikh),
    if (clock != null) clockProvider.overrideWithValue(() => clock),
    hukamnamaProvider.overrideWith(FixtureHukamnama.new),
    appVersionProvider.overrideWith((ref) async => '2.2.1 (9)'),
    isWebProvider.overrideWithValue(web),
    // The daily reminder has its own tests. Here the platform cannot remind,
    // so About shows what it showed before the reminder existed.
    reminderPlatformProvider
        .overrideWithValue(reminders ?? FakeReminderPlatform(supported: false)),
    reminderSettleProvider.overrideWithValue(reminderSettle),
    if (localOffset != null) localOffsetProvider.overrideWithValue(localOffset),
    widgetInstallProvider.overrideWithValue(
      widgetInstall ?? FakeWidgetInstall(supported: false),
    ),
    widgetCardSettleProvider.overrideWithValue(cardSettle),
    // The phone's screen timeout. By default nothing is asked of a phone.
    screenAwakeProvider.overrideWithValue(
      ScreenAwake((screenAwake ?? FakeScreenAwake()).toggle),
    ),
    filmPlayerFactoryProvider.overrideWithValue((films ?? FakeFilmPlayers()).call),
    whatsNewLoaderProvider.overrideWithValue((release) async => whatsNew[release]),
    whatsNewSettleProvider.overrideWithValue(whatsNewSettle),
    maintenanceProvider.overrideWith((ref) async => maintenance),
  ];

  await tester.pumpWidget(
    ProviderScope(
      retry: (_, __) => null,
      overrides: allOverrides,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: AppTheme.material,
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // The limit, the banners and the tab title, as main.dart has them.
          builder: appBuilder,
          navigatorObservers: [ref.watch(pageNamesProvider)],
          scrollBehavior: AppScrollBehavior(web: web),
          initialRoute: initialRoute,
          home: const HomeScreen(),
          onGenerateRoute: AppRoutes.generator(web: web),
        ),
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
