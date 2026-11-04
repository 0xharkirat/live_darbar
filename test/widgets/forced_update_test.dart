import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/core/store_links.dart';
import 'package:live_darbar/src/models/app_update.dart';
import 'package:live_darbar/src/models/maintenance.dart';
import 'package:live_darbar/src/views/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/app_harness.dart';

/// A build below the manifest's `minBuild` gets a sheet that cannot be closed
/// and offers only the store. While `release.json` carries a maintenance
/// message, a calm banner says it, and the app keeps playing.
const _forced = AppUpdate(
  version: '3.1.0',
  build: 11,
  storeUrl: kPlayStoreUrl,
  notesEn: ['A fix for a problem that stops playback.'],
  notesPa: ['ਇੱਕ ਸਮੱਸਿਆ ਦਾ ਹੱਲ।'],
  forced: true,
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

NavigatorState _navigator(WidgetTester tester) =>
    Navigator.of(tester.element(find.byType(HomeScreen)));

Future<void> _opensAtLaunch(WidgetTester tester, {String locale = 'en'}) async {
  await pumpApp(tester, update: _forced, locale: locale);
  await _settle(tester);
  expect(_navigator(tester).canPop(), isTrue, reason: 'the sheet is open');
}

void main() {
  group('a forced update', () {
    testWidgets('opens at launch, and says why', (tester) async {
      await _opensAtLaunch(tester);

      expect(find.text('Please update'), findsOneWidget);
      expect(
        find.text('This version is too old to work well. Update it from the store to go on.'),
        findsOneWidget,
      );
      expect(find.text('Version 3.1.0'), findsOneWidget);
      expect(find.text('A fix for a problem that stops playback.'), findsOneWidget);
    });

    testWidgets('offers the store and nothing else', (tester) async {
      await _opensAtLaunch(tester);

      expect(find.text('Update now'), findsOneWidget);
      expect(find.text('Not now'), findsNothing);
    });

    testWidgets('reads in Punjabi', (tester) async {
      await _opensAtLaunch(tester, locale: 'pa');

      expect(find.text('ਕਿਰਪਾ ਕਰਕੇ ਅੱਪਡੇਟ ਕਰੋ'), findsOneWidget);
      expect(find.text('Please update'), findsNothing);
    });

    testWidgets('a tap on the dim does not close it', (tester) async {
      await _opensAtLaunch(tester);

      await tester.tapAt(const Offset(20, 20));
      await _settle(tester);

      expect(find.text('Please update'), findsOneWidget);
    });

    testWidgets('a swipe down does not close it', (tester) async {
      await _opensAtLaunch(tester);

      await tester.fling(find.text('Please update'), const Offset(0, 600), 2500);
      await _settle(tester);

      expect(find.text('Please update'), findsOneWidget);
      // And it is back in its place, not left lower on the screen.
      final top = tester.getTopLeft(find.text('Please update')).dy;
      await tester.pump(const Duration(seconds: 1));
      expect(tester.getTopLeft(find.text('Please update')).dy, top);
    });

    testWidgets('the back button does not close it', (tester) async {
      await _opensAtLaunch(tester);

      await tester.binding.handlePopRoute();
      await _settle(tester);

      expect(find.text('Please update'), findsOneWidget);
    });

    testWidgets('with Reduce Motion it still stays', (tester) async {
      reduceMotion(tester);
      await _opensAtLaunch(tester);

      await tester.fling(find.text('Please update'), const Offset(0, 600), 2500);
      await tester.tapAt(const Offset(20, 20));
      await tester.binding.handlePopRoute();
      await _settle(tester);

      expect(find.text('Please update'), findsOneWidget);
    });

    testWidgets('Update now keeps the sheet, for the listener who comes back', (
      tester,
    ) async {
      await _opensAtLaunch(tester);

      await tester.tap(find.text('Update now'));
      await _settle(tester);

      expect(find.text('Please update'), findsOneWidget);
    });

    testWidgets('is never saved as declined', (tester) async {
      await _opensAtLaunch(tester);
      await tester.tapAt(const Offset(20, 20));
      await _settle(tester);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('update_dismissed_build'), isNull);
    });
  });

  group('the maintenance banner', () {
    const message = Maintenance(
      en: 'Live kirtan may stop for a few minutes while we fix the stream.',
      pa: 'ਅਸੀਂ ਸਟ੍ਰੀਮ ਠੀਕ ਕਰ ਰਹੇ ਹਾਂ।',
    );

    testWidgets('is not there when the file has no message', (tester) async {
      await pumpApp(tester);
      await _settle(tester);

      expect(find.textContaining('may stop for a few minutes'), findsNothing);
      expect(find.byIcon(CupertinoIcons.wrench), findsNothing);
    });

    testWidgets('says the message, in the listener\'s language', (tester) async {
      await pumpApp(tester, maintenance: message);
      await _settle(tester);

      expect(find.text(message.en!), findsOneWidget);
    });

    testWidgets('in Punjabi', (tester) async {
      await pumpApp(tester, locale: 'pa', maintenance: message);
      await _settle(tester);

      expect(find.text(message.pa!), findsOneWidget);
      expect(find.text(message.en!), findsNothing);
    });

    testWidgets('stays above a page that opens, as the offline banner does', (
      tester,
    ) async {
      await pumpApp(tester, maintenance: message, initialRoute: '/about');
      await _settle(tester);

      expect(find.text(message.en!), findsOneWidget);
    });

    testWidgets('blocks nothing: the app still plays what it can', (
      tester,
    ) async {
      await pumpApp(tester, maintenance: message);
      await _settle(tester);

      expect(find.text('Live Kirtan').hitTestable(), findsWidgets);
      expect(_navigator(tester).canPop(), isFalse, reason: 'no sheet opened');
    });
  });
}
