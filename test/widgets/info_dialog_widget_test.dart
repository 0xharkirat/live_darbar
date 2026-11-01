import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/views/widgets/info_dialog_widget.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Guards the Information screen against a missing translation.
///
/// Every string on it comes from the arb files, and Punjabi is kept complete
/// by hand. A key added to English alone still compiles, so the only thing
/// that catches it is rendering both locales.
void main() {
  Future<void> pumpDialog(WidgetTester tester, String locale) async {
    await tester.pumpWidget(
      ProviderScope(
        child: ShadApp(
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const InfoDialogWidget(),
        ),
      ),
    );
    await tester.pump();
  }

  // The screen sits on a gradient that animates forever, so pumpAndSettle
  // would wait for a frame that never comes. Tab changes are done in well
  // under a second, and this is long enough for them.
  Future<void> openTab(WidgetTester tester, Finder tab) async {
    await tester.tap(tab);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  for (final locale in ['en', 'pa']) {
    testWidgets('Information screen renders every tab in $locale',
        (tester) async {
      await pumpDialog(tester, locale);

      final l10n = await AppLocalizations.delegate.load(Locale(locale));

      expect(find.text(l10n.about_section_p1), findsOneWidget);

      await openTab(tester, find.text(l10n.about_me_heading).first);
      expect(find.text(l10n.about_me_motto), findsOneWidget);
      expect(find.text(l10n.about_me_website), findsOneWidget);

      await openTab(tester, find.text(l10n.licensing_heading).first);
      expect(find.text(l10n.licensing_audio_source), findsOneWidget);
      expect(find.text(l10n.licensing_final_p), findsOneWidget);
    });
  }
}
