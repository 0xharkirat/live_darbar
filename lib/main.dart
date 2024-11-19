import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:live_darbar/src/views/screens/home_screen.dart';
import 'package:quick_actions/quick_actions.dart';

void main() {
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

    // Initialize quick actions with a callback
    quickActions.initialize((String shortcutType) {
      if (shortcutType == 'action_play') {
        print('Play action triggered');
        ref.read(audioController).play(); // Call play function
      } else if (shortcutType == 'action_pause') {
        print('Pause action triggered');
        ref.read(audioController).pause(); // Call pause function
      }
    });

    // Set quick action items
    quickActions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(
        type: 'action_play',
        localizedTitle: 'Play Audio',
        icon: 'icon_play', // Replace with your asset name for play
      ),
      const ShortcutItem(
        type: 'action_pause',
        localizedTitle: 'Pause Audio',
        icon: 'icon_pause', // Replace with your asset name for pause
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Live Darbar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.manropeTextTheme(),
        colorScheme: ColorScheme.fromSeed(
            seedColor: Color(0xFFFFAC1C), brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
