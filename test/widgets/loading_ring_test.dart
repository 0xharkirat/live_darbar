import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:live_darbar/src/controllers/now_playing_controller.dart';
import 'package:live_darbar/src/core/motion.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/models/live_playback_state.dart';
import 'package:live_darbar/src/views/widgets/loading_ring.dart';
import 'package:live_darbar/src/views/widgets/play_button.dart';

import '../support/app_harness.dart';

/// The 1 ring that says "loading" in the app: gold, thin, and silent for the
/// first moments, so a load that is quick shows nothing at all. A screen
/// reader hears "Loading" in the listener's language.
void main() {
  Future<void> pumpRing(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    LoadingRing ring = const LoadingRing(size: 40),
  }) {
    return tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Center(child: ring)),
      ),
    );
  }

  /// How visible the ring is this frame, not the value it is heading for.
  double shown(WidgetTester tester) => tester
      .renderObject<RenderAnimatedOpacity>(
        find.descendant(
          of: find.byType(LoadingRing),
          matching: find.byType(AnimatedOpacity),
        ),
      )
      .opacity
      .value;

  group('it is quiet at first', () {
    testWidgets('and shows nothing before the delay', (tester) async {
      await pumpRing(tester);

      expect(shown(tester), 0);
      await tester.pump(Motion.ringDelay - const Duration(milliseconds: 10));
      expect(shown(tester), 0);

      // Let it start, so the test ends with nothing pending.
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump(Motion.quick);
    });

    testWidgets('and a load that ends inside the delay shows nothing, ever', (
      tester,
    ) async {
      await pumpRing(tester);
      await tester.pump(const Duration(milliseconds: 200));
      expect(shown(tester), 0);

      await tester.pumpWidget(const SizedBox());

      // No timer is left behind, or the test would fail here.
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('then fades in, and does not pop', (tester) async {
      await pumpRing(tester);

      await tester.pump(Motion.ringDelay);
      await tester.pump(const Duration(milliseconds: 60));
      expect(shown(tester), inExclusiveRange(0, 1), reason: 'part way in');

      await tester.pump(Motion.quick);
      expect(shown(tester), 1);
    });

    testWidgets('and spins once it shows', (tester) async {
      await pumpRing(tester);
      await tester.pump(Motion.ringDelay);
      await tester.pump(Motion.quick);

      double turns() => tester
          .widget<RotationTransition>(
            find.descendant(
              of: find.byType(LoadingRing),
              matching: find.byType(RotationTransition),
            ),
          )
          .turns
          .value;
      final before = turns();
      await tester.pump(const Duration(milliseconds: 200));

      expect(turns(), isNot(before));
    });
  });

  group('the look', () {
    test('is gold and thin by default', () {
      const ring = LoadingRing(size: 40);

      expect(ring.color, Palette.gold);
      expect(ring.strokeWidth, lessThanOrEqualTo(1.5));
    });

    testWidgets('keeps the size it was given, shown or not', (tester) async {
      await pumpRing(tester, ring: const LoadingRing(size: 24));
      expect(tester.getSize(find.byType(LoadingRing)), const Size(24, 24));

      await tester.pump(Motion.ringDelay);
      await tester.pump(Motion.quick);
      expect(tester.getSize(find.byType(LoadingRing)), const Size(24, 24));
    });
  });

  group('for a screen reader', () {
    for (final locale in ['en', 'pa']) {
      testWidgets('says "Loading" in $locale at once', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpRing(tester, locale: Locale(locale));

        expect(
          find.bySemanticsLabel(lookupAppLocalizations(Locale(locale)).loading),
          findsOneWidget,
        );
        handle.dispose();
        await tester.pump(Motion.ringDelay);
        await tester.pump(Motion.quick);
      });
    }

    testWidgets('can leave the words to the line beside it', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpRing(
        tester,
        ring: const LoadingRing(size: 12, announce: false),
      );

      expect(find.bySemanticsLabel(RegExp('Loading')), findsNothing);
      handle.dispose();
      await tester.pump(Motion.ringDelay);
      await tester.pump(Motion.quick);
    });
  });

  group('in the app', () {
    const working = NowPlaying(
      index: kMukhwakIndex,
      action: PlayAction.working,
      started: true,
      live: LivePlaybackState(isLiveSource: false),
    );
    const reconnecting = NowPlaying(
      index: kLiveIndex,
      action: PlayAction.failed,
      started: true,
      live: LivePlaybackState(status: LiveStatus.failed, reconnectAttempt: 1),
    );

    testWidgets('a play button that is working shows the ring', (
      tester,
    ) async {
      await pumpApp(tester, now: working);

      expect(
        find.descendant(
          of: find.byType(PlayButton),
          matching: find.byType(LoadingRing),
        ),
        findsWidgets,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('a line that says it is reconnecting shows the ring', (
      tester,
    ) async {
      await pumpApp(tester, now: reconnecting);

      expect(find.text('Reconnecting…'), findsWidgets);
      expect(find.byType(LoadingRing), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
