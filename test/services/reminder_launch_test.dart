import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/services/reminder_launch.dart';
import 'package:live_darbar/src/views/screens/hukamnama_screen.dart';

Route<void> readerRoute() => MaterialPageRoute<void>(
      settings: const RouteSettings(name: HukamnamaScreen.routeName),
      builder: (_) => const Scaffold(body: Text('reader')),
    );

/// A tap on the reminder opens the Hukamnama reader, also when it started the
/// app from closed and the app has no navigator for the first moments.
void main() {
  final navigatorKey = GlobalKey<NavigatorState>();

  Future<void> pumpApp(WidgetTester tester) => tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(body: Text('home')),
        ),
      );

  testWidgets('opens the reader when the app is running', (tester) async {
    await pumpApp(tester);

    await openReaderFromReminder(
      () => navigatorKey.currentState,
      route: readerRoute,
    );
    await tester.pumpAndSettle();

    expect(find.text('reader'), findsOneWidget);
  });

  testWidgets('waits for a cold start to build its navigator', (tester) async {
    NavigatorState? navigator;
    var asked = 0;
    final opened = openReaderFromReminder(
      () {
        asked++;
        return navigator;
      },
      route: readerRoute,
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(asked, greaterThan(1), reason: 'it tries again while waiting');

    await pumpApp(tester);
    navigator = navigatorKey.currentState;
    await tester.pump(const Duration(milliseconds: 300));
    await opened;
    await tester.pumpAndSettle();

    expect(find.text('reader'), findsOneWidget);
  });

  testWidgets('gives up after its tries instead of waiting for ever', (
    tester,
  ) async {
    var asked = 0;
    final done = openReaderFromReminder(
      () {
        asked++;
        return null;
      },
      tries: 4,
      every: const Duration(milliseconds: 100),
      route: readerRoute,
    );

    await tester.pump(const Duration(seconds: 1));
    await done;

    expect(asked, 4);
  });

  testWidgets('a tap while the reader is open does not stack a second', (
    tester,
  ) async {
    await pumpApp(tester);

    await openReaderFromReminder(
      () => navigatorKey.currentState,
      route: readerRoute,
    );
    await tester.pumpAndSettle();
    await openReaderFromReminder(
      () => navigatorKey.currentState,
      route: readerRoute,
    );
    await tester.pumpAndSettle();

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(find.text('reader'), findsNothing);
  });
}
