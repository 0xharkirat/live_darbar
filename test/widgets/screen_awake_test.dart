import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/services/screen_awake.dart';
import 'package:live_darbar/src/views/app_router.dart';
import 'package:live_darbar/src/views/screens/home_screen.dart';
import 'package:live_darbar/src/views/screens/hukamnama_screen.dart';

import '../support/app_harness.dart';
import '../support/fake_screen_awake.dart';

NavigatorState _navigator(WidgetTester tester) => Navigator.of(
      tester.element(find.byType(HomeScreen, skipOffstage: false).first),
    );

/// What the operating system sends when the app goes behind another one.
Future<void> _toBackground(WidgetTester tester) async {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await tester.pump();
}

Future<void> _toFront(WidgetTester tester) async {
  for (final state in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await tester.pump();
}

/// The screen timeout, kept off wherever the listener does not need it. The
/// phone locks itself for privacy and for battery, so only the reader, which
/// is read slowly with no touch, holds the screen on.
void main() {
  late FakeScreenAwake awake;

  setUp(() => awake = FakeScreenAwake());

  Future<void> pump(
    WidgetTester tester, {
    String initialRoute = AppRoutes.home,
  }) =>
      pumpApp(tester, screenAwake: awake, initialRoute: initialRoute);

  testWidgets('Home lets the screen lock', (tester) async {
    await pump(tester);

    expect(awake.on, isFalse);
    expect(awake.calls, isEmpty, reason: 'it never asked');
  });

  testWidgets('About lets the screen lock', (tester) async {
    await pump(tester, initialRoute: AppRoutes.about);
    await tester.pumpAndSettle();

    expect(awake.on, isFalse);
  });

  testWidgets('the Sikh history screen lets the screen lock', (tester) async {
    await pump(tester, initialRoute: AppRoutes.history);
    await tester.pumpAndSettle();

    expect(awake.on, isFalse);
  });

  testWidgets('the reader holds the screen on', (tester) async {
    await pump(tester);

    _navigator(tester).pushNamed(AppRoutes.hukamnama);
    await tester.pumpAndSettle();

    expect(find.byType(HukamnamaScreen), findsOneWidget);
    expect(awake.on, isTrue);
  });

  testWidgets('the reader releases it when the listener leaves', (
    tester,
  ) async {
    await pump(tester);
    _navigator(tester).pushNamed(AppRoutes.hukamnama);
    await tester.pumpAndSettle();

    _navigator(tester).pop();
    await tester.pumpAndSettle();

    expect(find.byType(HukamnamaScreen), findsNothing);
    expect(awake.on, isFalse);
  });

  testWidgets('the reader releases it when the back button closes it', (
    tester,
  ) async {
    await pump(tester);
    _navigator(tester).pushNamed(AppRoutes.hukamnama);
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(awake.on, isFalse);
  });

  testWidgets('the reader releases it when the app goes to the background, '
      'and holds it again on the way back', (tester) async {
    await pump(tester);
    _navigator(tester).pushNamed(AppRoutes.hukamnama);
    await tester.pumpAndSettle();

    await _toBackground(tester);
    expect(awake.on, isFalse, reason: 'behind another app');

    await _toFront(tester);
    expect(awake.on, isTrue, reason: 'back in the reader');
  });

  testWidgets('a reader closed in the background stays released when the app '
      'returns', (tester) async {
    await pump(tester);
    _navigator(tester).pushNamed(AppRoutes.hukamnama);
    await tester.pumpAndSettle();
    await _toBackground(tester);

    // Something closes the reader while the app is behind (a link from the
    // home screen widget). No frame runs until the app is back in front.
    _navigator(tester).pop();
    await _toFront(tester);
    await tester.pumpAndSettle();

    expect(find.byType(HukamnamaScreen), findsNothing);
    expect(awake.on, isFalse);
  });

  testWidgets('a reader opened from the reminder at launch holds the screen', (
    tester,
  ) async {
    await pump(tester, initialRoute: AppRoutes.hukamnama);
    await tester.pumpAndSettle();

    expect(awake.on, isTrue);
  });

  group('ScreenAwake', () {
    test('holds the screen until every holder has let go', () async {
      final fake = FakeScreenAwake();
      final screen = ScreenAwake(fake.toggle);

      screen.hold();
      screen.hold();
      screen.release();
      expect(fake.on, isTrue, reason: 'one reader is still open');

      screen.release();
      expect(fake.on, isFalse);
    });

    test('asks the phone once for each change, not for each holder', () async {
      final fake = FakeScreenAwake();
      final screen = ScreenAwake(fake.toggle);

      screen.hold();
      screen.hold();
      screen.release();
      screen.release();

      expect(fake.calls, [true, false]);
    });

    test('never goes below none', () async {
      final fake = FakeScreenAwake();
      final screen = ScreenAwake(fake.toggle);

      screen.release();
      screen.hold();

      expect(fake.on, isTrue);
    });

    test('a phone that cannot hold the screen does not stop the reader', () {
      final screen = ScreenAwake((_) async => throw StateError('no plugin'));

      expect(screen.hold, returnsNormally);
      expect(screen.release, returnsNormally);
    });
  });
}
