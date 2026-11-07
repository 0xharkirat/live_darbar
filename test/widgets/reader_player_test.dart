import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/views/app_router.dart';
import 'package:live_darbar/src/views/screens/home_screen.dart';
import 'package:live_darbar/src/views/screens/hukamnama_screen.dart';
import 'package:live_darbar/src/views/screens/now_playing_screen.dart';
import 'package:live_darbar/src/views/widgets/language_switch.dart';
import 'package:live_darbar/src/views/widgets/mini_player_widget.dart';
import 'package:live_darbar/src/views/widgets/source_switcher.dart';

import '../support/app_harness.dart';

/// The 3.1 design review: the reader's own player, the scrubber for a screen
/// reader, and targets of 44 pt or more.

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

Finder get _readerPlayer => find.descendant(
      of: find.byType(HukamnamaScreen),
      matching: find.byType(MiniPlayer),
    );

Future<void> _openPlayer(WidgetTester tester) async {
  showNowPlaying(tester.element(find.byType(HomeScreen)));
  await _settle(tester);
}

/// The height of the tap target around [label]: the nearest gesture detector.
double _targetHeight(WidgetTester tester, Finder label) => tester
    .getSize(
      find.ancestor(of: label, matching: find.byType(GestureDetector)).first,
    )
    .height;

void main() {
  group('the reader', () {
    testWidgets('has no player before anything has played', (tester) async {
      await pumpApp(tester, initialRoute: AppRoutes.hukamnama);
      await _settle(tester);

      final opacity = tester.widget<AnimatedOpacity>(
        find.descendant(of: _readerPlayer, matching: find.byType(AnimatedOpacity)),
      );
      expect(opacity.opacity, 0);
    });

    testWidgets('has the player once sound has started, and it opens the '
        'full player', (tester) async {
      await pumpApp(
        tester,
        now: recordingPlaying,
        initialRoute: AppRoutes.hukamnama,
      );
      await _settle(tester);

      expect(_readerPlayer, findsOneWidget);
      await tester.tap(_readerPlayer);
      await _settle(tester);

      expect(find.byType(NowPlayingScreen), findsOneWidget);
    });

    testWidgets('opened from the player goes back to it, and opens no second '
        'player', (tester) async {
      await pumpApp(tester, now: recordingPlaying);
      await _openPlayer(tester);
      await tester.tap(find.text('Read'));
      await _settle(tester);
      expect(find.byType(HukamnamaScreen), findsOneWidget);

      await tester.tap(_readerPlayer);
      await _settle(tester);

      expect(find.byType(HukamnamaScreen), findsNothing);
      expect(find.byType(NowPlayingScreen), findsOneWidget);
    });

    testWidgets('then a later tap on home opens the player again', (
      tester,
    ) async {
      await pumpApp(tester, now: recordingPlaying);
      await _openPlayer(tester);
      Navigator.of(tester.element(find.byType(NowPlayingScreen))).pop();
      await _settle(tester);
      expect(find.byType(NowPlayingScreen), findsNothing);

      await _openPlayer(tester);

      expect(find.byType(NowPlayingScreen), findsOneWidget);
    });
  });

  testWidgets('a screen reader hears the place in a recording, and moves it '
      '15 seconds', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(tester, now: recordingPlaying);
    await _openPlayer(tester);

    expect(
      tester.getSemantics(find.bySemanticsLabel('Playback position')),
      isSemantics(
        isSlider: true,
        value: '3:00 of 9:00',
        increasedValue: '3:15 of 9:00',
        decreasedValue: '2:45 of 9:00',
        hasIncreaseAction: true,
        hasDecreaseAction: true,
      ),
    );
    semantics.dispose();
  });

  group('every target is 44 pt or more:', () {
    testWidgets('the language switch', (tester) async {
      await pumpApp(tester);

      for (final label in ['English', 'ਪੰਜਾਬੀ']) {
        final option = find.descendant(
          of: find.byType(LanguageSwitch),
          matching: find.text(label),
        );
        expect(_targetHeight(tester, option), greaterThanOrEqualTo(44));
      }
    });

    testWidgets('the sources in the player', (tester) async {
      await pumpApp(tester, now: livePlaying);
      await _openPlayer(tester);

      final live = find.descendant(
        of: find.byType(SourceSwitcher),
        matching: find.text('Live'),
      );
      expect(_targetHeight(tester, live), greaterThanOrEqualTo(44));
    });

    testWidgets('Read in the player', (tester) async {
      await pumpApp(tester, now: recordingPlaying);
      await _openPlayer(tester);

      expect(
        _targetHeight(tester, find.text('Read')),
        greaterThanOrEqualTo(44),
      );
    });
  });
}
