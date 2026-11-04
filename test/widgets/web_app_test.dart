import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/core/store_links.dart';
import 'package:live_darbar/src/models/app_update.dart';
import 'package:live_darbar/src/views/screens/about_screen.dart';
import 'package:live_darbar/src/views/widgets/fade_page_route.dart';

import '../support/app_harness.dart';

/// The web app lives at `/app/`, in a browser. A browser has tabs, a mouse and
/// a link preview, and pages that change with a fade, not a phone's slide.
/// (The fade has its own tests in navigation_test.dart.)

/// The titles the app sends to the browser tab, in order. `Title` sends them
/// through the platform channel, and on the web the engine sets the tab.
List<String> _tabTitles(WidgetTester tester) {
  final titles = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'SystemChrome.setApplicationSwitcherDescription') {
        titles.add((call.arguments as Map)['label'] as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return titles;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

NavigatorState _navigator(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator).first);

/// Runs [body] as a browser or phone of [platform], and puts it back before the
/// test ends, which the binding checks.
Future<void> _as(TargetPlatform platform, Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  group('the tab title', () {
    for (final (locale, route, title) in [
      ('en', '/', 'Live Darbar'),
      ('en', '/hukamnama', 'Hukamnama · Live Darbar'),
      ('en', '/about', 'About this app · Live Darbar'),
      ('en', '/history', 'Sikh history · Live Darbar'),
      ('pa', '/', 'ਲਾਈਵ ਦਰਬਾਰ'),
      ('pa', '/hukamnama', 'ਹੁਕਮਨਾਮਾ · ਲਾਈਵ ਦਰਬਾਰ'),
      ('pa', '/about', 'ਇਸ ਐਪ ਬਾਰੇ · ਲਾਈਵ ਦਰਬਾਰ'),
      ('pa', '/history', 'ਸਿੱਖ ਇਤਿਹਾਸ · ਲਾਈਵ ਦਰਬਾਰ'),
    ]) {
      testWidgets('names the page: $route in $locale', (tester) async {
        final titles = _tabTitles(tester);
        await pumpApp(tester, web: true, locale: locale, initialRoute: route);
        await _settle(tester);

        expect(titles.last, title);
      });
    }

    testWidgets('goes back to the page below when a page closes', (
      tester,
    ) async {
      final titles = _tabTitles(tester);
      await pumpApp(tester, web: true, initialRoute: '/about');
      await _settle(tester);
      expect(titles.last, 'About this app · Live Darbar');

      _navigator(tester).pop();
      await _settle(tester);

      expect(titles.last, 'Live Darbar');
    });

    testWidgets('follows a page that opens from the page', (tester) async {
      final titles = _tabTitles(tester);
      await pumpApp(tester, web: true);
      await _settle(tester);

      unawaited(_navigator(tester).pushNamed('/hukamnama'));
      await _settle(tester);
      expect(titles.last, 'Hukamnama · Live Darbar');

      unawaited(_navigator(tester).pushNamed('/about'));
      await _settle(tester);
      expect(titles.last, 'About this app · Live Darbar');

      _navigator(tester).pop();
      await _settle(tester);
      expect(titles.last, 'Hukamnama · Live Darbar');
    });

    testWidgets('a sheet does not rename the tab', (tester) async {
      final titles = _tabTitles(tester);
      await pumpApp(
        tester,
        web: true,
        initialRoute: '/about',
        update: const AppUpdate(
          version: '3.1.0',
          build: 11,
          storeUrl: kPlayStoreUrl,
          notesEn: ['A new release.'],
          notesPa: [],
        ),
      );
      await _settle(tester);

      expect(find.text('A new release.'), findsOneWidget, reason: 'sheet open');
      expect(titles.last, 'About this app · Live Darbar');
    });

    testWidgets('and with the language: the tab follows the switch', (
      tester,
    ) async {
      final titles = _tabTitles(tester);
      await pumpApp(tester, web: true, locale: 'pa', initialRoute: '/about');
      await _settle(tester);

      expect(titles.last, 'ਇਸ ਐਪ ਬਾਰੇ · ਲਾਈਵ ਦਰਬਾਰ');
    });

    testWidgets('does nothing in a phone app, which has no tab', (
      tester,
    ) async {
      await pumpApp(tester, initialRoute: '/about');
      await _settle(tester);

      expect(
        find.descendant(
          of: find.byType(Navigator).first,
          matching: find.byType(Title),
        ),
        findsNothing,
      );
    });
  });

  group('scrollbars', () {
    for (final platform in [
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
    ]) {
      for (final route in ['/', '/about', '/history', '/hukamnama']) {
        testWidgets('every vertical list has one: $route, as $platform', (
          tester,
        ) async {
          await _as(platform, () async {
            await pumpApp(
              tester,
              web: true,
              initialRoute: route,
              size: desktop,
            );
            await _settle(tester);

            final lists = find.byType(Scrollable).evaluate().where((e) {
              final s = e.widget as Scrollable;
              return axisDirectionToAxis(s.axisDirection) == Axis.vertical;
            }).length;
            expect(lists, greaterThan(0));
            expect(find.byType(Scrollbar), findsNWidgets(lists));
          });
        });
      }
    }

    testWidgets('a phone app is as it was: none on Android', (tester) async {
      await _as(TargetPlatform.android, () async {
        await pumpApp(tester, initialRoute: '/about');
        await _settle(tester);

        expect(find.byType(Scrollbar), findsNothing);
      });
    });

    testWidgets('the scrollbar is the real one, and follows the list', (
      tester,
    ) async {
      await _as(TargetPlatform.android, () async {
        await pumpApp(
          tester,
          web: true,
          initialRoute: '/hukamnama',
          size: desktop,
        );
        await _settle(tester);

        final scrollbar =
            tester.widget<Scrollbar>(find.byType(Scrollbar).first);
        expect(scrollbar.controller, isNotNull);
      });
    });
  });

  group('page changes', () {
    testWidgets('the web fades a page in, and has no slide', (tester) async {
      await pumpApp(tester, web: true);
      await _settle(tester);

      unawaited(_navigator(tester).pushNamed('/about'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        ModalRoute.of(tester.element(find.byType(AboutScreen))),
        isA<FadePageRoute<void>>(),
      );
    });
  });

  group('the link preview card', () {
    final html = File('web/index.html').readAsStringSync();

    String? meta(String attribute, String name) {
      final match = RegExp(
        '<meta\\s+(?:[^>]*?)$attribute="$name"(?:[^>]*?)content="([^"]*)"',
      ).firstMatch(html);
      return match?.group(1);
    }

    String? property(String name) => meta('property', name);
    String? named(String name) => meta('name', name);

    test('is an Open Graph card for the app', () {
      expect(property('og:type'), 'website');
      expect(property('og:site_name'), 'Live Darbar');
      expect(property('og:title'), isNotEmpty);
      expect(property('og:description'), isNotEmpty);
      expect(property('og:url'), 'https://darbar.live/app/');
    });

    test('has an image the preview can fetch: absolute, https, with a size', () {
      expect(property('og:image'), startsWith('https://darbar.live/'));
      expect(property('og:image:width'), '1200');
      expect(property('og:image:height'), '630');
      expect(property('og:image:alt'), isNotEmpty);
    });

    test('shows the same painting as the landing page', () {
      final landing = File('site/index.html').readAsStringSync();
      expect(landing, contains(property('og:image')!));
    });

    test('is a large image card for X and the others that read twitter:', () {
      expect(named('twitter:card'), 'summary_large_image');
      expect(named('twitter:title'), property('og:title'));
      expect(named('twitter:description'), property('og:description'));
      expect(named('twitter:image'), property('og:image'));
    });

    test('keeps titles and descriptions short enough not to be cut', () {
      expect(property('og:title')!.length, lessThanOrEqualTo(60));
      expect(property('og:description')!.length, lessThanOrEqualTo(160));
    });

    test('names the page, for a crawler that reads only the address', () {
      expect(html, contains('<link rel="canonical" href="https://darbar.live/app/">'));
    });
  });
}
