import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/core/store_links.dart';
import 'package:live_darbar/src/models/app_update.dart';
import 'package:live_darbar/src/views/screens/home_screen.dart';
import 'package:live_darbar/src/views/screens/now_playing_screen.dart';
import 'package:live_darbar/src/views/widgets/quality_sheet.dart';
import 'package:live_darbar/src/views/widgets/reminder_sheet.dart';
import 'package:live_darbar/src/views/widgets/update_sheet.dart';
import 'package:live_darbar/src/views/widgets/widget_steps_sheet.dart';

import '../support/app_harness.dart';

/// The Android back button and the back swipe close a sheet, and on Home they
/// leave the app.
///
/// Android has two ways to send back, and `android:enableOnBackInvokedCallback`
/// in the manifest picks between them. Off, the activity sends `popRoute`
/// (what `handlePopRoute` stands in for). On, Android asks the app first
/// whether it will handle back (`setFrameworkHandlesBack`), and a swipe
/// arrives as `startBackGesture` then `commitBackGesture`. Android 16 turns
/// the second way on for every app that targets it, this one included, so
/// both ways have to close every sheet. The Navigator answers both the same
/// way: every sheet here is a route on it.

typedef _Opener = Future<void> Function(BuildContext home);

final _sheets = <String, _Opener>{
  'the sound quality sheet': showQualitySheet,
  'the update sheet': (home) => showUpdateSheet(
        home,
        const AppUpdate(
          version: '2.3.0',
          build: 10,
          storeUrl: kPlayStoreUrl,
          notesEn: ['A new release.'],
          notesPa: ['ਨਵਾਂ ਰੀਲੀਜ਼।'],
        ),
      ),
  'the reminder question': showReminderPrompt,
  'the reminder time sheet': showReminderTimeSheet,
  'the widget steps': showWidgetStepsSheet,
  'the player': showNowPlaying,
};

NavigatorState _navigator(WidgetTester tester) =>
    Navigator.of(tester.element(find.byType(HomeScreen)));

/// Runs a transition to its end. The player cannot use `pumpAndSettle`: its
/// equalizer loops while sound plays.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _open(WidgetTester tester, _Opener open) async {
  unawaited(open(tester.element(find.byType(HomeScreen))));
  await _settle(tester);
  expect(_navigator(tester).canPop(), isTrue, reason: 'the sheet is open');
}

/// What the app asks of the phone on the platform channel, in order.
List<String> _platformCalls(WidgetTester tester) {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'SystemNavigator.pop') calls.add('pop');
      if (call.method == 'SystemNavigator.setFrameworkHandlesBack') {
        calls.add('handlesBack:${call.arguments}');
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return calls;
}

/// A back swipe, as Android sends it when the app has said it handles back.
Future<void> _swipeBack(WidgetTester tester, {bool commit = true}) async {
  Future<void> send(String method, Map<String, Object?> arguments) =>
      tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/backgesture',
        const StandardMethodCodec().encodeMethodCall(
          MethodCall(method, arguments),
        ),
        (_) {},
      );

  const edge = <String, Object?>{
    'touchOffset': <double>[2, 400],
    'swipeEdge': 0,
  };
  await send('startBackGesture', {...edge, 'progress': 0.0});
  await send('updateBackGestureProgress', {...edge, 'progress': 0.4});
  await send(commit ? 'commitBackGesture' : 'cancelBackGesture', {});
  await _settle(tester);
}

void main() {
  for (final MapEntry(key: name, value: open) in _sheets.entries) {
    group(name, () {
      testWidgets('closes on back, and the app stays open', (tester) async {
        final calls = _platformCalls(tester);
        await pumpApp(tester, now: livePlaying);
        await _open(tester, open);

        await tester.binding.handlePopRoute();
        await _settle(tester);

        expect(_navigator(tester).canPop(), isFalse, reason: 'closed');
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(calls, isNot(contains('pop')), reason: 'did not leave the app');
      });

      testWidgets('closes on a back swipe', (tester) async {
        await pumpApp(tester, now: livePlaying);
        await _open(tester, open);

        await _swipeBack(tester);

        expect(_navigator(tester).canPop(), isFalse, reason: 'closed');
      });

      testWidgets('stays open when the swipe is cancelled', (tester) async {
        await pumpApp(tester, now: livePlaying);
        await _open(tester, open);

        await _swipeBack(tester, commit: false);

        expect(_navigator(tester).canPop(), isTrue, reason: 'still open');
      });

      testWidgets('tells Android that the app handles back while it is open', (
        tester,
      ) async {
        // Only Android is told. A test runs as Android unless it says not.
        expect(defaultTargetPlatform, TargetPlatform.android);
        final calls = _platformCalls(tester);
        await pumpApp(tester, now: livePlaying);
        // The app tells the phone only once it has been in front.
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

        await _open(tester, open);
        expect(calls.last, 'handlesBack:true');

        await tester.binding.handlePopRoute();
        await _settle(tester);
        expect(calls.last, 'handlesBack:false', reason: 'Home again');
      });
    });
  }

  group('Home', () {
    testWidgets('leaves the app on back', (tester) async {
      final calls = _platformCalls(tester);
      await pumpApp(tester);

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(calls, ['pop']);
    });

    testWidgets('leaves the app on a back swipe', (tester) async {
      final calls = _platformCalls(tester);
      await pumpApp(tester);

      await _swipeBack(tester);

      expect(calls, ['pop']);
    });
  });
}
