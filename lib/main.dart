import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:live_darbar/src/views/screens/home_screen.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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

  @override
  void initState() {
    super.initState();

    if (kIsWeb || kIsWasm) {
      return;
    }
    // Initialize quick actions with a callback
    quickActions.initialize((String shortcutType) {
      if (shortcutType == 'live_kirtan') {
        log('Live Kirtan Action Triggered');
        ref.read(audioController).play(0); // Call play function
      } else if (shortcutType == 'mukhwak') {
        log('Mukhwak Action Triggered');
        ref.read(audioController).play(1); // Call pause function
      } else if (shortcutType == 'mukhwak_katha') {
        log('Mukhwak Katha Action Triggered');
        ref.read(audioController).play(2); // Call pause function
      }
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

  @override
  Widget build(BuildContext context) {
    return ShadApp.material(
      title: 'Live Darbar',
      debugShowCheckedModeBanner: false,
      darkTheme: ShadThemeData(
        colorScheme: const ShadOrangeColorScheme.dark(),
        brightness: Brightness.dark,
        textTheme: ShadTextTheme.fromGoogleFont(
          GoogleFonts.manrope,
        ),
      ),
      home: const HomeScreen(),
    );

    // return MaterialApp(
    //   title: 'Live Darbar',
    //   debugShowCheckedModeBanner: false,
    //   theme: ThemeData(
    //     textTheme: GoogleFonts.manropeTextTheme(),
    //     colorScheme: ColorScheme.fromSeed(
    //         seedColor: Color(0xFFFFAC1C), brightness: Brightness.dark),
    //     useMaterial3: true,
    //   ),
    //   home: const HomeScreen(),
    // );
  }
}
