// Drives the real app through the 5 parts of the demo on the darbar.live
// landing page, so that a screen recording of the simulator becomes the page's
// film.
//
// It is a recording rig, not a regression test. It asserts almost nothing; it
// touches the app the way a first-time listener would, at a pace a viewer can
// follow. One recording holds two passes:
//
//   A. English, for the film on /
//   C. Punjabi, from a fresh start, for the film on /pa/. Its language step
//      switches to English.
//
// Each pass is one continuous take of 5 parts, and each part starts with a tap.
// Live kirtan starts once and plays through the first 2 parts, so the app is
// never restarted inside a pass:
//
//   1. live      tap play on Live Kirtan
//   2. quality   open the player from the mini player, tap Sound quality, pick
//                Data saver, then close the sheet and the player. Live kirtan
//                plays all the while.
//   3. hukamnama tap the Hukamnama tile
//   4. katha     tap the Katha tile
//   5. language  tap the other language in the switch
//
// After each tap that starts sound, the test waits until the app shows that the
// source plays: its button turns from a play arrow with a ring into a pause or
// a stop. Loading can take seconds. tool/site_film.dart cuts a wait of more than
// 0.6 s out of the film, and starts the sound on the frame where the button
// turns.
//
// The film shows Monday 2 November 2026, whatever day the test runs on: the
// clock, the Sikh date and the recordings resolver are pinned, the way
// test/screens/screens_test.dart pins the clock and the Sikh date. The app
// plays SGPC's files for that day, so the sound that tool/site_film.dart
// mixes in must be that day's too.
//
// This file needs the app at 7b97625 or later (the polished player, and the
// quality sheet's row labels). Copy it into a checkout of that commit to run it.
//
// The taps draw no crosshair. They go straight to the gesture binding, so the
// recording shows the app and nothing else. The page draws its own cursor on
// top of the film, from the positions this test writes to marks.log.
//
// How to use it (tool/site_film.dart then cuts the film from the recording):
//
//   1. Boot the iPhone 17 Pro simulator and set a clean status bar:
//        xcrun simctl status_bar booted override --time 9:41 \
//          --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
//   2. Start the test, with a folder the test and the shell both use, and the
//      path of 2 November's Hukamnama (see _hukamnamaFixture):
//        flutter test integration_test/landing_film_test.dart \
//          -d <simulator id> --dart-define=FILM_DIR=/some/folder \
//          --dart-define=HUKAMNAMA_FIXTURE=$PWD/test/fixtures/sgpc_hukamnama_2026_11_02.json
//   3. The test writes FILM_DIR/ready once the app has today's data, then waits.
//   4. Start `xcrun simctl io booted recordVideo FILM_DIR/raw.mov`, wait a
//      moment, then create FILM_DIR/go. The test runs both passes.
//   5. When FILM_DIR/done appears, stop the recording with SIGINT.
//
// FILM_DIR/marks.log gets one line per step: "name epoch-milliseconds", and,
// for a tap, the tap's place as a fraction of the screen: "name epoch x y".
// A mark is written just before its tap. The taps of a pass are named
// "<pass>_live", "<pass>_player", "<pass>_quality", "<pass>_saver",
// "<pass>_scrim" (a tap outside the sheet, which closes it), "<pass>_close"
// (a swipe down on the player), "<pass>_hukamnama", "<pass>_katha" and
// "<pass>_language". "<pass>_start" and "<pass>_end" bound a pass. The
// simulator's audio does not reach the recording, so the sound track
// is made apart.
//
// The simulator shares the Mac's file system, which is why the test can watch
// for a file the shell creates. It needs the network: live kirtan, the Katha
// and the Hukamnama all come from SGPC.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:live_darbar/l10n/app_localizations_en.dart';
import 'package:live_darbar/l10n/app_localizations_pa.dart';
import 'package:live_darbar/main.dart' as app;
import 'package:live_darbar/src/controllers/hukamnama_controller.dart';
import 'package:live_darbar/src/controllers/now_playing_controller.dart';
import 'package:live_darbar/src/controllers/sikh_date_controller.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:live_darbar/src/controllers/daily_content_controller.dart';
import 'package:live_darbar/src/core/clock.dart';
import 'package:live_darbar/src/models/hukamnama.dart';
import 'package:live_darbar/src/models/sikh_date.dart';
import 'package:live_darbar/src/views/screens/home_screen.dart';
import 'package:live_darbar/src/views/widgets/language_switch.dart';
import 'package:live_darbar/src/views/widgets/mini_player_widget.dart';
import 'package:live_darbar/src/views/widgets/play_button.dart';
import 'package:live_darbar/src/views/widgets/pressable.dart';
import 'package:live_darbar/src/views/widgets/quality_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _dir = String.fromEnvironment('FILM_DIR');

/// The path of test/fixtures/sgpc_hukamnama_2026_11_02.json, which the
/// simulator reads from the Mac's file system. SGPC's feed serves the newest
/// day, so after it posts the next morning's text, the card on the home screen
/// would read "Hukamnama of 3 November" under a date of 2 November. With the
/// fixture it reads 2 November's, as the screenshots do.
const _hukamnamaFixture = String.fromEnvironment('HUKAMNAMA_FIXTURE');

/// 2 November's Hukamnama, from [_hukamnamaFixture].
class _Fixture extends HukamnamaController {
  @override
  Future<Hukamnama> build() async => Hukamnama.fromSgpc(
        jsonDecode(File(_hukamnamaFixture).readAsStringSync())
            as Map<String, dynamic>,
      );
}

/// The film shows Monday 2 November 2026 in Amritsar, whatever day it runs on.
/// The same pin as test/screens/screens_test.dart.
DateTime _pinnedNow() => DateTime.utc(2026, 11, 2, 6);

final List<Override> _pinnedDate = [
  clockProvider.overrideWithValue(_pinnedNow),
  // The app's recordings resolver reads its own clock. Pin it too, so the
  // Hukamnama and Katha say "Today's recording" and play 2 November's files.
  dailyContentResolver.overrideWith((ref) {
    final resolver = DailyContentResolver(clock: _pinnedNow);
    ref.onDispose(resolver.dispose);
    return resolver;
  }),
  sikhDateProvider.overrideWith(
    (ref) async => SikhDate(
      day: 17,
      monthIndex: 7,
      year: 558,
      gregorian: DateTime.utc(2026, 11, 2),
    ),
  ),
  if (_hukamnamaFixture.isNotEmpty) hukamnamaProvider.overrideWith(_Fixture.new),
];

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final en = AppLocalizationsEn();
  final pa = AppLocalizationsPa();
  var pointer = 100;

  void mark(String name, [Offset? at, Size? of]) {
    if (_dir.isEmpty) return;
    final place = at == null || of == null
        ? ''
        : ' ${(at.dx / of.width).toStringAsFixed(4)}'
            ' ${(at.dy / of.height).toStringAsFixed(4)}';
    File('$_dir/marks.log').writeAsStringSync(
      '$name ${DateTime.now().millisecondsSinceEpoch}$place\n',
      mode: FileMode.append,
    );
  }

  Future<void> hold(WidgetTester tester, int ms) =>
      tester.pump(Duration(milliseconds: ms));

  /// A tap at [at] that the recording does not mark. It goes to the gesture
  /// binding itself: the test binding's own tap path draws a crosshair.
  Future<void> tapAt(WidgetTester tester, Offset at) async {
    final id = pointer++;
    final view = tester.view.viewId;
    GestureBinding.instance.handlePointerEvent(
      PointerDownEvent(viewId: view, pointer: id, position: at),
    );
    await tester.pump(const Duration(milliseconds: 90));
    GestureBinding.instance.handlePointerEvent(
      PointerUpEvent(viewId: view, pointer: id, position: at),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }

  /// Writes the mark for [name], with the centre of [target], then taps it.
  Future<void> tapMarked(
    WidgetTester tester,
    String name,
    Finder target, {
    Offset shift = Offset.zero,
  }) async {
    final at = tester.getCenter(target.first) + shift;
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    mark(name, at, size);
    await tapAt(tester, at);
  }

  /// Writes the mark for [name], at [fx], [fy] as fractions of the screen,
  /// then taps there. For a tap on something that has no widget of its own,
  /// such as the scrim that closes a sheet.
  Future<void> tapPlace(
    WidgetTester tester,
    String name,
    double fx,
    double fy,
  ) async {
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    final at = Offset(size.width * fx, size.height * fy);
    mark(name, at, size);
    await tapAt(tester, at);
  }

  var clock = 0;

  /// Writes the mark for [name], then swipes down from [fx], [fy] by [by] of
  /// the screen's height, in 0.2 s. The events carry times, so that the sheet
  /// below reads a quick flick and not a slow drag.
  Future<void> swipeDown(
    WidgetTester tester,
    String name,
    double fx,
    double fy,
    double by,
  ) async {
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    final from = Offset(size.width * fx, size.height * fy);
    mark(name, from, size);
    final id = pointer++;
    final view = tester.view.viewId;
    GestureBinding.instance.handlePointerEvent(PointerDownEvent(
      viewId: view,
      pointer: id,
      position: from,
      timeStamp: Duration(milliseconds: clock),
    ));
    await tester.pump(const Duration(milliseconds: 40));
    const steps = 8;
    for (var i = 1; i <= steps; i++) {
      clock += 25;
      final to = from + Offset(0, size.height * by * i / steps);
      GestureBinding.instance.handlePointerEvent(PointerMoveEvent(
        viewId: view,
        pointer: id,
        position: to,
        delta: Offset(0, size.height * by / steps),
        timeStamp: Duration(milliseconds: clock),
      ));
      await tester.pump(const Duration(milliseconds: 25));
    }
    GestureBinding.instance.handlePointerEvent(PointerUpEvent(
      viewId: view,
      pointer: id,
      position: from + Offset(0, size.height * by),
      timeStamp: Duration(milliseconds: clock + 10),
    ));
    await tester.pump(const Duration(milliseconds: 16));
  }

  Finder playButton(int index) => find.byWidgetPredicate(
        (w) => w is PlayButton && w.index == index,
      );

  /// Waits until the app shows that source [index] plays: its button has
  /// turned from a play arrow with a ring into a pause or a stop. SGPC's
  /// recordings take a second or more to load, and live kirtan can take 5
  /// or more. tool/site_film.dart cuts that wait out of the film.
  ///
  /// For a moment after a tap, the state still holds the answer of the source
  /// before, so it must hold for 0.6 s.
  Future<void> waitPlaying(WidgetTester tester, int index) async {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    var steady = 0;
    for (var i = 0; i < 600; i++) {
      final now = container.read(nowPlayingProvider);
      final playing = now.index == index &&
          (now.action == PlayAction.pause || now.action == PlayAction.stop);
      steady = playing ? steady + 1 : 0;
      if (steady >= 12) return;
      await hold(tester, 50);
    }
    fail('Source $index did not play within 30 s.');
  }

  /// One pass: the 5 parts, in one take. [prefix] names the marks.
  Future<void> pass(
    WidgetTester tester, {
    required String prefix,
    required String switchTo,
    required String dataSaverLabel, // in the language the pass starts in
  }) async {
    mark('${prefix}_start');
    await hold(tester, 1400);

    // 1. Live kirtan.
    await tapMarked(tester, '${prefix}_live', playButton(kLiveIndex));
    await waitPlaying(tester, kLiveIndex);
    await hold(tester, 2200);

    // 2. Sound quality, while live kirtan plays. The mini player has risen by
    // now. Tap its left part, away from its own play button.
    await tapMarked(
      tester,
      '${prefix}_player',
      find.byType(MiniPlayer),
      shift: const Offset(-60, 0),
    );
    await hold(tester, 1300);
    await tapMarked(tester, '${prefix}_quality', find.byType(QualityButton));
    await hold(tester, 1100);
    await tapMarked(
      tester,
      '${prefix}_saver',
      find.byWidgetPredicate(
        (w) =>
            w is Pressable &&
            (w.semanticLabel ?? '').startsWith(dataSaverLabel),
      ),
    );
    await hold(tester, 1500);
    // Close the sheet with a tap on the scrim above it, then the player with
    // a swipe down. Each closes in under half a second.
    await tapPlace(tester, '${prefix}_scrim', 0.5, 0.16);
    await hold(tester, 900);
    await swipeDown(tester, '${prefix}_close', 0.5, 0.12, 0.7);
    await hold(tester, 1100);

    // 3. Hukamnama.
    await tapMarked(tester, '${prefix}_hukamnama', playButton(kMukhwakIndex));
    await waitPlaying(tester, kMukhwakIndex);
    await hold(tester, 2600);

    // 4. Katha.
    await tapMarked(tester, '${prefix}_katha', playButton(kKathaIndex));
    await waitPlaying(tester, kKathaIndex);
    await hold(tester, 2600);

    // 5. Language. The Katha plays on.
    final other = find.descendant(
      of: find.byType(LanguageSwitch),
      matching: find.text(switchTo),
    );
    await tapMarked(tester, '${prefix}_language', other);
    await hold(tester, 3200);
    mark('${prefix}_end');
  }

  testWidgets(
    'landing film',
    (tester) async {
      expect(_dir, isNotEmpty, reason: 'Pass --dart-define=FILM_DIR=<folder>.');
      // Draw every frame, so the recording is smooth and not frame-on-demand.
      binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
      // Let the taps below reach the app without the binding's crosshair.
      binding.shouldPropagateDevicePointerEvents = true;
      try {
        // A clean install: English, default text size, automatic quality.
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        for (final name in ['ready', 'go', 'done', 'marks.log']) {
          final f = File('$_dir/$name');
          if (f.existsSync()) f.deleteSync();
        }

        // main() is `void ... async`, so it cannot be awaited; give it a moment.
        // It starts the audio plumbing. The app it runs has the real date, so
        // it is replaced at once by one with the date pinned.
        app.main();
        await hold(tester, 3000);
        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: _pinnedDate,
            child: const app.MyApp(),
          ),
        );
        await hold(tester, 1500);
        await _waitForToday(tester);

        File('$_dir/ready').writeAsStringSync('1');
        while (!File('$_dir/go').existsSync()) {
          await hold(tester, 250);
        }

        // ---- A. English, for /; the language step ends in Punjabi ----
        await pass(
          tester,
          prefix: 'A',
          switchTo: 'ਪੰਜਾਬੀ',
          dataSaverLabel: en.quality_data_saver,
        );
        await hold(tester, 1500);

        // ---- C. Punjabi, from a fresh start, for /pa/ ----
        // A new ProviderScope is a new app as far as state goes: no player, no
        // mini player, the language and the quality read from storage again.
        mark('C_restart');
        await prefs.clear();
        await prefs.setString('locale', 'pa');
        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: _pinnedDate,
            child: const app.MyApp(),
          ),
        );
        await hold(tester, 1500);
        await _waitForToday(tester);

        await pass(
          tester,
          prefix: 'C',
          switchTo: 'English',
          dataSaverLabel: pa.quality_data_saver,
        );

        mark('end');
        File('$_dir/done').writeAsStringSync('1');
        await hold(tester, 1500);
      } finally {
        binding.shouldPropagateDevicePointerEvents = false;
      }
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

Future<void> _waitForToday(WidgetTester tester) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(HomeScreen)),
  );
  for (var i = 0; i < 60; i++) {
    final ready = container.read(hukamnamaProvider).hasValue &&
        container.read(sikhDateProvider).hasValue;
    if (ready) break;
    await tester.pump(const Duration(milliseconds: 500));
  }
  // Paintings decode, language settles.
  await tester.pump(const Duration(milliseconds: 2500));
}
