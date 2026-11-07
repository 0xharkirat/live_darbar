import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/widget_card_controller.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/core/widget_card_rules.dart';
import 'package:live_darbar/src/views/screens/home_screen.dart';
import 'package:live_darbar/src/views/widgets/demo_film.dart';
import 'package:live_darbar/src/views/widgets/widget_card.dart';
import 'package:live_darbar/src/views/widgets/widget_picture.dart';
import 'package:live_darbar/src/views/widgets/widget_steps_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/app_harness.dart';
import '../support/fake_film_player.dart';
import '../support/fake_widget_install.dart';

/// The "add the widget" card on Home, and the steps sheet it opens. The rules
/// that decide when it shows are in test/core/widget_card_rules_test.dart.
/// Here the card is checked on screen, with a phone that answers.
final _en = lookupAppLocalizations(const Locale('en'));
final _pa = lookupAppLocalizations(const Locale('pa'));

/// A listener who played the Hukamnama on an earlier visit and has not been
/// shown the card.
const _later = {WidgetCardController.playedKey: true};

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _pumpHome(
  WidgetTester tester, {
  String locale = 'en',
  FakeWidgetInstall? install,
  Map<String, Object> prefs = _later,
  Duration cardSettle = Duration.zero,
  FakeFilmPlayers? films,
}) async {
  await pumpApp(
    tester,
    locale: locale,
    widgetInstall: install ?? FakeWidgetInstall(),
    prefs: prefs,
    cardSettle: cardSettle,
    films: films,
  );
  await _settle(tester);
}

/// Whether a [CustomPaint] is the one that draws a film's taps.
bool _isMarks(Element e) =>
    e.widget is CustomPaint &&
    (e.widget as CustomPaint).painter is TapMarksPainter;

/// The app goes to the background and comes back, as when the listener adds
/// the widget on the home screen.
Future<void> _comeBack(WidgetTester tester) async {
  final binding = tester.binding;
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    binding.handleAppLifecycleStateChanged(state);
  }
  await _settle(tester);
}

Finder get _title => find.text(_en.widget_card_title);
Finder get _add => find.text(_en.widget_card_add);
Finder get _notNow => find.text(_en.widget_card_dismiss);

Future<bool?> _saved(String key) async =>
    (await SharedPreferences.getInstance()).getBool(key);

void main() {
  group('the card', () {
    testWidgets('shows on a later visit, with its picture and 2 buttons', (
      tester,
    ) async {
      await _pumpHome(tester);

      expect(_title, findsOneWidget);
      expect(_add, findsOneWidget);
      expect(_notNow, findsOneWidget);
      expect(find.byType(WidgetPicture), findsOneWidget);
    });

    testWidgets('sits under the Hukamnama card, so the order above stays', (
      tester,
    ) async {
      await _pumpHome(tester);

      // The Hukamnama card shows the Rahao line of the recorded text.
      final read = tester.getBottomLeft(find.textContaining('ਜਿਉ ਬਿਨੁ')).dy;
      final card = tester.getTopLeft(_title).dy;
      final about = tester.getTopLeft(find.text(_en.about_this_app)).dy;
      expect(card, greaterThan(read));
      expect(card, lessThan(about));
    });

    testWidgets('does not show before the Hukamnama has played', (
      tester,
    ) async {
      await _pumpHome(tester, prefs: const {});

      expect(_title, findsNothing);
    });

    testWidgets('does not show where there are no home screen widgets', (
      tester,
    ) async {
      await _pumpHome(tester, install: FakeWidgetInstall(supported: false));

      expect(_title, findsNothing);
    });

    testWidgets('does not show when the widget is already on the home screen', (
      tester,
    ) async {
      await _pumpHome(
        tester,
        install: FakeWidgetInstall(placementNow: WidgetPlacement.added),
      );

      expect(_title, findsNothing);
      expect(await _saved(WidgetCardController.shownKey), isNull);
    });

    testWidgets('does not show when the phone cannot say if it is there', (
      tester,
    ) async {
      await _pumpHome(
        tester,
        install: FakeWidgetInstall()..placementError = StateError('no plugin'),
      );

      expect(_title, findsNothing);
    });

    testWidgets('shows once: an earlier visit showed it, so it stays away', (
      tester,
    ) async {
      await _pumpHome(
        tester,
        prefs: {..._later, WidgetCardController.shownKey: true},
      );

      expect(_title, findsNothing);
    });

    testWidgets('is saved as shown the moment it appears', (tester) async {
      await _pumpHome(tester);

      expect(_title, findsOneWidget);
      expect(await _saved(WidgetCardController.shownKey), isTrue);
    });

    testWidgets('stays on screen for the rest of the visit', (tester) async {
      await _pumpHome(tester);
      expect(_title, findsOneWidget);

      await _comeBack(tester);
      await _settle(tester);

      expect(_title, findsOneWidget);
    });

    testWidgets('"Not now" hides it for good', (tester) async {
      await _pumpHome(tester);
      await tester.ensureVisible(_notNow);
      await tester.pump();

      await tester.tap(_notNow);
      await _settle(tester);

      expect(_title, findsNothing);
      expect(await _saved(WidgetCardController.dismissedKey), isTrue);
    });

    testWidgets('does not come back after "Not now", on a new visit', (
      tester,
    ) async {
      await _pumpHome(
        tester,
        prefs: {
          ..._later,
          WidgetCardController.shownKey: true,
          WidgetCardController.dismissedKey: true,
        },
      );

      expect(_title, findsNothing);
    });

    testWidgets('goes away when the listener adds the widget and comes back', (
      tester,
    ) async {
      final phone = FakeWidgetInstall();
      await _pumpHome(tester, install: phone);
      expect(_title, findsOneWidget);

      phone.placementNow = WidgetPlacement.added;
      await _comeBack(tester);

      expect(_title, findsNothing);
    });

    testWidgets('a first play shows it on the next return to the front', (
      tester,
    ) async {
      // The recording played on this visit, so this is not yet a later one.
      await _pumpHome(tester, prefs: const {});
      expect(_title, findsNothing);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      await container.read(widgetCardProvider.notifier).markPlayed();
      await _settle(tester);
      expect(_title, findsNothing, reason: 'the same visit');

      await _comeBack(tester);

      expect(_title, findsOneWidget);
    });
  });

  group('a sheet', () {
    testWidgets('keeps the card away while it is open', (tester) async {
      // The card waits 5 s, as the app waits for the sheets of a launch.
      await _pumpHome(tester, cardSettle: const Duration(seconds: 5));
      showWidgetStepsSheet(tester.element(find.byType(HomeScreen)));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.pump(const Duration(seconds: 6));

      expect(find.text(_en.widget_steps_title), findsOneWidget);
      expect(_title, findsNothing);
      expect(await _saved(WidgetCardController.shownKey), isNull,
          reason: 'the 1 time is not spent under a sheet');
    });

    testWidgets('lets the card show once it has closed', (tester) async {
      await _pumpHome(tester, cardSettle: const Duration(seconds: 5));
      showWidgetStepsSheet(tester.element(find.byType(HomeScreen)));
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      expect(_title, findsNothing);

      await tester.tap(find.text(_en.widget_steps_done));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await _settle(tester);

      expect(_title, findsOneWidget);
    });

    testWidgets('a card that is on screen stays when a sheet opens', (
      tester,
    ) async {
      await _pumpHome(tester);
      expect(_title, findsOneWidget);

      showWidgetStepsSheet(tester.element(find.byType(HomeScreen)));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(_title, findsOneWidget);
    });
  });

  group('Add widget', () {
    testWidgets('on Android asks the phone, which shows its own dialog', (
      tester,
    ) async {
      final phone = FakeWidgetInstall();
      await _pumpHome(tester, install: phone);
      await tester.ensureVisible(_add);
      await tester.pump();

      await tester.tap(_add);
      await _settle(tester);

      expect(phone.pinCount, 1);
      expect(find.text(_en.widget_steps_title), findsNothing);
    });

    testWidgets('Cancel in the dialog keeps the card, and a tap asks again', (
      tester,
    ) async {
      // Android tells the app nothing when the listener taps Cancel. The app
      // only finds no widget when it comes back to the front.
      final phone = FakeWidgetInstall();
      await _pumpHome(tester, install: phone);
      await tester.ensureVisible(_add);
      await tester.pump();

      await tester.tap(_add);
      await _settle(tester);
      await _comeBack(tester);

      expect(_title, findsOneWidget, reason: 'Cancel is not Not now');
      expect(
        find.text(_en.widget_steps_title),
        findsNothing,
        reason: 'Cancel means no, so no steps follow it',
      );

      await tester.ensureVisible(_add);
      await tester.pump();
      await tester.tap(_add);
      await _settle(tester);

      expect(phone.pinCount, 2);
    });

    testWidgets('on Android with no pinning opens the steps', (tester) async {
      final phone = FakeWidgetInstall(pinSupported: false);
      await _pumpHome(tester, install: phone);
      await tester.ensureVisible(_add);
      await tester.pump();

      await tester.tap(_add);
      await _settle(tester);

      expect(phone.pinCount, 0);
      expect(find.text(_en.widget_steps_title), findsOneWidget);
      expect(find.text(_en.widget_steps_android_widgets), findsOneWidget);
      expect(find.text(_en.widget_steps_iphone_add), findsNothing);
    });

    testWidgets('on iPhone opens the steps, with no call to the phone', (
      tester,
    ) async {
      final phone = FakeWidgetInstall(iphone: true);
      await _pumpHome(tester, install: phone);
      await tester.ensureVisible(_add);
      await tester.pump();

      await tester.tap(_add);
      await _settle(tester);

      expect(phone.pinCount, 0);
      expect(find.text(_en.widget_steps_title), findsOneWidget);
    });
  });

  group('the steps sheet', () {
    Future<void> openOnIphone(WidgetTester tester,
        {String locale = 'en', FakeFilmPlayers? films}) async {
      await _pumpHome(
        tester,
        locale: locale,
        install: FakeWidgetInstall(iphone: true),
        prefs: const {},
        films: films,
      );
      showWidgetStepsSheet(tester.element(find.byType(HomeScreen)));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('shows the film and the 3 steps for an iPhone', (tester) async {
      await openOnIphone(tester);

      expect(find.byType(DemoFilmView), findsOneWidget);
      expect(find.byType(WidgetPicture), findsNothing,
          reason: 'the film takes the picture’s place');
      expect(find.text(_en.widget_steps_press_hold), findsOneWidget);
      expect(find.text(_en.widget_steps_iphone_add), findsOneWidget);
      expect(find.text(_en.widget_steps_iphone_find), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    group('the demo film', () {
      final posterOf = find.descendant(
        of: find.byType(DemoFilmView),
        matching: find.byType(Image),
      );

      String posterAsset(WidgetTester tester) =>
          (tester.widget<Image>(posterOf).image as AssetImage).assetName;

      double videoOpacity(WidgetTester tester) => tester
          .widget<AnimatedOpacity>(
            find.descendant(
              of: find.byType(DemoFilmView),
              matching: find.byType(AnimatedOpacity),
            ),
          )
          .opacity;

      testWidgets('plays the iPhone film above the 3 steps, on its own', (
        tester,
      ) async {
        final films = FakeFilmPlayers();
        await openOnIphone(tester, films: films);

        expect(films.players, hasLength(1));
        expect(films.last!.asset, DemoFilm.iphone.video);
        expect(films.last!.initialized, isTrue);
        expect(films.last!.playing, isTrue, reason: 'it starts by itself');
        final film = tester.getBottomLeft(find.byType(DemoFilmView)).dy;
        final title = tester.getTopLeft(find.text(_en.widget_steps_title)).dy;
        final step1 =
            tester.getTopLeft(find.text(_en.widget_steps_press_hold)).dy;
        expect(film, lessThan(title));
        expect(title, lessThan(step1));
      });

      testWidgets('lights the step the film is on, and none after the last', (
        tester,
      ) async {
        final films = FakeFilmPlayers();
        await openOnIphone(tester, films: films);

        Color? badge(int i) => (tester
                .widget<AnimatedContainer>(
                  find.descendant(
                    of: find.byKey(ValueKey('widget-step-$i')),
                    matching: find.byType(AnimatedContainer),
                  ),
                )
                .decoration as BoxDecoration?)
            ?.color;
        Future<List<bool>> lit(double seconds) async {
          films.last!.playAt(seconds);
          await tester.pump(const Duration(milliseconds: 400));
          return [for (var i = 0; i < 3; i++) badge(i) == Palette.gold];
        }

        expect(await lit(0.6), [true, false, false]);
        expect(await lit(3.0), [false, true, false]);
        expect(await lit(8.0), [false, false, true]);
        expect(await lit(17.0), [false, false, false]);
      });

      testWidgets('is a phone frame in the film’s own ratio, centred', (
        tester,
      ) async {
        await openOnIphone(tester);

        final frame = tester.getRect(find.byType(DemoFilmView));
        final screen = tester.getRect(posterOf);
        expect(screen.width / screen.height, closeTo(540 / 1174, 0.001));
        final bezel = (frame.width - screen.width) / 2;
        expect(bezel, closeTo(frame.width * 0.03, 0.01),
            reason: 'the demo film on darbar.live has a 3% bezel');
        expect(frame.center.dx, closeTo(tester.view.physicalSize.width / 6, 1),
            reason: 'in the middle of the sheet');
      });

      testWidgets('shows the poster until the first picture is on screen', (
        tester,
      ) async {
        final films = FakeFilmPlayers();
        await openOnIphone(tester, films: films);

        expect(posterAsset(tester), DemoFilm.iphone.poster);
        expect(videoOpacity(tester), 0,
            reason: 'the film is open and has not drawn a picture yet');
        expect(find.byType(CustomPaint).evaluate().where(_isMarks), isEmpty,
            reason: 'no taps without a film');

        films.last!.playAt(0.4);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(videoOpacity(tester), 1);
        expect(posterAsset(tester), DemoFilm.iphone.poster,
            reason: 'the poster stays under the film');
        expect(
            find.byType(CustomPaint).evaluate().where(_isMarks), hasLength(1));
      });

      testWidgets('draws the taps over the film, and moves them with it', (
        tester,
      ) async {
        final films = FakeFilmPlayers();
        await openOnIphone(tester, films: films);
        films.last!.playAt(0.2);
        await tester.pump();

        final painter = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((p) => p.painter)
            .whereType<TapMarksPainter>()
            .single;
        expect(painter.film, same(DemoFilm.iphone));
        final first = painter.time.value;
        await tester.pump(const Duration(milliseconds: 400));
        expect(painter.time.value, greaterThan(first),
            reason: 'the clock runs between the player’s reports');

        films.last!.playAt(12.0);
        await tester.pump();
        expect(painter.time.value, closeTo(12.0, 0.05),
            reason: 'and takes the player’s word at each report');
      });

      testWidgets('shows the poster and no film when the film cannot open', (
        tester,
      ) async {
        final films = FakeFilmPlayers(initializeError: StateError('no codec'));
        await openOnIphone(tester, films: films);

        expect(tester.takeException(), isNull);
        expect(posterAsset(tester), DemoFilm.iphone.poster);
        expect(find.byKey(const ValueKey('film-view')), findsNothing);
        expect(films.players, hasLength(1), reason: 'it does not try again');
        expect(films.last!.disposed, isTrue);
      });

      testWidgets('shows the poster when the player reports an error', (
        tester,
      ) async {
        final films = FakeFilmPlayers();
        await openOnIphone(tester, films: films);
        films.last!.playAt(1.0);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byKey(const ValueKey('film-view')), findsOneWidget);

        films.last!.report(const FilmValue(hasError: true));
        await tester.pump();

        expect(find.byKey(const ValueKey('film-view')), findsNothing);
        expect(posterAsset(tester), DemoFilm.iphone.poster);
        expect(films.last!.disposed, isTrue);
      });

      testWidgets('shows the poster only under Reduce Motion', (tester) async {
        reduceMotion(tester);
        final films = FakeFilmPlayers();
        await openOnIphone(tester, films: films);

        expect(films.players, isEmpty,
            reason: 'a looping film is motion the listener asked not to see');
        expect(posterAsset(tester), DemoFilm.iphone.poster);
        expect(find.byKey(const ValueKey('film-view')), findsNothing);
        expect(find.byType(DemoFilmView), findsOneWidget);
      });

      testWidgets('pauses when the app goes to the background, and resumes', (
        tester,
      ) async {
        final films = FakeFilmPlayers();
        await openOnIphone(tester, films: films);
        final player = films.last!;
        final plays = player.plays;
        expect(player.pauses, 0);

        for (final state in [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        await tester.pump();
        expect(player.pauses, greaterThan(0));
        expect(player.playing, isFalse);

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump();
        expect(player.plays, greaterThan(plays));
        expect(player.playing, isTrue);
      });

      testWidgets('pauses and lets go of the film when the sheet closes', (
        tester,
      ) async {
        final films = FakeFilmPlayers();
        await openOnIphone(tester, films: films);
        final player = films.last!;
        expect(player.disposed, isFalse);

        await tester.tap(find.text(_en.widget_steps_done));
        await _settle(tester);

        expect(find.byType(DemoFilmView), findsNothing);
        expect(player.pauses, greaterThan(0));
        expect(player.disposed, isTrue);
      });

      testWidgets('hides from a screen reader, which hears the steps', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await openOnIphone(tester);

        expect(
          tester.getSemantics(find.byType(DemoFilmView)).label,
          isEmpty,
        );
        expect(
          find.descendant(
            of: find.byType(DemoFilmView),
            matching: find.byType(ExcludeSemantics),
          ),
          findsWidgets,
        );
        handle.dispose();
      });

      testWidgets('leaves the steps and Done in view on a phone', (
        tester,
      ) async {
        await openOnIphone(tester);

        final done = tester.getBottomLeft(find.text(_en.widget_steps_done)).dy;
        expect(done, lessThan(tester.view.physicalSize.height / 3));
        expect(tester.takeException(), isNull);
      });

      testWidgets('is the Android film on Android, with the widget steps', (
        tester,
      ) async {
        final films = FakeFilmPlayers();
        await _pumpHome(tester, prefs: const {}, films: films);
        showWidgetStepsSheet(tester.element(find.byType(HomeScreen)));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(DemoFilmView), findsOneWidget);
        expect(films.last!.asset, DemoFilm.android.video);
        expect(posterAsset(tester), DemoFilm.android.poster);
        expect(find.byType(WidgetPicture), findsNothing,
            reason: 'the film takes the picture’s place');
        expect(find.text(_en.widget_steps_android_widgets), findsOneWidget);
        final screen = tester.getRect(posterOf);
        expect(screen.width / screen.height, closeTo(540 / 1116, 0.001));
      });

      testWidgets('is the same film in Punjabi', (tester) async {
        final films = FakeFilmPlayers();
        await openOnIphone(tester, locale: 'pa', films: films);

        expect(films.last!.asset, DemoFilm.iphone.video);
        expect(find.text(_pa.widget_steps_title), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      group('files', () {
        int size(String path) => File(path).lengthSync();

        test('are light: each film under 450 KB, each poster under 20 KB', () {
          for (final f in [DemoFilm.iphone, DemoFilm.android]) {
            expect(size(f.video), lessThan(450 * 1000), reason: f.video);
            expect(size(f.poster), lessThan(20 * 1000), reason: f.poster);
          }
        });

        test('are all that the app carries: 2 films, 2 posters, under 1 MB',
            () {
          final files =
              Directory('assets/videos').listSync().whereType<File>().toList();
          expect(files, hasLength(4));
          final total = files.fold<int>(0, (s, f) => s + f.lengthSync());
          expect(total, lessThan(1000 * 1000), reason: '$total bytes');
        });

        test('replace the animated clip, which is gone', () {
          expect(
              File('assets/images/add_widget_demo.webp').existsSync(), isFalse);
          expect(
            File('assets/images/add_widget_demo_still.webp').existsSync(),
            isFalse,
          );
        });
      });
    });

    testWidgets('says each step with its number to a screen reader', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await openOnIphone(tester);

      expect(
        find.bySemanticsLabel('2. ${_en.widget_steps_iphone_add}'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('Done closes it', (tester) async {
      await openOnIphone(tester);

      await tester.tap(find.text(_en.widget_steps_done));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text(_en.widget_steps_title), findsNothing);
    });

    testWidgets('a swipe down closes it', (tester) async {
      await openOnIphone(tester);

      await tester.fling(
        find.text(_en.widget_steps_title),
        const Offset(0, 600),
        2000,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text(_en.widget_steps_title), findsNothing);
    });

    testWidgets('Punjabi: words, Gurmukhi numbers and no letter spacing', (
      tester,
    ) async {
      await openOnIphone(tester, locale: 'pa');

      expect(find.text(_pa.widget_steps_title), findsOneWidget);
      expect(find.text(_pa.widget_steps_press_hold), findsOneWidget);
      for (final number in ['੧', '੨', '੩']) {
        expect(find.text(number), findsOneWidget);
      }
      for (final text in [
        _pa.widget_steps_title,
        _pa.widget_steps_press_hold,
        _pa.widget_steps_iphone_find,
        _pa.widget_steps_done,
      ]) {
        final style = tester.widget<Text>(find.text(text)).style!;
        expect(style.letterSpacing ?? 0, 0, reason: text);
      }
    });
  });

  group('the picture', () {
    ImageProvider imageOf(WidgetTester tester) => tester
        .widget<Image>(find.descendant(
          of: find.byType(WidgetPicture),
          matching: find.byType(Image),
        ))
        .image;

    testWidgets('is the English render in English', (tester) async {
      await _pumpHome(tester);

      expect(
        (imageOf(tester) as AssetImage).assetName,
        'assets/images/widget_idle_en.png',
      );
    });

    testWidgets('is the Punjabi render in Punjabi', (tester) async {
      await _pumpHome(tester, locale: 'pa');

      expect(
        (imageOf(tester) as AssetImage).assetName,
        'assets/images/widget_idle_pa.png',
      );
    });

    test('both renders are bundled, as real PNG files', () async {
      for (final language in ['en', 'pa']) {
        final data =
            await rootBundle.load('assets/images/widget_idle_$language.png');
        // The 8 bytes that start every PNG file.
        expect(data.buffer.asUint8List(0, 8),
            [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
        expect(data.lengthInBytes, greaterThan(10000));
      }
    });
  });

  group('Punjabi', () {
    testWidgets('shows the card in Punjabi with no letter spacing', (
      tester,
    ) async {
      await _pumpHome(tester, locale: 'pa');

      for (final text in [
        _pa.widget_card_title,
        _pa.widget_card_add,
        _pa.widget_card_dismiss,
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
        final style = tester.widget<Text>(find.text(text)).style!;
        expect(style.letterSpacing ?? 0, 0, reason: text);
      }
      expect(_title, findsNothing);
    });
  });

  group('for a screen reader', () {
    testWidgets('the card says its title, and each button is a button', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpHome(tester);

      expect(find.bySemanticsLabel(_en.widget_card_add), findsOneWidget);
      expect(find.bySemanticsLabel(_en.widget_card_dismiss), findsOneWidget);
      expect(_title, findsOneWidget);
      handle.dispose();
    });
  });

  testWidgets('every Add widget button has a target of at least 44 points', (
    tester,
  ) async {
    await _pumpHome(tester);

    final add = tester.getSize(find
        .ancestor(
          of: _add,
          matching: find.byType(Container),
        )
        .first);
    final dismiss = tester.getSize(find
        .ancestor(
          of: _notNow,
          matching: find.byType(Container),
        )
        .first);
    expect(add.height, greaterThanOrEqualTo(44));
    expect(dismiss.height, greaterThanOrEqualTo(44));
  });

  testWidgets('the card is a widget of Home, not of another screen', (
    tester,
  ) async {
    await _pumpHome(tester);

    expect(
      find.descendant(
        of: find.byType(HomeScreen),
        matching: find.byType(WidgetCard),
      ),
      findsOneWidget,
    );
  });
}
