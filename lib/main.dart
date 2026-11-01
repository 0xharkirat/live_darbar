import 'dart:async';
import 'dart:developer';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intelligence/intelligence.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:live_darbar/src/controllers/locale_controller.dart';
import 'package:live_darbar/src/media_session/live_darbar_audio_handler.dart';
import 'package:live_darbar/src/core/app_theme.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/views/screens/home_screen.dart';
import 'package:live_darbar/src/views/screens/mukhwak_pdf_viewer.dart';
import 'package:live_darbar/src/views/widgets/offline_banner_widget.dart';
import 'package:live_darbar/src/controllers/mukhwak_controller.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:live_darbar/l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Lock the UI to portrait up orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  final container = ProviderContainer();
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

    // Connect the media session: the notification, the lock screen, headset
    // buttons, Android Auto and voice assistants.
    //
    // Before the first frame, and with a container made here rather than by
    // the widget tree. A car or an assistant can start the app with no screen
    // at all, and a command from it finds a handler on a controller that is
    // already there. A provider that waited for a widget to read it would
    // wait for ever.
    try {
      await LiveDarbarAudioHandler.init(container.read(audioController));
    } catch (e) {
      // The app still plays. It just has no controls outside itself.
      debugPrint('Media session not started: $e');
    }
  }

  runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
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
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();

    if (kIsWeb || kIsWasm) {
      return;
    }

    unawaited(init());

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

    // Prefetch daily Mukhwak PDF
    ref.read(mukhwakController.notifier).fetchAndCache();
  }

  @override
  void dispose() {
    _oacpChannel.setMethodCallHandler(null);
    _channel.setMethodCallHandler(null);
    super.dispose();
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
      case 'play_live_kirtan':
        ref.read(audioController).play(0);
      case 'play_mukhwak':
        ref.read(audioController).play(1);
      case 'play_katha':
        ref.read(audioController).play(2);
      case 'view_mukhwak_pdf':
        _navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => const MukhwakPdfViewer(),
          ),
        );
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
      // The offline banner lives above every route rather than inside
      // HomeScreen, so it is still there when the player dialog or the PDF
      // viewer is open. Losing your connection while reading the Mukhwak is
      // exactly when you want to be told.
      builder: (context, child) => Column(
        children: [
          const OfflineBannerWidget(),
          Expanded(child: child ?? const SizedBox.shrink()),
        ],
      ),
      home: const HomeScreen(),
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
