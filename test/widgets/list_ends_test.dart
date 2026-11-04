import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/core/store_links.dart';
import 'package:live_darbar/src/models/app_update.dart';
import 'package:live_darbar/src/models/whats_new.dart';
import 'package:live_darbar/src/views/screens/home_screen.dart';
import 'package:live_darbar/src/views/screens/now_playing_screen.dart';
import 'package:live_darbar/src/views/widgets/mini_player_widget.dart';
import 'package:live_darbar/src/views/widgets/quality_sheet.dart';

import '../support/app_harness.dart';

/// A list ends above the system navigation bar, and above the mini player on
/// Home, so its last item is never hidden. The bar's height changes with the
/// phone, so the space comes from the view's bottom padding, not from a number.
///
/// `SafeArea` around a scroll view is not the fix. It shrinks the scrolling
/// area, so an item is cut off as it reaches the bar instead of sliding under
/// it. The space belongs inside the scroll view.

/// The bar of a phone with a home indicator: 34 points.
const _bar = 34.0;

/// The phone's bottom padding, as the system sets it.
void _withNavigationBar(WidgetTester tester) {
  // Physical pixels: the harness is at 3x.
  tester.view.padding = const FakeViewPadding(bottom: _bar * 3);
  tester.view.viewPadding = const FakeViewPadding(bottom: _bar * 3);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

double get _viewHeight => 874;

/// The scroll view to the end, and the lowest text in it.
Future<double> _lowestTextAtTheEnd(
  WidgetTester tester,
  Finder scrollView,
) async {
  final scrollable = tester.state<ScrollableState>(
    find.descendant(of: scrollView, matching: find.byType(Scrollable)).first,
  );
  scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
  await tester.pump();

  var lowest = 0.0;
  for (final text in find
      .descendant(of: scrollView, matching: find.byType(Text))
      .evaluate()) {
    final rect = tester.getRect(find.byElementPredicate((e) => e == text));
    if (rect.bottom > lowest) lowest = rect.bottom;
  }
  return lowest;
}

void main() {
  group('a page', () {
    testWidgets('Home ends above the bar and the mini player', (tester) async {
      await pumpApp(tester, now: livePlaying);
      _withNavigationBar(tester);
      await _settle(tester);

      final lowest = await _lowestTextAtTheEnd(
        tester,
        find.byType(SingleChildScrollView),
      );
      final miniPlayer = MiniPlayer.heightOf(tester.element(find.byType(HomeScreen)));

      expect(lowest, lessThanOrEqualTo(_viewHeight - _bar - miniPlayer));
    });

    for (final (name, route) in [
      ('About', '/about'),
      ('Sikh history', '/history'),
      ('the Hukamnama reader', '/hukamnama'),
    ]) {
      testWidgets('$name ends above the bar', (tester) async {
        await pumpApp(tester, initialRoute: route);
        _withNavigationBar(tester);
        await _settle(tester);

        final lowest = await _lowestTextAtTheEnd(
          tester,
          find.byType(CustomScrollView),
        );

        expect(lowest, lessThanOrEqualTo(_viewHeight - _bar));
      });
    }
  });

  group('the player', () {
    Future<void> openPlayer(WidgetTester tester) async {
      await pumpApp(tester, now: livePlaying);
      // A short window, so the player scrolls: 402 x 500 points.
      tester.view.physicalSize = const Size(1206, 1500);
      _withNavigationBar(tester);
      showNowPlaying(tester.element(find.byType(HomeScreen)));
      await _settle(tester);
    }

    testWidgets('scrolls under the bar, and ends above it', (tester) async {
      await openPlayer(tester);
      final view = tester.view.physicalSize.height / 3;
      final scrollView = find.descendant(
        of: find.byType(NowPlayingScreen),
        matching: find.byType(SingleChildScrollView),
      );

      // The scroll view fills the screen, so an item slides under the bar.
      // With a SafeArea around it, it would stop short of the bar.
      expect(tester.getRect(scrollView).bottom, view);

      final lowest = await _lowestTextAtTheEnd(tester, scrollView);
      expect(lowest, lessThanOrEqualTo(view - _bar));
    });
  });

  group('a sheet', () {
    const update = AppUpdate(
      version: '3.1.0',
      build: 11,
      storeUrl: kPlayStoreUrl,
      notesEn: ['One', 'Two', 'Three'],
      notesPa: ['ਇੱਕ', 'ਦੋ', 'ਤਿੰਨ'],
    );

    /// The sheet's scroll view fills the sheet down to the screen's edge, and
    /// its last line sits above the bar.
    void expectEndsAboveTheBar(WidgetTester tester, Finder sheetText) {
      final scrollView = find.ancestor(
        of: sheetText,
        matching: find.byType(SingleChildScrollView),
      );
      expect(scrollView, findsOneWidget);
      // The sheet's own hairline border is 1 point.
      expect(tester.getRect(scrollView).bottom, closeTo(_viewHeight, 1.5));

      var lowest = 0.0;
      for (final text in find
          .descendant(of: scrollView, matching: find.byType(Text))
          .evaluate()) {
        final rect = tester.getRect(find.byElementPredicate((e) => e == text));
        if (rect.bottom > lowest) lowest = rect.bottom;
      }
      expect(lowest, lessThanOrEqualTo(_viewHeight - _bar));
    }

    testWidgets('the update offer', (tester) async {
      await pumpApp(tester, update: update);
      _withNavigationBar(tester);
      await _settle(tester);

      expectEndsAboveTheBar(tester, find.text('One'));
    });

    testWidgets('the sound quality sheet', (tester) async {
      await pumpApp(tester, now: livePlaying);
      _withNavigationBar(tester);
      showQualitySheet(tester.element(find.byType(HomeScreen)));
      await _settle(tester);

      expectEndsAboveTheBar(tester, find.text('Data saver').first);
    });

    testWidgets('a small sheet, such as what is new', (tester) async {
      await pumpApp(
        tester,
        prefs: const {'locale': 'en', 'whats_new_seen_release': '2.1'},
        whatsNew: const {
          '2.2': WhatsNew(
            release: '2.2',
            items: [
              WhatsNewItem(titleEn: 'First thing', titlePa: 'ਪਹਿਲੀ'),
              WhatsNewItem(titleEn: 'Second thing', titlePa: 'ਦੂਜੀ'),
              WhatsNewItem(titleEn: 'Third thing', titlePa: 'ਤੀਜੀ'),
            ],
          ),
        },
      );
      _withNavigationBar(tester);
      await _settle(tester);

      expectEndsAboveTheBar(tester, find.text('First thing'));
    });
  });
}
