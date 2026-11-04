import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/views/screens/home_screen.dart';
import 'package:live_darbar/src/views/screens/now_playing_screen.dart';

import '../support/app_harness.dart';

/// The full-screen player is a modern iOS sheet: the page behind it scales
/// back, and a swipe down on its top part closes it, with the finger's speed.

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _open(WidgetTester tester) async {
  await pumpApp(tester, now: livePlaying);
  showNowPlaying(tester.element(find.byType(HomeScreen)));
  await _settle(tester);
}

void main() {
  testWidgets('home is at full size until the player opens', (tester) async {
    await pumpApp(tester, now: livePlaying);

    expect(tester.getRect(find.byType(HomeScreen)).width, 402);
  });

  testWidgets('the page behind scales back when the player is open', (
    tester,
  ) async {
    await _open(tester);

    final home = tester.getRect(find.byType(HomeScreen));
    expect(home.width, lessThan(402));
    expect(home.width, greaterThan(402 * 0.8));
  });

  testWidgets('and scales back up when it closes', (tester) async {
    await _open(tester);

    Navigator.of(tester.element(find.byType(NowPlayingScreen))).pop();
    await _settle(tester);

    expect(find.byType(NowPlayingScreen), findsNothing);
    expect(tester.getRect(find.byType(HomeScreen)).width, 402);
  });

  testWidgets('a flick down from the top part closes it', (tester) async {
    await _open(tester);

    // On the artwork, near the top of the sheet.
    await tester.flingFrom(const Offset(200, 160), const Offset(0, 200), 1800);
    await _settle(tester);

    expect(find.byType(NowPlayingScreen), findsNothing);
  });

  testWidgets('a short slow drag lets it spring back', (tester) async {
    await _open(tester);

    final gesture = await tester.startGesture(const Offset(200, 160));
    for (var i = 0; i < 5; i++) {
      await gesture.moveBy(const Offset(0, 8));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await _settle(tester);

    expect(find.byType(NowPlayingScreen), findsOneWidget);
  });
}
