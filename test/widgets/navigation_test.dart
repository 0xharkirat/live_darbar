import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/core/motion.dart';
import 'package:live_darbar/src/views/app_router.dart';
import 'package:live_darbar/src/views/screens/about_screen.dart';
import 'package:live_darbar/src/views/screens/home_screen.dart';
import 'package:live_darbar/src/views/screens/hukamnama_screen.dart';
import 'package:live_darbar/src/views/screens/now_playing_screen.dart';
import 'package:live_darbar/src/views/widgets/fade_page_route.dart';

import '../support/app_harness.dart';

NavigatorState _navigator(WidgetTester tester) =>
    Navigator.of(
      tester.element(find.byType(HomeScreen, skipOffstage: false).first),
    );

/// The route that holds [page].
ModalRoute<dynamic> _routeOf(WidgetTester tester, Type page) =>
    ModalRoute.of(tester.element(find.byType(page)))!;

/// The page's opacity, from the nearest fade above it.
double _opacity(WidgetTester tester, Type page) => tester
    .widget<FadeTransition>(
      find
          .ancestor(of: find.byType(page), matching: find.byType(FadeTransition))
          .first,
    )
    .opacity
    .value;

/// What the browser's back button sends the app: the engine posts `popRoute`
/// on the navigation channel.
Future<void> _browserBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
  await tester.pumpAndSettle();
}

/// What the app tells the browser, which the web writes after the `#`.
Future<List<String>> _record(WidgetTester tester) async {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.navigation,
    (call) async {
      if (call.method == 'routeInformationUpdated') {
        final args = call.arguments as Map<Object?, Object?>;
        calls.add((args['uri'] ?? args['location']).toString());
      } else if (call.method == 'selectSingleEntryHistory') {
        calls.add('single-entry');
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.navigation, null),
  );
  return calls;
}

void main() {
  group('on the web, a page fades', () {
    testWidgets('the route is a fade, named for the address bar', (
      tester,
    ) async {
      await pumpApp(tester, web: true);

      _navigator(tester).pushNamed(AppRoutes.hukamnama);
      await tester.pumpAndSettle();

      final route = _routeOf(tester, HukamnamaScreen);
      expect(route, isA<FadePageRoute<void>>());
      expect(route.settings.name, '/hukamnama');
      expect(route.transitionDuration, Motion.quick);
      expect(route.reverseTransitionDuration, Motion.press);
    });

    testWidgets('and does not slide in from the right', (tester) async {
      await pumpApp(tester, web: true);

      _navigator(tester).pushNamed(AppRoutes.about);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final partway = tester.getTopLeft(find.byType(AboutScreen)).dx;
      final partwayOpacity = _opacity(tester, AboutScreen);

      await tester.pumpAndSettle();

      expect(partway, 0, reason: 'no movement');
      expect(partwayOpacity, inExclusiveRange(0, 1), reason: 'still fading');
      expect(_opacity(tester, AboutScreen), 1);
      expect(find.byType(CupertinoPageTransition), findsNothing);
    });

    testWidgets('and fades out over 120 ms when it leaves', (tester) async {
      await pumpApp(tester, web: true);
      _navigator(tester).pushNamed(AppRoutes.about);
      await tester.pumpAndSettle();

      _navigator(tester).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));

      expect(find.byType(AboutScreen), findsOneWidget);
      expect(_opacity(tester, AboutScreen), inExclusiveRange(0, 1));

      await tester.pump(const Duration(milliseconds: 120));
      await tester.pump();
      expect(find.byType(AboutScreen), findsNothing);
    });

    testWidgets('and with Reduce Motion the fade is still a real fade', (
      tester,
    ) async {
      reduceMotion(tester);
      await pumpApp(tester, web: true);

      _navigator(tester).pushNamed(AppRoutes.about);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      expect(tester.getTopLeft(find.byType(AboutScreen)).dx, 0);
      expect(_opacity(tester, AboutScreen), inExclusiveRange(0, 1));
    });
  });

  group('on iOS and Android, a page slides', () {
    testWidgets('the route is the Cupertino page, with its swipe back', (
      tester,
    ) async {
      await pumpApp(tester);

      _navigator(tester).pushNamed(AppRoutes.hukamnama);
      await tester.pumpAndSettle();

      final route = _routeOf(tester, HukamnamaScreen);
      expect(route, isA<CupertinoPageRoute<void>>());
      expect(route.settings.name, '/hukamnama');
    });

    testWidgets('in from the right', (tester) async {
      await pumpApp(tester);

      _navigator(tester).pushNamed(AppRoutes.about);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final partway = tester.getTopLeft(find.byType(AboutScreen)).dx;

      await tester.pumpAndSettle();

      expect(partway, greaterThan(0));
      expect(tester.getTopLeft(find.byType(AboutScreen)).dx, 0);
    });
  });

  group('the address bar', () {
    testWidgets('follows the page, and the page back', (tester) async {
      final calls = await _record(tester);
      await pumpApp(tester, web: true);
      expect(calls, contains('single-entry'));

      _navigator(tester).pushNamed(AppRoutes.hukamnama);
      await tester.pumpAndSettle();
      expect(calls.last, '/hukamnama');

      await _browserBack(tester);
      expect(calls.last, '/');
    });

    testWidgets('returns to home when the reader opened from the player closes', (
      tester,
    ) async {
      final calls = await _record(tester);
      await pumpApp(tester, web: true, now: recordingPlaying);
      showNowPlaying(tester.element(find.byType(HomeScreen)));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Read'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(HukamnamaScreen), findsOneWidget);
      expect(calls.last, '/hukamnama');

      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/navigation',
        const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
        (_) {},
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(HukamnamaScreen), findsNothing);
      expect(find.byType(NowPlayingScreen), findsOneWidget);
      expect(calls.last, '/', reason: 'the player sits on home');
    });
  });

  group('a link to a page', () {
    testWidgets('opens it over home, so back has somewhere to go', (
      tester,
    ) async {
      await pumpApp(tester, web: true, initialRoute: AppRoutes.hukamnama);

      expect(find.byType(HukamnamaScreen), findsOneWidget);
      expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);

      await _browserBack(tester);

      expect(find.byType(HukamnamaScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('to /app/ itself opens home alone', (tester) async {
      await pumpApp(tester, web: true);

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(_navigator(tester).canPop(), isFalse);
    });

    testWidgets('to a page that does not exist opens home alone', (
      tester,
    ) async {
      await pumpApp(tester, web: true, initialRoute: '/nowhere');

      // Flutter says so, once, and carries on with home.
      expect(
        tester.takeException().toString(),
        contains('Could not navigate to initial route'),
      );
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(_navigator(tester).canPop(), isFalse);
    });
  });

  group('the browser back button', () {
    testWidgets('closes the page and stays in the app', (tester) async {
      await pumpApp(tester, web: true);
      _navigator(tester).pushNamed(AppRoutes.about);
      await tester.pumpAndSettle();
      expect(find.byType(AboutScreen), findsOneWidget);

      await _browserBack(tester);

      expect(find.byType(AboutScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('twice: reader, back, About, back', (tester) async {
      await pumpApp(tester, web: true);

      _navigator(tester).pushNamed(AppRoutes.hukamnama);
      await tester.pumpAndSettle();
      await _browserBack(tester);
      expect(find.byType(HukamnamaScreen), findsNothing);

      _navigator(tester).pushNamed(AppRoutes.about);
      await tester.pumpAndSettle();
      await _browserBack(tester);

      expect(find.byType(AboutScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });
}
