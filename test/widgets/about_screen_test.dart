import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/core/app_theme.dart';
import 'package:live_darbar/src/core/app_version.dart';
import 'package:live_darbar/src/views/screens/about_screen.dart';

/// Guards the About screen against a missing translation.
///
/// Every string on it comes from the arb files, and Punjabi is kept complete
/// by hand. A key added to English alone still compiles, so the only thing
/// that catches it is rendering both locales.
void main() {
  Future<AppLocalizations> pump(WidgetTester tester, String locale) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appVersionProvider.overrideWith((ref) async => '2.2.0 (8)'),
        ],
        child: MaterialApp(
          theme: AppTheme.material,
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AboutScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.delegate.load(Locale(locale));
  }

  for (final locale in ['en', 'pa']) {
    testWidgets('About renders every section in $locale', (tester) async {
      final l10n = await pump(tester, locale);

      expect(find.text(l10n.about_section_p1), findsOneWidget);
      expect(find.text(l10n.privacy_policy), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text(l10n.about_me_website),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(l10n.about_me_heading), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text(l10n.licensing_final_p),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(l10n.licensing_audio_source), findsOneWidget);
      expect(find.text(l10n.licensing_images_source), findsOneWidget);
    });
  }
}
