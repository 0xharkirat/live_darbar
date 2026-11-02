import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/home_screen_widget/widget_actions.dart';
import 'package:live_darbar/src/views/screens/hukamnama_screen.dart';

Route<void> readerRoute() => MaterialPageRoute<void>(
      settings: const RouteSettings(name: HukamnamaScreen.routeName),
      builder: (_) => const Scaffold(body: Text('reader')),
    );

void main() {
  final navigatorKey = GlobalKey<NavigatorState>();

  Future<void> pumpApp(WidgetTester tester) => tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(body: Text('home')),
        ),
      );

  testWidgets('opens the reader on top of the home screen', (tester) async {
    await pumpApp(tester);

    openHukamnamaReader(navigatorKey.currentState, route: readerRoute);
    await tester.pumpAndSettle();

    expect(find.text('reader'), findsOneWidget);
  });

  testWidgets('a second tap does not stack a second reader', (tester) async {
    await pumpApp(tester);

    openHukamnamaReader(navigatorKey.currentState, route: readerRoute);
    await tester.pumpAndSettle();
    openHukamnamaReader(navigatorKey.currentState, route: readerRoute);
    await tester.pumpAndSettle();

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    // One pop is enough to get back home.
    expect(find.text('home'), findsOneWidget);
    expect(find.text('reader'), findsNothing);
  });

  testWidgets('opens the reader again when another screen is on top',
      (tester) async {
    await pumpApp(tester);
    openHukamnamaReader(navigatorKey.currentState, route: readerRoute);
    await tester.pumpAndSettle();
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/about'),
        builder: (_) => const Scaffold(body: Text('about')),
      ),
    );
    await tester.pumpAndSettle();

    openHukamnamaReader(navigatorKey.currentState, route: readerRoute);
    await tester.pumpAndSettle();

    expect(find.text('reader'), findsOneWidget);
    expect(find.text('about'), findsNothing);
  });

  test('says "not ready" while there is no navigator, so native retries', () {
    expect(
      () => openHukamnamaReader(null),
      throwsA(
        isA<PlatformException>().having((e) => e.code, 'code', 'not_ready'),
      ),
    );
  });

  test('the reader route carries the name that the check looks for', () {
    expect(HukamnamaScreen.route().settings.name, HukamnamaScreen.routeName);
  });
}
