import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:live_darbar/src/controllers/now_playing_controller.dart';
import 'package:live_darbar/src/controllers/sikh_date_controller.dart';
import 'package:live_darbar/src/core/app_theme.dart';
import 'package:live_darbar/src/models/live_playback_state.dart';
import 'package:live_darbar/src/models/sikh_date.dart';
import 'package:live_darbar/src/views/app_router.dart';
import 'package:live_darbar/src/views/screens/hukamnama_screen.dart';
import 'package:live_darbar/src/views/widgets/sangrand_row.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hark, 7 November: "we will show ... sangrand hukumnama as well". The month's
/// pauri of Barah Maha, on its own page, with a row on Home that leads there.
void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  /// 22 Katak 558, 7 November 2026.
  SikhDate katak({int day = 22}) => SikhDate(
        day: day,
        monthIndex: 7,
        year: 558,
        gregorian: DateTime.utc(2026, 11, day == 1 ? 17 : 7),
      );

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    SikhDate? date,
    Map<String, Object> saved = const {},
  }) async {
    SharedPreferences.setMockInitialValues({'locale': 'en', ...saved});
    tester.view.physicalSize = const Size(1206, 6000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sikhDateProvider.overrideWith((ref) async => date ?? katak()),
          // Nothing has played: the page's floating player stays hidden, and
          // no audio player starts.
          nowPlayingProvider.overrideWithValue(
            const NowPlaying(
              index: kLiveIndex,
              action: PlayAction.play,
              started: false,
              live: LivePlaybackState(),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.material,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          onGenerateRoute: AppRoutes.generator(web: false),
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('the page', () {
    testWidgets('shows the month\'s pauri, under the title of Barah Maha', (
      tester,
    ) async {
      await pump(tester, const SangrandScreen());
      // The large title, and the small one the bar shows on scroll.
      expect(find.text(en.sangrand_title), findsWidgets);
      expect(find.text('${en.barah_maha} · Katak · ${en.hukamnama_ang('135')}'),
          findsOneWidget);
      expect(find.text('ਬਾਰਹ ਮਾਹਾ ਮਾਂਝ ਮਹਲਾ ੫ ਘਰੁ ੪ ॥'), findsOneWidget);
      expect(find.text('ੴ ਸਤਿਗੁਰ ਪ੍ਰਸਾਦਿ ॥'), findsOneWidget);
      expect(find.text('ਕਤਿਕਿ ਕਰਮ ਕਮਾਵਣੇ ਦੋਸੁ ਨ ਕਾਹੂ ਜੋਗੁ ॥'), findsOneWidget);
      expect(
        find.text(
            'In the month of Katak, do good deeds. Do not try to blame anyone else.'),
        findsOneWidget,
      );
    });

    testWidgets('follows the meaning switches of the reader', (tester) async {
      await pump(
        tester,
        const SangrandScreen(),
        saved: {'reader_meaning_english': false},
      );
      expect(find.textContaining('In the month of Katak'), findsNothing);
      expect(find.textContaining('ਕੱਤਕ (ਦੀ ਸੁਹਾਵਣੀ ਰੁੱਤ)'), findsOneWidget);
    });

    testWidgets('has the reading options', (tester) async {
      await pump(tester, const SangrandScreen());
      expect(find.byKey(const ValueKey('reader-options')), findsOneWidget);
    });
  });

  group('the row on Home', () {
    Widget row() => const Scaffold(body: Center(child: SangrandRow()));

    testWidgets('names the month and its first line', (tester) async {
      await pump(tester, row());
      expect(
        find.textContaining(en.sangrand_row('Katak').toUpperCase(),
            findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('ਕਤਿਕਿ ਕਰਮ ਕਮਾਵਣੇ', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('says so on Sangrand day itself', (tester) async {
      await pump(tester, row(), date: katak(day: 1));
      expect(
        find.textContaining(en.sangrand_row_today('Katak').toUpperCase(),
            findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('opens the page', (tester) async {
      await pump(tester, row());
      await tester.tap(find.byType(SangrandRow));
      await tester.pumpAndSettle();
      expect(find.byType(SangrandScreen), findsOneWidget);
    });

    testWidgets('is not there before the Sikh date is known', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sikhDateProvider.overrideWith((ref) async => null)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: SangrandRow()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('ਕਤਿਕਿ', findRichText: true), findsNothing);
    });
  });

  test('the page has its own address, /sangrand', () {
    expect(AppRoutes.sangrand, '/sangrand');
  });
}
