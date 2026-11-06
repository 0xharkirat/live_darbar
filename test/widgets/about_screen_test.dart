import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/core/app_theme.dart';
import 'package:live_darbar/src/core/app_version.dart';
import 'package:live_darbar/src/core/platform.dart';
import 'package:live_darbar/src/services/reminder_platform.dart';
import 'package:live_darbar/src/views/screens/about_screen.dart';
import 'package:live_darbar/src/views/widgets/language_switch.dart';
import 'package:live_darbar/src/views/widgets/settings_group.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../support/fake_reminder_platform.dart';

/// Stands in for the platform behind `url_launcher` and records each launch.
class _FakeLauncher extends UrlLauncherPlatform {
  final launches = <({String url, PreferredLaunchMode mode})>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launches.add((url: url, mode: options.mode));
    return true;
  }
}

/// Guards the About screen against a missing translation.
///
/// Every string on it comes from the arb files, and Punjabi is kept complete
/// by hand. A key added to English alone still compiles, so the only thing
/// that catches it is rendering both locales.
void main() {
  late UrlLauncherPlatform original;

  setUp(() => original = UrlLauncherPlatform.instance);
  tearDown(() => UrlLauncherPlatform.instance = original);

  Future<AppLocalizations> pump(
    WidgetTester tester,
    String locale, {
    bool web = false,
    Size size = const Size(1170, 2532),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appVersionProvider.overrideWith((ref) async => '2.2.0 (8)'),
          isWebProvider.overrideWithValue(web),
          // The daily reminder is tested in reminder_setting_test.dart.
          reminderPlatformProvider
              .overrideWithValue(FakeReminderPlatform(supported: false)),
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
    // Hark, 6 November: the globe sat inside the other icons in English, and
    // the whole row floated to the middle in Punjabi, whose label is shorter.
    // The test font is wider than the app's, so the switch fits beside the
    // label in some of these and drops under it in others. Both must line up.
    for (final (layout, size) in [
      ('on an iPad', const Size(2048, 2732)),
      ('on a phone', const Size(1170, 2532)),
    ]) {
      testWidgets(
          'the language row lines up with the rows under it in $locale, '
          '$layout', (tester) async {
        await pump(tester, locale, size: size);

        final globe = tester.getRect(find.byIcon(CupertinoIcons.globe).first);
        final feedback =
            tester.getRect(find.byIcon(CupertinoIcons.chat_bubble_text));
        expect(globe.left, feedback.left, reason: 'the icons share 1 edge');

        final group = tester.getRect(find.byType(SettingsGroup).first);
        final languages = tester.getRect(find.byType(LanguageSwitch));
        if (languages.top < globe.bottom) {
          expect(
            group.right - languages.right,
            lessThanOrEqualTo(16),
            reason: 'the switch sits at the right edge, where the toggles sit',
          );
        } else {
          expect(languages.left, globe.left, reason: 'it starts at the icon');
        }
      });
    }

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

  group('the link back to the site', () {
    testWidgets('is on the web, and opens darbar.live in a new tab', (
      tester,
    ) async {
      final launcher = _FakeLauncher();
      UrlLauncherPlatform.instance = launcher;
      final l10n = await pump(tester, 'en', web: true);

      await tester.tap(find.text(l10n.about_site));
      await tester.pump();

      expect(launcher.launches.map((l) => l.url), ['https://darbar.live']);
      expect(
        launcher.launches.single.mode,
        PreferredLaunchMode.externalApplication,
        reason: 'a new tab, so the kirtan keeps playing',
      );
    });

    testWidgets('is not in the apps, which have no site to go back to', (
      tester,
    ) async {
      final l10n = await pump(tester, 'en');

      expect(find.text(l10n.about_site), findsNothing);
    });

    testWidgets('reads the same in Punjabi', (tester) async {
      final l10n = await pump(tester, 'pa', web: true);

      expect(find.text(l10n.about_site), findsOneWidget);
      expect(l10n.about_site, 'darbar.live');
    });
  });
}
