import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intelligence/intelligence.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:live_darbar/src/controllers/locale_controller.dart';
import 'package:live_darbar/src/controllers/theme_controller.dart';
import 'package:live_darbar/src/core/app_theme.dart';
import 'package:live_darbar/src/views/screens/home_screen.dart';
import 'package:live_darbar/src/views/screens/mukhwak_pdf_viewer.dart';
import 'package:live_darbar/src/views/widgets/offline_banner_widget.dart';
import 'package:live_darbar/src/controllers/mukhwak_controller.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:live_darbar/l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Lock the UI to portrait up orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  if (!kIsWeb && !kIsWasm) {
    // Enable background audio playback
    //
    // The channel id is copied from just_audio_background's own example and
    // reads oddly, but leave it alone. Android keys notification channels by
    // id and never deletes an old one short of an uninstall, so renaming it
    // would leave every existing user with two "Audio playback" entries in
    // their notification settings. The id is invisible to users; only the name
    // shows. Nothing is gained by fixing it and something is lost.
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: true,
    );
  }

  runApp(const ProviderScope(child: MyApp()));
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
    final themeColor = ref.watch(themeController);
    final locale = ref.watch(localeController);
    return ShadApp(
      navigatorKey: _navigatorKey,
      title: 'Live Darbar',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.shadThemeData(themeColor.colorScheme),
      darkTheme: AppTheme.shadThemeData(themeColor.colorScheme),
      materialThemeBuilder: (context, theme) {
        return AppTheme.materialThemeData(themeColor.colorScheme);
      },
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
