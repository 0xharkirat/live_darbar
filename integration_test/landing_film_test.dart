// Drives the real app through the flow that the darbar.live landing page shows,
// so that a screen recording of the simulator becomes the page's demo film.
//
// It is a recording rig, not a regression test. It asserts almost nothing; it
// exists to touch the app the way a first-time listener would, at a pace a
// viewer can follow. It runs the flow 3 times in one recording:
//
//   A. in English: the hero film (open, play, player, Hukamnama, meaning)
//   B. in English: more moments, for stills (text size, sound quality)
//   C. in Punjabi, from a fresh start: the same flow as A, for /pa/
//
// How to use it:
//
//   1. Boot the iPhone 17 Pro simulator and set a clean status bar:
//        xcrun simctl status_bar booted override --time 9:41 \
//          --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
//   2. Start the test, with a folder the test and the shell both use:
//        flutter test integration_test/landing_film_test.dart \
//          -d <simulator id> --dart-define=FILM_DIR=/some/folder
//   3. The test writes FILM_DIR/ready once the app has today's data, then waits.
//   4. Start `xcrun simctl io booted recordVideo FILM_DIR/raw.mov`, wait a
//      moment, then create FILM_DIR/go. The test runs the flow.
//   5. When FILM_DIR/done appears, stop the recording with SIGINT.
//
// FILM_DIR/marks.log gets one "name epoch-milliseconds" line per step, so the
// recording can be cut at the right frames. A mark is the moment a step
// starts, not the moment the screen answers: find the frame to cut at by
// looking, and use the marks to tell the steps apart.
//
//   6. Cut and encode the film for site/img/ (about 15 s, muted, under 1 MB
//      per file; the page names them film.mp4 and film.webm):
//        ffmpeg -i raw.mov -an \
//          -vf "trim=start=4.5:duration=14.8,setpts=PTS-STARTPTS,fps=30,\
//               scale=540:1174:flags=lanczos,fade=t=out:st=14.45:d=0.35" \
//          -c:v libx264 -crf 31 -pix_fmt yuv420p -movflags +faststart film.mp4
//      The same filter with `-c:v libvpx-vp9 -b:v 0 -crf 41` makes film.webm.
//      The poster is the first frame, saved as WebP.
//
// The simulator shares the Mac's file system, which is why the test can watch
// for a file the shell creates. It needs the network: live kirtan and the
// Hukamnama both come from SGPC.

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:live_darbar/l10n/app_localizations_en.dart';
import 'package:live_darbar/l10n/app_localizations_pa.dart';
import 'package:live_darbar/main.dart' as app;
import 'package:live_darbar/src/controllers/hukamnama_controller.dart';
import 'package:live_darbar/src/controllers/sikh_date_controller.dart';
import 'package:live_darbar/src/views/screens/home_screen.dart';
import 'package:live_darbar/src/views/screens/hukamnama_screen.dart';
import 'package:live_darbar/src/views/screens/now_playing_screen.dart';
import 'package:live_darbar/src/views/widgets/mini_player_widget.dart';
import 'package:live_darbar/src/views/widgets/pressable.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _dir = String.fromEnvironment('FILM_DIR');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final en = AppLocalizationsEn();
  final pa = AppLocalizationsPa();

  void mark(String name) {
    if (_dir.isEmpty) return;
    File('$_dir/marks.log').writeAsStringSync(
      '$name ${DateTime.now().millisecondsSinceEpoch}\n',
      mode: FileMode.append,
    );
  }

  Future<void> hold(WidgetTester tester, int ms) =>
      tester.pump(Duration(milliseconds: ms));

  /// The outermost scroll view inside [screen].
  ScrollPosition scrollOf(WidgetTester tester, Type screen) {
    final scrollable = find.descendant(
      of: find.byType(screen),
      matching: find.byType(Scrollable),
    );
    return tester.state<ScrollableState>(scrollable.first).position;
  }

  /// Scrolls by [delta] in [ms], as one smooth motion. Not a finger fling, so
  /// it stops where it is told to and the recording is the same every time.
  Future<void> glideBy(
    WidgetTester tester,
    Type screen,
    double delta,
    int ms, {
    Curve curve = Curves.easeInOutCubic,
  }) async {
    final position = scrollOf(tester, screen);
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    position.animateTo(
      target,
      duration: Duration(milliseconds: ms),
      curve: curve,
    );
    await hold(tester, ms + 80);
  }

  /// Scrolls the reader down until the Meaning heading is on screen, at a
  /// steady pace, then lets it settle with the heading in the top third.
  Future<void> glideToMeaning(WidgetTester tester, String heading) async {
    final title = find.text(heading);
    final height = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    for (var i = 0; i < 30; i++) {
      if (title.evaluate().isNotEmpty &&
          tester.getTopLeft(title.first).dy < height * 0.8) {
        break;
      }
      await glideBy(tester, HukamnamaScreen, 520, 380, curve: Curves.linear);
    }
    final y = tester.getTopLeft(title.first).dy;
    await glideBy(tester, HukamnamaScreen, y - height * 0.3, 700,
        curve: Curves.easeOutCubic);
  }

  Future<void> back(WidgetTester tester) async {
    final button = find.byType(CupertinoNavigationBarBackButton);
    if (button.evaluate().isNotEmpty) {
      await tester.tap(button.first);
    } else {
      Navigator.of(tester.element(find.byType(HukamnamaScreen))).pop();
    }
    await hold(tester, 800);
  }

  Future<void> waitForToday(WidgetTester tester) async {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    for (var i = 0; i < 60; i++) {
      final ready = container.read(hukamnamaProvider).hasValue &&
          container.read(sikhDateProvider).hasValue;
      if (ready) break;
      await hold(tester, 500);
    }
    await hold(tester, 2500); // paintings decode, language settles
  }

  /// Home, play, player, back, scroll to the Read card, open the reader,
  /// scroll to the meaning. [prefix] names the marks.
  Future<void> flow(
    WidgetTester tester, {
    required String prefix,
    required String liveTitle,
    required String readLabel,
    required String meaningHeading,
  }) async {
    mark('${prefix}_start');
    await hold(tester, 1400);

    mark('${prefix}_play');
    await tester.tap(find.text(liveTitle).first, warnIfMissed: false);
    await hold(tester, 2000);

    mark('${prefix}_player');
    final mini = find.byType(MiniPlayer);
    await tester.tapAt(tester.getTopLeft(mini) + const Offset(96, 34));
    await hold(tester, 2600);

    mark('${prefix}_player_closed');
    Navigator.of(tester.element(find.byType(NowPlayingScreen))).pop();
    await hold(tester, 1100);

    // The Read card sits under the fold. Bring it up, so the viewer sees it.
    mark('${prefix}_home_scroll');
    await glideBy(tester, HomeScreen, 360, 800);
    await hold(tester, 900);

    mark('${prefix}_reader');
    final readCard = find.byWidgetPredicate(
      (w) => w is Pressable && w.semanticLabel == readLabel,
    );
    await tester.tap(readCard.first, warnIfMissed: false);
    await hold(tester, 1700);

    mark('${prefix}_scroll');
    await glideToMeaning(tester, meaningHeading);
    mark('${prefix}_meaning');
    await hold(tester, 1500);
  }

  testWidgets(
    'landing film',
    (tester) async {
      expect(_dir, isNotEmpty, reason: 'Pass --dart-define=FILM_DIR=<folder>.');
      // Draw every frame, so the recording is smooth and not frame-on-demand.
      binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

      // A clean install: English, default text size, automatic quality.
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      for (final name in ['ready', 'go', 'done', 'marks.log']) {
        final f = File('$_dir/$name');
        if (f.existsSync()) f.deleteSync();
      }

      // main() is `void ... async`, so it cannot be awaited; give it a moment.
      app.main();
      await hold(tester, 3000);
      await waitForToday(tester);

      File('$_dir/ready').writeAsStringSync('1');
      while (!File('$_dir/go').existsSync()) {
        await hold(tester, 250);
      }

      // ---- A. English: the hero film ----
      await flow(
        tester,
        prefix: 'A',
        liveTitle: en.live_kirtan,
        readLabel: en.read_hukamnama,
        meaningHeading: en.meaning,
      );

      mark('A_punjabi');
      final meaningToPunjabi = find.descendant(
        of: find.byType(HukamnamaScreen),
        matching: find.text('ਪੰਜਾਬੀ'),
      );
      await tester.tap(meaningToPunjabi.first);
      await hold(tester, 2600);
      mark('A_end');

      // ---- B. English: more moments, for stills ----
      // Larger text, at the top of the reader.
      await glideBy(tester, HukamnamaScreen, -20000, 900);
      await hold(tester, 600);
      mark('B_text_before');
      await hold(tester, 600);
      final larger = find.bySemanticsLabel(en.larger_text);
      final bigger = larger.evaluate().isNotEmpty ? larger : find.text('A+');
      await tester.tap(bigger.first);
      await hold(tester, 700);
      await tester.tap(bigger.first);
      await hold(tester, 1800);
      mark('B_text_after');
      // Back to the default size, so the Punjabi pass starts clean.
      final smaller =
          find.bySemanticsLabel(en.smaller_text).evaluate().isNotEmpty
              ? find.bySemanticsLabel(en.smaller_text)
              : find.text('A−');
      await tester.tap(smaller.first);
      await hold(tester, 500);
      await tester.tap(smaller.first);
      await hold(tester, 500);
      await back(tester);
      await hold(tester, 600);

      // The player, and the sound quality sheet.
      mark('B_quality');
      await tester.tapAt(tester.getTopLeft(find.byType(MiniPlayer)) +
          const Offset(96, 34));
      await hold(tester, 2200);
      await tester.tap(find.textContaining(en.quality).first);
      await hold(tester, 1500);
      mark('B_sheet');
      await hold(tester, 1500);
      await tester.tap(find.text(en.quality_data_saver).first);
      await hold(tester, 1800);
      mark('B_saver');
      // Back to Automatic, so the Punjabi pass starts clean.
      await tester.tap(find.text(en.quality_automatic).first);
      await hold(tester, 700);
      await tester.tapAt(const Offset(180, 120)); // the barrier
      await hold(tester, 900);
      if (find.byType(NowPlayingScreen).evaluate().isNotEmpty) {
        Navigator.of(tester.element(find.byType(NowPlayingScreen))).pop();
      }
      await hold(tester, 1000);

      // ---- C. Punjabi, from a fresh start ----
      // A new ProviderScope is a new app as far as state goes: no player, no
      // mini player, the language read from storage again.
      mark('C_restart');
      await prefs.setString('locale', 'pa');
      await tester.pumpWidget(
        ProviderScope(key: UniqueKey(), child: const app.MyApp()),
      );
      await hold(tester, 1500);
      await waitForToday(tester);

      await flow(
        tester,
        prefix: 'C',
        liveTitle: pa.live_kirtan,
        readLabel: pa.read_hukamnama,
        meaningHeading: pa.meaning,
      );

      mark('C_english');
      final meaningToEnglish = find.descendant(
        of: find.byType(HukamnamaScreen),
        matching: find.text('English'),
      );
      await tester.tap(meaningToEnglish.first);
      await hold(tester, 2600);
      mark('C_end');

      // Larger text in Punjabi, for a still.
      await glideBy(tester, HukamnamaScreen, -20000, 900);
      await hold(tester, 600);
      final biggerPa = find.bySemanticsLabel(pa.larger_text).evaluate().isNotEmpty
          ? find.bySemanticsLabel(pa.larger_text)
          : find.text('A+');
      await tester.tap(biggerPa.first);
      await hold(tester, 700);
      await tester.tap(biggerPa.first);
      await hold(tester, 1800);
      mark('C_text_after');

      mark('end');
      File('$_dir/done').writeAsStringSync('1');
      await hold(tester, 1500);
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
