import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:live_darbar/src/controllers/now_playing_controller.dart';
import 'package:live_darbar/src/core/motion.dart';
import 'package:live_darbar/src/views/widgets/play_button.dart';

import '../support/app_harness.dart';

/// The glyph in the middle of the play button: play, pause, stop and retry.
///
/// It changes in place, over the same disc. The new glyph comes in from 95% with
/// a fade, and the old one leaves faster than the new one arrives, so the
/// button never shows two glyphs at full strength. Under Reduce Motion nothing
/// moves: the glyphs only cross-fade.
void main() {
  Future<void> pumpButton(WidgetTester tester, NowPlaying now) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [nowPlayingProvider.overrideWithValue(now)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: Center(child: PlayButton(index: kMukhwakIndex)),
          ),
        ),
      ),
    );
  }

  final play = find.byIcon(CupertinoIcons.play_fill);
  final pause = find.byIcon(CupertinoIcons.pause_fill);

  /// The glyph's own transitions: inside the switcher, not the press scale
  /// around the whole button.
  Finder inGlyph(Finder of, Type transition) => find.descendant(
        of: find.byType(AnimatedSwitcher),
        matching: find.ancestor(of: of, matching: find.byType(transition)),
      );

  double scaleOf(WidgetTester tester, Finder glyph) => tester
      .widget<ScaleTransition>(inGlyph(glyph, ScaleTransition).first)
      .scale
      .value;

  double opacityOf(WidgetTester tester, Finder glyph) => tester
      .widget<FadeTransition>(inGlyph(glyph, FadeTransition).first)
      .opacity
      .value;

  /// Starts the change from play to pause and runs the first frame.
  Future<void> startSwap(WidgetTester tester) async {
    await pumpButton(tester, idle);
    await pumpButton(tester, recordingPlaying);
    await tester.pump();
  }

  testWidgets('the new glyph enters from 95%, not from nothing', (
    tester,
  ) async {
    await startSwap(tester);

    expect(scaleOf(tester, pause), closeTo(Motion.enterScale, 0.001));
    expect(Motion.enterScale, 0.95);
    expect(opacityOf(tester, pause), closeTo(0, 0.001));
  });

  testWidgets('and grows to 100% as it fades in', (tester) async {
    await startSwap(tester);

    await tester.pump(const Duration(milliseconds: 60));
    final partway = scaleOf(tester, pause);
    expect(partway, inExclusiveRange(Motion.enterScale, 1));
    expect(opacityOf(tester, pause), inExclusiveRange(0, 1));

    await tester.pump(Motion.quick);
    expect(scaleOf(tester, pause), 1);
    expect(opacityOf(tester, pause), 1);
  });

  testWidgets('the old glyph leaves before the new one has arrived', (
    tester,
  ) async {
    await startSwap(tester);

    await tester.pump(const Duration(milliseconds: 100));
    expect(play, findsOneWidget, reason: 'still leaving at 100 ms');

    await tester.pump(const Duration(milliseconds: 25));
    expect(play, findsNothing, reason: 'gone at 125 ms, as Motion.press ends');
    expect(
      scaleOf(tester, pause),
      lessThan(1),
      reason: 'the new glyph is still arriving',
    );
  });

  testWidgets('the old glyph shrinks to 95% as it leaves', (tester) async {
    await startSwap(tester);

    await tester.pump(const Duration(milliseconds: 60));

    expect(scaleOf(tester, play), inExclusiveRange(Motion.enterScale, 1));
    expect(opacityOf(tester, play), inExclusiveRange(0, 1));
  });

  test('the exit is faster than the entrance', () {
    expect(Motion.press, lessThan(Motion.quick));
  });

  group('with Reduce Motion', () {
    testWidgets('the glyphs only fade', (tester) async {
      reduceMotion(tester);

      await startSwap(tester);

      expect(inGlyph(pause, ScaleTransition), findsNothing);
      expect(inGlyph(pause, FadeTransition), findsWidgets);
    });

    testWidgets('and the new glyph still arrives', (tester) async {
      reduceMotion(tester);

      await startSwap(tester);
      await tester.pump(Motion.quick);

      expect(pause, findsOneWidget);
      expect(play, findsNothing);
    });
  });
}
