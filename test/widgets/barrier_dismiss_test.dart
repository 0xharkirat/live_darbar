import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/core/store_links.dart';
import 'package:live_darbar/src/models/app_update.dart';
import 'package:live_darbar/src/views/screens/home_screen.dart';
import 'package:live_darbar/src/views/screens/now_playing_screen.dart';
import 'package:live_darbar/src/views/widgets/app_sheet.dart';
import 'package:live_darbar/src/views/widgets/quality_sheet.dart';
import 'package:live_darbar/src/views/widgets/update_sheet.dart';

import '../support/app_harness.dart';

/// A tap on the dimmed area closes a sheet, on every sheet in the app.
///
/// Swiping down is the phone's way. A mouse has no swipe, and a finger often
/// goes for the dim first, so the tap has to work too. Each sheet is also
/// checked under Reduce Motion, which builds it a different way.
const _dimmedTopLeft = Offset(20, 20);

NavigatorState _navigator(WidgetTester tester) =>
    Navigator.of(tester.element(find.byType(HomeScreen)));

/// Runs every sheet and page transition to its end.
///
/// The player cannot use `pumpAndSettle`: while sound plays its equalizer
/// loops, so the tree never settles.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _opens(WidgetTester tester, Future<void> Function() open) async {
  unawaited(open());
  await _settle(tester);
  expect(_navigator(tester).canPop(), isTrue, reason: 'the sheet is open');
}

Future<void> _tapDimmed(
  WidgetTester tester, [
  Offset at = _dimmedTopLeft,
]) async {
  await tester.tapAt(at);
  await _settle(tester);
}

void main() {
  for (final reduced in [false, true]) {
    final motion = reduced ? 'with Reduce Motion' : 'with motion';

    group(motion, () {
      testWidgets('the sound quality sheet closes', (tester) async {
        if (reduced) reduceMotion(tester);
        await pumpApp(tester);

        await _opens(
          tester,
          () => showQualitySheet(tester.element(find.byType(HomeScreen))),
        );
        await _tapDimmed(tester);

        expect(_navigator(tester).canPop(), isFalse);
      });

      testWidgets('the update sheet closes', (tester) async {
        if (reduced) reduceMotion(tester);
        await pumpApp(tester);

        await _opens(
          tester,
          () => showUpdateSheet(
            tester.element(find.byType(HomeScreen)),
            const AppUpdate(
              version: '2.3.0',
              build: 10,
              storeUrl: kPlayStoreUrl,
              notesEn: ['A new release.'],
              notesPa: ['ਨਵਾਂ ਰੀਲੀਜ਼।'],
            ),
          ),
        );
        await _tapDimmed(tester);

        expect(_navigator(tester).canPop(), isFalse);
      });

      testWidgets('any sheet made with showAppSheet closes', (tester) async {
        if (reduced) reduceMotion(tester);
        await pumpApp(tester);

        await _opens(
          tester,
          () => showAppSheet<void>(
            tester.element(find.byType(HomeScreen)),
            (_) => const SizedBox(height: 200, width: double.infinity),
          ),
        );
        await _tapDimmed(tester);

        expect(_navigator(tester).canPop(), isFalse);
      });

      testWidgets('the player closes', (tester) async {
        if (reduced) reduceMotion(tester);
        await pumpApp(tester, now: livePlaying);

        await _opens(
          tester,
          () => showNowPlaying(tester.element(find.byType(HomeScreen))),
        );
        expect(find.byType(NowPlayingScreen), findsOneWidget);
        await _tapDimmed(tester, const Offset(200, 20));

        expect(find.byType(NowPlayingScreen), findsNothing);
        expect(_navigator(tester).canPop(), isFalse);
      });
    });
  }

  testWidgets('a tap on the sheet itself does not close it', (tester) async {
    await pumpApp(tester, now: livePlaying);

    await _opens(
      tester,
      () => showNowPlaying(tester.element(find.byType(HomeScreen))),
    );
    // The middle of the player: the artwork, not a control.
    await tester.tapAt(const Offset(200, 300));
    await _settle(tester);

    expect(find.byType(NowPlayingScreen), findsOneWidget);
  });
}
