import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/core/store_links.dart';
import 'package:live_darbar/src/models/app_update.dart';
import 'package:live_darbar/src/views/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/app_harness.dart';

/// The update sheet asks once per release, however the listener closes it.
///
/// The app saves the declined build, and the next launch stays quiet for it.
/// Each way out must save it. If one does not, the sheet comes back at every
/// launch until the listener updates.
const _update = AppUpdate(
  version: '3.0.0',
  build: 10,
  storeUrl: kPlayStoreUrl,
  notesEn: ['A new release.'],
  notesPa: ['ਨਵਾਂ ਰੀਲੀਜ਼।'],
);

/// The key UpdateController reads at launch.
const _dismissedBuildKey = 'update_dismissed_build';

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _opensAtLaunch(WidgetTester tester) async {
  await pumpApp(tester, update: _update);
  await _settle(tester);
  expect(find.text('A new release.'), findsOneWidget, reason: 'sheet open');
}

Future<int?> _savedAnswer() async =>
    (await SharedPreferences.getInstance()).getInt(_dismissedBuildKey);

void _expectClosed(WidgetTester tester) {
  expect(find.text('A new release.'), findsNothing);
  expect(
    Navigator.of(tester.element(find.byType(HomeScreen))).canPop(),
    isFalse,
  );
}

void main() {
  testWidgets('a swipe down saves the answer', (tester) async {
    await _opensAtLaunch(tester);

    await tester.fling(find.text('A new release.'), const Offset(0, 600), 2000);
    await _settle(tester);

    _expectClosed(tester);
    expect(await _savedAnswer(), 10);
  });

  testWidgets('a tap on the dim saves the answer', (tester) async {
    await _opensAtLaunch(tester);

    await tester.tapAt(const Offset(20, 20));
    await _settle(tester);

    _expectClosed(tester);
    expect(await _savedAnswer(), 10);
  });

  testWidgets('the back gesture saves the answer', (tester) async {
    await _opensAtLaunch(tester);

    await tester.binding.handlePopRoute();
    await _settle(tester);

    _expectClosed(tester);
    expect(await _savedAnswer(), 10);
  });

  testWidgets('"Not now" saves the answer', (tester) async {
    await _opensAtLaunch(tester);

    await tester.tap(find.text('Not now'));
    await _settle(tester);

    _expectClosed(tester);
    expect(await _savedAnswer(), 10);
  });
}
