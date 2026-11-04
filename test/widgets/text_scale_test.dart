import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/core/text_scale.dart';
import 'package:live_darbar/src/models/sgpc_day.dart';
import 'package:live_darbar/src/models/sikh_date.dart';
import 'package:live_darbar/src/views/app_router.dart';
import 'package:live_darbar/src/views/screens/about_screen.dart';
import 'package:live_darbar/src/views/screens/home_screen.dart';
import 'package:live_darbar/src/views/screens/hukamnama_screen.dart';
import 'package:live_darbar/src/views/screens/now_playing_screen.dart';
import 'package:live_darbar/src/views/widgets/language_switch.dart';
import 'package:live_darbar/src/views/widgets/live_badge.dart';

import '../support/app_harness.dart';
import '../support/load_fonts.dart';

/// What Android's largest font setting gives, and the most that iOS gives
/// before its accessibility sizes (which go on to 3.1).
const _beyondTheLimit = 3.0;

/// The text size the screen reader user chose, as the phone reports it.
void _phoneTextScale(WidgetTester tester, double scale) {
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// How big 10 points of text come out, where [find] is.
double _tenPointsAt(WidgetTester tester, Finder find) =>
    MediaQuery.textScalerOf(tester.element(find.first)).scale(10);

void main() {
  // The real fonts, because the question is whether text fits on a phone.
  // The test font draws every glyph about 1.7 times as wide as Geist.
  setUpAll(loadAppFonts);

  test('the limit is 2x, which is where Android stops', () {
    expect(kMaxTextScale, 2.0);
  });

  for (final locale in ['en', 'pa']) {
    group('at the largest text size, in $locale', () {
      testWidgets('Home has no overflow', (tester) async {
        _phoneTextScale(tester, kMaxTextScale);

        await pumpApp(tester, locale: locale);

        expect(tester.takeException(), isNull, reason: 'no overflow');
      });

      testWidgets('Home has no overflow with the player up', (tester) async {
        _phoneTextScale(tester, kMaxTextScale);

        await pumpApp(tester, locale: locale, now: livePlaying);

        expect(tester.takeException(), isNull, reason: 'no overflow');
      });

      for (final (name, now) in [
        ('live', livePlaying),
        ('a recording', recordingPlaying),
      ]) {
        testWidgets('the player has no overflow, $name', (tester) async {
          _phoneTextScale(tester, _beyondTheLimit);

          await pumpApp(tester, locale: locale, now: now);
          unawaited(showNowPlaying(tester.element(find.byType(HomeScreen))));
          // The equalizer loops while sound plays, so the tree never settles.
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));

          expect(find.byType(NowPlayingScreen), findsOneWidget);
          expect(tester.takeException(), isNull, reason: 'no overflow');
        });
      }

      testWidgets('the Hukamnama reader has no overflow', (tester) async {
        _phoneTextScale(tester, _beyondTheLimit);

        await pumpApp(tester,
            locale: locale, initialRoute: AppRoutes.hukamnama);
        await tester.pumpAndSettle();

        expect(find.byType(HukamnamaScreen), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'no overflow');
      });

      testWidgets('About has no overflow', (tester) async {
        _phoneTextScale(tester, _beyondTheLimit);

        await pumpApp(tester, locale: locale, initialRoute: AppRoutes.about);
        await tester.pumpAndSettle();

        expect(find.byType(AboutScreen), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'no overflow');
      });
    });
  }

  group('the language switch on Home', () {
    final nov3 = DateTime.utc(2026, 11, 3, 6);

    Future<void> pumpDated(WidgetTester tester, String locale) => pumpApp(
          tester,
          locale: locale,
          clock: nov3,
          sikh: SikhDate(
            day: 18,
            monthIndex: 7,
            year: 558,
            gregorian: sgpcDayOf(nov3),
          ),
        );

    /// Whether the dates were cut short. The top line is the Sikh date and the
    /// next is the everyday date.
    bool cut(WidgetTester tester, String text) => tester
        .renderObject<RenderParagraph>(find.text(text))
        .didExceedMaxLines;

    testWidgets('sits beside the dates at the default size', (tester) async {
      await pumpDated(tester, 'en');

      final date = find.text('TUESDAY, 3 NOVEMBER');
      final switchTop = tester.getTopLeft(find.byType(LanguageSwitch)).dy;

      expect(tester.getTopLeft(find.byType(LanguageSwitch)).dx,
          greaterThan(tester.getTopRight(date).dx));
      expect(switchTop, lessThan(tester.getBottomLeft(date).dy));
    });

    testWidgets('drops under the dates at the largest size, and they read '
        'whole', (tester) async {
      _phoneTextScale(tester, kMaxTextScale);

      await pumpDated(tester, 'en');

      final date = find.text('TUESDAY, 3 NOVEMBER');
      expect(
        tester.getTopLeft(find.byType(LanguageSwitch)).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(date).dy),
      );
      expect(cut(tester, 'TUESDAY, 3 NOVEMBER'), isFalse);
      expect(cut(tester, '18 KATAK 558'), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not move live kirtan when the language changes', (
      tester,
    ) async {
      _phoneTextScale(tester, kMaxTextScale);
      await pumpDated(tester, 'en');
      final english = tester.getTopLeft(find.text('Live Darbar')).dy;

      await tester.tap(find.text('ਪੰਜਾਬੀ'));
      await tester.pump(const Duration(milliseconds: 400));
      final punjabi = tester.getTopLeft(find.text('Live Darbar')).dy;

      // Punjabi lines are taller than English ones, so the title may sit a
      // little lower. A switch that jumps from beside to below would move it
      // by the height of a whole row.
      expect((punjabi - english).abs(), lessThan(24));
    });
  });

  group('the live hero', () {
    for (final locale in ['en', 'pa']) {
      testWidgets('keeps its words off the LIVE badge at 2x, in $locale', (
        tester,
      ) async {
        _phoneTextScale(tester, kMaxTextScale);
        await pumpApp(tester, locale: locale);
        final l10n = lookupAppLocalizations(Locale(locale));

        final badge = find.byType(LiveBadge).first;
        // Words on a painting stop at 1.3x, so the title stays on 1 line.
        final title = find.text(l10n.live_kirtan).first;
        expect(
          tester.getTopLeft(title).dy,
          greaterThanOrEqualTo(tester.getBottomLeft(badge).dy),
          reason: 'the title clears the badge',
        );
        expect(
          MediaQuery.textScalerOf(tester.element(title)).scale(10),
          closeTo(10 * kPaintingTextScale, 0.01),
        );
      });
    }
  });

  group('the limit', () {
    testWidgets('holds text above 2x at 2x', (tester) async {
      _phoneTextScale(tester, _beyondTheLimit);

      await pumpApp(tester);

      expect(_tenPointsAt(tester, find.byType(HomeScreen)), 20);
    });

    testWidgets('leaves a smaller size as the listener set it', (tester) async {
      _phoneTextScale(tester, 1.3);

      await pumpApp(tester);

      expect(_tenPointsAt(tester, find.byType(HomeScreen)), closeTo(13, 0.01));
    });

    testWidgets('does not shrink text below the default', (tester) async {
      _phoneTextScale(tester, 0.8);

      await pumpApp(tester);

      // A listener who chose smaller text keeps it. The limit is a ceiling.
      expect(_tenPointsAt(tester, find.byType(HomeScreen)), closeTo(8, 0.01));
    });

    testWidgets('reaches a page that Home pushed', (tester) async {
      _phoneTextScale(tester, _beyondTheLimit);

      await pumpApp(tester, initialRoute: AppRoutes.about);
      await tester.pumpAndSettle();

      expect(_tenPointsAt(tester, find.byType(AboutScreen)), 20);
    });
  });
}
