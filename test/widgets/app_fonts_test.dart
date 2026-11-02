import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/views/app_router.dart';
import 'package:live_darbar/src/views/screens/home_screen.dart';

import '../support/app_harness.dart';

/// The web renders any text whose font is not bundled in Roboto, which it
/// downloads from fonts.gstatic.com. Only the app's own faces, and the two
/// icon fonts, may appear on a screen.
///
/// The one place Roboto showed was the back label of the navigation bar:
/// Cupertino styles it `CupertinoSystemText`, the system font, which resolves
/// to nothing off Apple devices. [AppTheme] now sets the Cupertino styles in
/// Geist, and this test fails if any other face comes back.
const _allowed = {
  'Geist',
  'GeistSerif',
  'NotoSansGurmukhi',
  'TiroGurmukhi',
  'packages/cupertino_icons/CupertinoIcons',
  'MaterialIcons',
};

/// Every run of text on screen, with the family it is set in.
Map<String, String?> _fonts(WidgetTester tester) {
  final found = <String, String?>{};
  void visit(InlineSpan span, String? inherited) {
    final family = span.style?.fontFamily ?? inherited;
    if (span is TextSpan) {
      final text = span.text;
      if (text != null && text.trim().isNotEmpty) found[text] = family;
    }
    span.visitDirectChildren((child) {
      visit(child, family);
      return true;
    });
  }

  for (final paragraph
      in tester.renderObjectList<RenderParagraph>(find.byType(RichText))) {
    visit(paragraph.text, null);
  }
  return found;
}

void main() {
  Future<void> open(WidgetTester tester, String route) async {
    Navigator.of(tester.element(find.byType(HomeScreen))).pushNamed(route);
    await tester.pumpAndSettle();
  }

  void expectOnlyAppFonts(WidgetTester tester) {
    final stray = {
      for (final entry in _fonts(tester).entries)
        if (!_allowed.contains(entry.value)) entry.key: entry.value,
    };
    expect(stray, isEmpty, reason: 'text outside the bundled fonts');
  }

  test('the app declares a Roboto, so CanvasKit does not download one', () {
    // CanvasKit fetches Roboto from fonts.gstatic.com on every load unless
    // the font manifest already has a family by that name.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final roboto = RegExp(r'- family: Roboto\n\s+fonts:\n\s+- asset: (\S+)')
        .firstMatch(pubspec);

    expect(roboto, isNotNull);
    expect(File(roboto!.group(1)!).existsSync(), isTrue);
  });

  for (final locale in ['en', 'pa']) {
    testWidgets('home is set in the bundled fonts, $locale', (tester) async {
      await pumpApp(tester, locale: locale);

      expectOnlyAppFonts(tester);
    });

    testWidgets('the reader, back label included, $locale', (tester) async {
      await pumpApp(tester, locale: locale);
      await open(tester, AppRoutes.hukamnama);

      expect(find.byType(CupertinoNavigationBarBackButton), findsOneWidget);
      expectOnlyAppFonts(tester);
    });

    testWidgets('About, back label included, $locale', (tester) async {
      await pumpApp(tester, locale: locale);
      await open(tester, AppRoutes.about);

      expect(find.byType(CupertinoNavigationBarBackButton), findsOneWidget);
      expectOnlyAppFonts(tester);
    });
  }
}
