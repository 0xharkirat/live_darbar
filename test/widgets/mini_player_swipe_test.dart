import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/views/screens/now_playing_screen.dart';
import 'package:live_darbar/src/views/widgets/mini_player_widget.dart';

import '../support/app_harness.dart';

/// The mini player opens the full player on a tap or a swipe up. The swipe
/// hands its speed to the sheet, which opens on a spring that starts there.

/// Runs the sheet's move to its end. The player cannot use `pumpAndSettle`:
/// while sound plays its equalizer loops, so the tree never settles.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
}

Finder get _miniPlayer => find.byType(MiniPlayer);

/// How far down the screen the player's top edge is, 60 ms after the
/// gesture let go.
Future<double> _topAfter(WidgetTester tester, Duration after) async {
  await tester.pump();
  await tester.pump(after);
  return tester.getTopLeft(find.byType(NowPlayingScreen)).dy;
}

void main() {
  testWidgets('a short, quick flick up opens the player', (tester) async {
    await pumpApp(tester, now: livePlaying);
    await tester.fling(_miniPlayer, const Offset(0, -80), 1200);
    await _settle(tester);

    expect(find.byType(NowPlayingScreen), findsOneWidget);
  });

  testWidgets('a slow pull of 60 points opens it without a flick', (
    tester,
  ) async {
    await pumpApp(tester, now: livePlaying);

    final gesture = await tester.startGesture(tester.getCenter(_miniPlayer));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, -6));
      await tester.pump(const Duration(milliseconds: 120));
    }
    // Hold still before letting go, so the finger has no speed.
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await _settle(tester);

    expect(find.byType(NowPlayingScreen), findsOneWidget);
  });

  testWidgets('a slow pull of 36 points does nothing', (tester) async {
    await pumpApp(tester, now: livePlaying);

    final gesture = await tester.startGesture(tester.getCenter(_miniPlayer));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(0, -6));
      await tester.pump(const Duration(milliseconds: 120));
    }
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await _settle(tester);

    expect(find.byType(NowPlayingScreen), findsNothing);
  });

  testWidgets('a swipe down does not open it', (tester) async {
    await pumpApp(tester, now: livePlaying);

    await tester.fling(_miniPlayer, const Offset(0, 40), 1200);
    await _settle(tester);

    expect(find.byType(NowPlayingScreen), findsNothing);
  });

  testWidgets('a hard flick throws the sheet open faster than a tap', (
    tester,
  ) async {
    await pumpApp(tester, now: livePlaying);
    await tester.tap(_miniPlayer);
    final tapped = await _topAfter(tester, const Duration(milliseconds: 60));

    // A new app for the second open.
    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester, now: livePlaying);
    await tester.fling(_miniPlayer, const Offset(0, -60), 3000);
    final flicked = await _topAfter(tester, const Duration(milliseconds: 60));

    expect(
      flicked,
      lessThan(tapped),
      reason: 'a smaller top is further up: the flick is further along',
    );
  });

  testWidgets('both open to the same place', (tester) async {
    await pumpApp(tester, now: livePlaying);
    await tester.tap(_miniPlayer);
    await _settle(tester);
    final tapped = tester.getTopLeft(find.byType(NowPlayingScreen)).dy;

    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester, now: livePlaying);
    await tester.fling(_miniPlayer, const Offset(0, -60), 3000);
    await _settle(tester);

    expect(tester.getTopLeft(find.byType(NowPlayingScreen)).dy, tapped);
  });

  testWidgets('with Reduce Motion the sheet does not travel', (tester) async {
    reduceMotion(tester);
    await pumpApp(tester, now: livePlaying);
    await tester.fling(_miniPlayer, const Offset(0, -60), 3000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final early = tester.getTopLeft(find.byType(NowPlayingScreen)).dy;

    await _settle(tester);
    expect(early, tester.getTopLeft(find.byType(NowPlayingScreen)).dy);
  });
}
