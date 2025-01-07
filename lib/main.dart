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
import 'package:quick_actions/quick_actions.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Lock the UI to portrait up orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  if (!kIsWeb && !kIsWasm) {
    // Enable background audio playback
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
  }

  void _handleSelection(String id) {
    log("Intelligence: $id");
    shortcutPlay(id, ref);
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
    return ShadApp.material(
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
    ref.read(audioController).play(1); // Call pause function
  } else if (channelKey == 'mukhwak_katha') {
    log('Mukhwak Katha action Triggered');
    ref.read(audioController).play(2); // Call pause function
  }
}
