import 'dart:async';
import 'dart:developer';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intelligence/intelligence.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:live_darbar/src/controllers/locale_controller.dart';
import 'package:live_darbar/src/controllers/reminder_controller.dart';
import 'package:live_darbar/src/controllers/sikh_history_controller.dart';
import 'package:live_darbar/src/home_screen_widget/widget_actions.dart';
import 'package:live_darbar/src/home_screen_widget/widget_background.dart';
import 'package:live_darbar/src/home_screen_widget/widget_links.dart';
import 'package:live_darbar/src/home_screen_widget/widget_playback.dart';
import 'package:live_darbar/src/home_screen_widget/widget_publisher.dart';
import 'package:live_darbar/src/home_screen_widget/widget_remote.dart';
import 'package:live_darbar/src/home_screen_widget/widget_sync.dart';
import 'package:live_darbar/src/media_session/live_darbar_audio_handler.dart';
import 'package:live_darbar/src/bootstrap.dart';
import 'package:live_darbar/src/core/app_theme.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/open_link.dart';
import 'package:live_darbar/src/models/sgpc_day.dart';
import 'package:live_darbar/src/services/legacy_pdf_cleanup.dart';
import 'package:live_darbar/src/services/reminder_launch.dart';
import 'package:live_darbar/src/views/app_builder.dart';
import 'package:live_darbar/src/views/app_scroll_behavior.dart';
import 'package:live_darbar/src/views/browser_title.dart';
import 'package:live_darbar/src/views/app_router.dart';
import 'package:live_darbar/src/views/screens/home_screen.dart';
import 'package:live_darbar/src/views/widgets/artwork.dart';
import 'package:live_darbar/src/views/widgets/error_view.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:live_darbar/l10n/app_localizations.dart';

/// Where the home screen widget's background refresh starts, with the app
/// closed. `WidgetRefresh.kt` starts it by this name in an engine of its own.
///
/// It lives in this file so that it is part of the program. The compiler keeps
/// only what `main` can reach, and no screen reaches the refresh. The work
/// itself is in `widget_background.dart`.
@pragma('vm:entry-point')
Future<void> widgetRefreshEntry(List<String> args) => widgetRefreshMain(args);

/// The media session, once it has started. Null on the web, and when it
/// could not start. The iPhone widget's taps read what it plays.
LiveDarbarAudioHandler? _mediaSession;

/// Starts the app. If start-up fails, the listener sees a calm screen with a
/// Retry, not a blank one. See [bootstrap]. A widget that breaks later shows
/// a small, calm box in its place in a release build. See [installErrorView].
Future<void> main() {
  // Before [bootstrap], which watches this builder during the first frame.
  installErrorView();
  return bootstrap<ProviderContainer>(
    prepare: _prepare,
    build: (container) =>
        UncontrolledProviderScope(container: container, child: const MyApp()),
  );
}

/// Everything that runs before the first frame, in the order it always has.
Future<ProviderContainer> _prepare() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Lock the UI to portrait up orientation.
  //
  // Not awaited. A service can start this engine with no activity, for a tap
  // on the home screen widget, the notification or a car. Then nothing on the
  // Android side answers this call, and an await would wait for ever, and
  // with it the media session below. The activity locks portrait itself
  // (`screenOrientation` in AndroidManifest.xml), so nothing is lost.
  unawaited(
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
  );
  final container = ProviderContainer();
  try {
    await _startServices(container);
  } catch (_) {
    // A retry makes a new container, so this one goes now.
    container.dispose();
    rethrow;
  }
  // Last, so the order above is as it was. The native splash is still up, and
  // Home's 3 paintings are decoded before its first frame.
  await preloadArtwork();
  return container;
}

/// The audio session, the widget store and the media session. A failure in the
/// audio session or the media session is not fatal: the app plays without
/// them. Anything else that throws fails the start-up.
Future<void> _startServices(ProviderContainer container) async {
  if (!kIsWeb && !kIsWasm) {
    // Say what kind of audio this is, before any player exists.
    //
    // `just_audio` applies a music profile when nothing has been configured,
    // so this changes no behaviour today. It makes the choice explicit rather
    // than inherited: playback category on iOS, and media usage with music
    // content on Android, which is what routes the sound to a Bluetooth
    // headset or a car stereo and lets the system pause it for a call. Native
    // apps only. The session plugin has nothing to configure on web.
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (e) {
      // Not worth stopping the app for. The player falls back to its default.
      debugPrint('Audio session not configured: $e');
    }

    // On iPhone the widget reads the App Group's store. Point home_widget
    // at it before anything writes there. It is fast, and it never throws.
    await HomeWidgetPublisher.prepare();

    // Connect the media session: the notification, the lock screen, headset
    // buttons, Android Auto and voice assistants.
    //
    // Before the first frame, and with a container made here rather than by
    // the widget tree. A car or an assistant can start the app with no screen
    // at all, and a command from it finds a handler on a controller that is
    // already there. A provider that waited for a widget to read it would
    // wait for ever.
    try {
      final handler =
          await LiveDarbarAudioHandler.init(container.read(audioController));
      _mediaSession = handler;
      // Tell the home screen widget what the session does, from here, so that
      // it follows the app, the notification, a headset, the car and the
      // widget itself. The widget's own taps can wake the app with no screen,
      // and this runs without one.
      if (HomeWidgetPublisher.isSupported) {
        WidgetPlaybackSync(
          playbackState: handler.playbackState,
          mediaItem: handler.mediaItem,
          publisher: container.read(widgetPublisherProvider),
        ).start();
      }
      // On iPhone, the widget's play buttons are intents that run in this
      // process with the app in the background, and no screen. They talk to
      // the player through this, never through a widget. See widget_remote.dart.
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        WidgetRemote(
          audio: container.read(audioController),
          now: () => widgetPlaybackFor(
            handler.playbackState.value,
            handler.mediaItem.value,
          ),
          playing: handler.playbackState.map((s) => s.playing),
        ).start();
      }
    } catch (e) {
      // The app still plays. It just has no controls outside itself.
      debugPrint('Media session not started: $e');
    }
  }
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  final QuickActions quickActions = const QuickActions();
  final Intelligence? _intelligence =
      defaultTargetPlatform == TargetPlatform.iOS ? Intelligence() : null;
  static const MethodChannel _channel =
      MethodChannel('com.hsi.harki.live_darbar/audio');
  static const MethodChannel _oacpChannel =
      MethodChannel('com.hsi.harki.live_darbar/oacp');

  // The widget's tap opens the reader from outside the widget tree, so the
  // app needs a handle on its navigator.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<Uri?>? _widgetLinks;

  // Null on the web, which has no reminder.
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();

    if (kIsWeb || kIsWasm) {
      return;
    }

    unawaited(init());
    unawaited(deleteLegacyHukamnamaPdfs());

    _channel.setMethodCallHandler((call) async {
      if (call.method == "playLiveDarbar") {
        // Trigger playback logic
        ref.read(audioController).play(0);
      }
    });

    _oacpChannel.setMethodCallHandler(_handleOacpCommand);
    // Initialize quick actions with a callback
    quickActions.initialize((String shortcutType) {
      shortcutPlay(shortcutType, ref);
    });

    // Set quick action items
    quickActions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(
        type: 'live_kirtan',
        localizedTitle: 'Live Kirtan',
      ),
      const ShortcutItem(
        type: 'mukhwak',
        localizedTitle: 'Mukhwak',
      ),
      const ShortcutItem(
        type: 'mukhwak_katha',
        localizedTitle: 'Mukhwak Katha',
      ),
    ]);

    // Keep the home screen widget's text in step with the date and the
    // Hukamnama.
    if (HomeWidgetPublisher.isSupported) ref.read(widgetSyncProvider);

    // The iPhone widget opens the app with a link. See widget_links.dart.
    // A running app hears it on the stream. A cold start asks once, after
    // the first frame, so the navigator is there for the reader.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      _widgetLinks = HomeWidget.widgetClicked.listen(_handleWidgetLink);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          _handleWidgetLink(await HomeWidget.initiallyLaunchedFromHomeWidget());
        } on PlatformException catch (e) {
          debugPrint('Widget link not read: $e');
        }
      });
    }

    // The daily Hukamnama reminder. The app can stay open for days, so the
    // schedule is also set again each time it comes back to the front.
    _lifecycle = AppLifecycleListener(onResume: _onResume);
    unawaited(_startReminder());
  }

  /// Gets the reminder ready, and sets it again from the saved choice.
  ///
  /// It asks nothing. The one question about the reminder belongs to the
  /// Hukamnama reader, the first time the listener opens it
  /// (`askAboutReminderOnFirstOpen`). Asking here, on Home at launch, put it
  /// under the update offer, and it never appeared.
  ///
  /// "Today in Sikh history" is set again here, after the reminder has got the
  /// phone ready. It is never asked about: it is a switch in About.
  Future<void> _startReminder() async {
    await ref.read(reminderProvider.notifier).start(_openReaderFromReminder);
    unawaited(ref.read(sikhHistoryProvider.notifier).resync());
  }

  void _onResume() {
    unawaited(ref.read(reminderProvider.notifier).resync());
    unawaited(ref.read(sikhHistoryProvider.notifier).resync());
  }

  /// A tap on the reminder. When it started the app, there is no navigator
  /// yet, and this waits for one.
  void _openReaderFromReminder() => unawaited(
        openReaderFromReminder(() => _navigatorKey.currentState),
      );

  @override
  void dispose() {
    _widgetLinks?.cancel();
    _lifecycle?.dispose();
    _oacpChannel.setMethodCallHandler(null);
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  /// Does what the iPhone widget's button showed, from what the player does
  /// now. See [widgetTapFor].
  void _handleWidgetLink(Uri? uri) {
    final link = widgetLinkFrom(uri);
    if (link == null || !mounted) return;
    final session = _mediaSession;
    final now = session == null
        ? WidgetPlayback.idle
        : widgetPlaybackFor(
            session.playbackState.value,
            session.mediaItem.value,
          );
    final tap = widgetTapFor(link, now);
    if (tap == WidgetTap.openReader) {
      try {
        openHukamnamaReader(_navigatorKey.currentState);
      } on PlatformException catch (e) {
        debugPrint('Reader not opened: $e');
      }
      return;
    }
    unawaited(runWidgetTap(tap, ref.read(audioController)));
  }

  void _handleSelection(String id) {
    log("Intelligence: $id");
    shortcutPlay(id, ref);
  }

  Future<void> _handleOacpCommand(MethodCall call) async {
    if (call.method != 'handleOacpCommand') return;
    if (!mounted) return;
    final dynamic raw = call.arguments;
    if (raw is! Map) return;
    final command = raw['command'] as String?;
    log('OACP command received: $command');

    switch (command) {
      case kPlayLiveCommand:
        ref.read(audioController).play(kLiveIndex);
      // What a tap on the widget, away from its buttons, sends.
      case kOpenHukamnamaCommand:
        openHukamnamaReader(_navigatorKey.currentState);
      case 'play_mukhwak':
        ref.read(audioController).play(1);
      case 'play_katha':
        ref.read(audioController).play(2);
      case 'view_mukhwak_pdf':
        await openLinkInApp(kHukamnamaPdfPageUrl);
    }
  }

  Future<void> init() async {
    if (_intelligence == null) return; // Skip initialization if not on iOS

    try {
      _intelligence.selectionsStream().listen(_handleSelection);
    } on PlatformException catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeController);
    AppType.tracking = locale != 'pa';
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Live Darbar',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.material,
      darkTheme: AppTheme.material,
      themeMode: ThemeMode.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale(locale),
      // The text size limit and the banners, above every route, and the
      // browser tab's title.
      builder: appBuilder,
      navigatorObservers: [ref.watch(pageNamesProvider)],
      // A scrollbar on every vertical list on the web.
      scrollBehavior: const AppScrollBehavior(),
      // Pages are pushed by name, so the web shows them in the address bar.
      // See AppRoutes.
      home: const HomeScreen(),
      onGenerateRoute: AppRoutes.generator(),
    );
  }
}

void shortcutPlay(String? channelKey, WidgetRef ref) {
  if (channelKey == 'live_kirtan') {
    log('Live Kirtan action Triggered');
    ref.read(audioController).play(0); // Call play function
  } else if (channelKey == 'mukhwak') {
    log('Mukhwak action Triggered');
    ref.read(audioController).play(1);
  } else if (channelKey == 'mukhwak_katha') {
    log('Mukhwak Katha action Triggered');
    ref.read(audioController).play(2);
  }
}
