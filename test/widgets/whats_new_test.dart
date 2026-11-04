import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/core/store_links.dart';
import 'package:live_darbar/src/models/app_update.dart';
import 'package:live_darbar/src/models/whats_new.dart';
import 'package:live_darbar/src/views/screens/home_screen.dart';
import 'package:live_darbar/src/views/widgets/whats_new_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/app_harness.dart';

/// The first open after an update shows 1 calm sheet of what is new, once.
/// The test app is version 2.2.1, so its release is 2.2.
const _notes = {
  '2.2': WhatsNew(
    release: '2.2',
    items: [
      WhatsNewItem(
        titleEn: 'Home screen widget',
        titlePa: 'ਹੋਮ ਸਕ੍ਰੀਨ ਵਿਜੇਟ',
        bodyEn: 'Play without opening the app.',
        bodyPa: 'ਐਪ ਖੋਲ੍ਹੇ ਬਿਨਾਂ ਚਲਾਓ।',
      ),
      WhatsNewItem(titleEn: 'Daily reminder', titlePa: 'ਰੋਜ਼ਾਨਾ ਰਿਮਾਈਂਡਰ'),
      WhatsNewItem(titleEn: 'Sikh history', titlePa: 'ਸਿੱਖ ਇਤਿਹਾਸ'),
    ],
  ),
};

/// An existing install: the listener has saved something before.
const _updated = {'locale': 'en', 'whats_new_seen_release': '2.1'};

final _title = find.text('What’s new in 2.2');

/// The calm the app asks for in a phone. With none, a sheet that opens a frame
/// later (the update offer, after its check) could be passed by.
const _settleTime = Duration(milliseconds: 500);

/// The app goes to the background, the way the system walks it there.
void _leave(WidgetTester tester) {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  addTearDown(() => _return(tester));
}

/// And back to the front.
void _return(WidgetTester tester) {
  if (tester.binding.lifecycleState == AppLifecycleState.resumed) return;
  for (final state in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    if (tester.binding.lifecycleState == state) continue;
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

Future<String?> _seen() async =>
    (await SharedPreferences.getInstance()).getString('whats_new_seen_release');

NavigatorState _navigator(WidgetTester tester) =>
    Navigator.of(tester.element(find.byType(HomeScreen)));

void main() {
  group('after an update', () {
    testWidgets('the sheet opens with the new things', (tester) async {
      await pumpApp(tester, prefs: _updated, whatsNew: _notes);
      await _settle(tester);

      expect(_title, findsOneWidget);
      expect(find.text('Home screen widget'), findsOneWidget);
      expect(find.text('Play without opening the app.'), findsOneWidget);
      expect(find.text('Daily reminder'), findsOneWidget);
      expect(find.text('Sikh history'), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);
    });

    testWidgets('it reads in Punjabi when the app does', (tester) async {
      await pumpApp(
        tester,
        locale: 'pa',
        prefs: {..._updated, 'locale': 'pa'},
        whatsNew: _notes,
      );
      await _settle(tester);

      expect(find.text('2.2 ਵਿੱਚ ਕੀ ਨਵਾਂ ਹੈ'), findsOneWidget);
      expect(find.text('ਹੋਮ ਸਕ੍ਰੀਨ ਵਿਜੇਟ'), findsOneWidget);
      expect(find.text('ਰੋਜ਼ਾਨਾ ਰਿਮਾਈਂਡਰ'), findsOneWidget);
      expect(find.text('Daily reminder'), findsNothing);
    });

    testWidgets('Got it closes it, and the release is saved as seen', (
      tester,
    ) async {
      await pumpApp(tester, prefs: _updated, whatsNew: _notes);
      await _settle(tester);

      await tester.tap(find.text('Got it'));
      await _settle(tester);

      expect(_title, findsNothing);
      expect(_navigator(tester).canPop(), isFalse);
      expect(await _seen(), '2.2');
    });

    testWidgets('a swipe down closes it too, and it never comes back', (
      tester,
    ) async {
      await pumpApp(tester, prefs: _updated, whatsNew: _notes);
      await _settle(tester);

      await tester.fling(find.text('Got it'), const Offset(0, 300), 1800);
      await _settle(tester);
      expect(_title, findsNothing);

      // The next launch.
      await tester.pumpWidget(const SizedBox());
      await pumpApp(tester, prefs: {..._updated, ...{'whats_new_seen_release': '2.2'}}, whatsNew: _notes);
      await _settle(tester);
      expect(_title, findsNothing);
    });

    testWidgets('it shows to a listener whose old build kept no record', (
      tester,
    ) async {
      await pumpApp(tester, prefs: {'locale': 'en'}, whatsNew: _notes);
      await _settle(tester);

      expect(_title, findsOneWidget);
    });
  });

  group('shows nothing', () {
    testWidgets('on a fresh install, and records the release', (tester) async {
      await pumpApp(tester, whatsNew: _notes);
      await _settle(tester);

      expect(_title, findsNothing);
      expect(await _seen(), '2.2');
    });

    testWidgets('when the release was seen already', (tester) async {
      await pumpApp(
        tester,
        prefs: {'locale': 'en', 'whats_new_seen_release': '2.2'},
        whatsNew: _notes,
      );
      await _settle(tester);

      expect(_title, findsNothing);
    });

    testWidgets('when the release has no notes', (tester) async {
      await pumpApp(tester, prefs: _updated);
      await _settle(tester);

      expect(find.byType(WhatsNewSheet), findsNothing);
      expect(await _seen(), '2.2');
    });
  });

  group('waits', () {
    testWidgets('while the app has no screen, then opens on the first look', (
      tester,
    ) async {
      // A tap on the home screen widget, the car or Siri starts the app with
      // no screen.
      _leave(tester);
      await pumpApp(
        tester,
        prefs: _updated,
        whatsNew: _notes,
        whatsNewSettle: _settleTime,
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(_title, findsNothing);
      expect(await _seen(), '2.1', reason: 'not spent while nobody looks');

      _return(tester);
      await tester.pump(const Duration(milliseconds: 300));
      await _settle(tester);

      expect(_title, findsOneWidget);
    });

    testWidgets('and never opens over the update offer', (tester) async {
      await pumpApp(
        tester,
        prefs: _updated,
        whatsNew: _notes,
        whatsNewSettle: _settleTime,
        update: const AppUpdate(
          version: '2.3.0',
          build: 99,
          storeUrl: kPlayStoreUrl,
          notesEn: ['A newer release.'],
          notesPa: ['ਨਵਾਂ ਰੀਲੀਜ਼।'],
        ),
      );
      await _settle(tester);

      expect(find.text('A newer release.'), findsOneWidget);
      expect(_title, findsNothing, reason: 'the offer is on top');
      expect(await _seen(), '2.1', reason: 'not spent under the offer');

      // The listener answers the offer. Then the notes follow.
      await tester.tap(find.text('Not now').evaluate().isNotEmpty
          ? find.text('Not now')
          : find.text('Later'));
      await _settle(tester);
      await tester.pump(const Duration(milliseconds: 600));
      await _settle(tester);

      expect(find.text('A newer release.'), findsNothing);
      expect(_title, findsOneWidget);
    });

    testWidgets('and never opens over a page', (tester) async {
      await pumpApp(
        tester,
        prefs: _updated,
        whatsNew: _notes,
        whatsNewSettle: _settleTime,
        initialRoute: '/about',
      );
      await _settle(tester);

      expect(_title, findsNothing);
    });
  });
}
