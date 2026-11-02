import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/views/app_router.dart';
import 'package:live_darbar/src/views/screens/about_screen.dart';
import 'package:live_darbar/src/views/screens/home_screen.dart';
import 'package:live_darbar/src/views/screens/hukamnama_screen.dart';

import '../support/app_harness.dart';

/// A pushed page must show a way back that a visitor can see.
///
/// On the web the page is a column in the middle of a wide window, and the
/// stock back control sat at the window's far left edge. So on the web it
/// lines up with the column, and always names where it goes.
void main() {
  final backButton = find.byType(CupertinoNavigationBarBackButton);

  Future<void> open(WidgetTester tester, String route) async {
    Navigator.of(tester.element(find.byType(HomeScreen)))
        .pushNamed(route);
    await tester.pumpAndSettle();
  }

  final pages = [
    (AppRoutes.about, AboutScreen.maxWidth, 'About'),
    (AppRoutes.hukamnama, 620.0, 'the reader'),
  ];

  for (final (route, columnWidth, name) in pages) {
    group(name, () {
      testWidgets('on a wide window the back control sits at the column', (
        tester,
      ) async {
        await pumpApp(tester, web: true, size: desktop);
        await open(tester, route);

        expect(backButton, findsOneWidget);
        final rect = tester.getRect(backButton);
        final columnLeft = (desktop.width - columnWidth) / 2;

        expect(rect.left, inInclusiveRange(columnLeft - 16, columnLeft + 16));
        expect(rect.top, lessThan(80), reason: 'at the top of the page');
        expect(rect.height, greaterThanOrEqualTo(44), reason: 'a real target');
        expect(rect.width, greaterThan(60), reason: 'it has a label');
      });

      testWidgets('names where it goes, in English', (tester) async {
        await pumpApp(tester, web: true, size: desktop);
        await open(tester, route);

        expect(
          find.descendant(of: backButton, matching: find.text('Live Darbar')),
          findsOneWidget,
        );
      });

      testWidgets('names where it goes, in Punjabi', (tester) async {
        await pumpApp(tester, web: true, size: desktop, locale: 'pa');
        await open(tester, route);

        final l10n = await AppLocalizations.delegate.load(const Locale('pa'));
        expect(
          find.descendant(of: backButton, matching: find.text(l10n.app_title)),
          findsOneWidget,
        );
      });

      testWidgets('closes the page when tapped', (tester) async {
        await pumpApp(tester, web: true, size: desktop);
        await open(tester, route);

        await tester.tap(backButton);
        await tester.pumpAndSettle();

        expect(find.byType(HomeScreen), findsOneWidget);
        expect(backButton, findsNothing);
      });

      testWidgets('is still there when the page has scrolled', (tester) async {
        await pumpApp(tester, web: true, size: desktop);
        await open(tester, route);

        await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
        await tester.pumpAndSettle();

        expect(backButton, findsOneWidget);
        expect(tester.getRect(backButton).top, lessThan(80));
      });

      testWidgets('on a phone sized window it keeps to the margin', (
        tester,
      ) async {
        await pumpApp(tester, web: true);
        await open(tester, route);

        expect(backButton, findsOneWidget);
        expect(tester.getRect(backButton).left, inInclusiveRange(4, 24));
      });

      testWidgets('in the apps it stays at the screen edge, as on iOS', (
        tester,
      ) async {
        await pumpApp(tester, size: desktop);
        await open(tester, route);

        expect(backButton, findsOneWidget);
        expect(tester.getRect(backButton).left, lessThan(16));
      });
    });
  }

  testWidgets('home has no back control', (tester) async {
    await pumpApp(tester, web: true, size: desktop);

    expect(backButton, findsNothing);
    expect(find.byType(HukamnamaScreen), findsNothing);
  });
}
