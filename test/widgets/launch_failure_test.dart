import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/bootstrap.dart';
import 'package:live_darbar/src/core/text_scale.dart';

import '../support/load_fonts.dart';

/// A start-up that fails must not leave a blank screen. Before the first frame
/// the phone shows the splash for ever, and a build that fails in the first
/// frame shows a grey box in a release build. Both end on a calm screen with
/// a Retry.
void main() {
  setUpAll(loadAppFonts);

  final en = lookupAppLocalizations(const Locale('en'));
  final pa = lookupAppLocalizations(const Locale('pa'));

  /// Puts [app] on screen, as `runApp` does, in the test's own binding.
  void launch(WidgetTester tester, Widget app) {
    tester.binding.attachRootWidget(tester.binding.wrapWithDefaultView(app));
  }

  Future<void> start(
    WidgetTester tester, {
    required Future<String> Function() prepare,
    required Widget Function(String) build,
  }) async {
    await bootstrap<String>(
      prepare: prepare,
      build: build,
      launch: (app) => launch(tester, app),
    );
    await tester.pump();
  }

  const app = Text('The app', textDirection: TextDirection.ltr);
  Finder failure() => find.text(en.launch_failed_title);

  group('when the work before the first frame fails', () {
    testWidgets('a calm screen replaces the blank one, in both languages', (
      tester,
    ) async {
      await start(
        tester,
        prepare: () async => throw StateError('no audio'),
        build: (_) => app,
      );

      expect(failure(), findsOneWidget);
      expect(find.text(en.launch_failed_body), findsOneWidget);
      expect(find.text(pa.launch_failed_title), findsOneWidget);
      expect(find.text(pa.launch_failed_body), findsOneWidget);
      expect(find.text('The app'), findsNothing);
    });

    testWidgets('it names no exception and no stack', (tester) async {
      await start(
        tester,
        prepare: () async => throw StateError('secret detail'),
        build: (_) => app,
      );

      expect(find.textContaining('secret detail'), findsNothing);
      expect(find.textContaining('StateError'), findsNothing);
    });

    testWidgets('Retry works the start-up again, and the app comes up', (
      tester,
    ) async {
      var tries = 0;
      await start(
        tester,
        prepare: () async {
          tries++;
          if (tries == 1) throw StateError('first time');
          return 'ready';
        },
        build: (_) => app,
      );

      await tester.tap(find.bySemanticsLabel(RegExp('^${en.retry}')));
      await tester.pump();
      await tester.pump();

      expect(tries, 2);
      expect(find.text('The app'), findsOneWidget);
      expect(failure(), findsNothing);
    });

    testWidgets('Retry that fails again shows the same screen again', (
      tester,
    ) async {
      var tries = 0;
      await start(
        tester,
        prepare: () async {
          tries++;
          throw StateError('still broken');
        },
        build: (_) => app,
      );

      await tester.tap(find.bySemanticsLabel(RegExp('^${en.retry}')));
      await tester.pump();
      await tester.pump();

      expect(tries, 2);
      expect(failure(), findsOneWidget);
    });

    testWidgets('a build that throws at once is the same failure', (
      tester,
    ) async {
      await start(
        tester,
        prepare: () async => 'ready',
        build: (_) => throw StateError('no widget'),
      );

      expect(failure(), findsOneWidget);
    });
  });

  group('when the first frame fails', () {
    Widget broken() => Builder(
          builder: (_) => throw StateError('home would not build'),
        );

    testWidgets('a calm screen replaces the grey box', (tester) async {
      await start(tester, prepare: () async => 'ready', build: (_) => broken());
      await tester.pump();

      expect(tester.takeException(), isStateError);
      expect(failure(), findsOneWidget);
    });

    testWidgets('Retry builds the app again and does not prepare again', (
      tester,
    ) async {
      var prepared = 0;
      var built = 0;
      await start(
        tester,
        prepare: () async {
          prepared++;
          return 'ready';
        },
        build: (_) => ++built == 1 ? broken() : app,
      );
      await tester.pump();
      expect(tester.takeException(), isStateError);

      await tester.tap(find.bySemanticsLabel(RegExp('^${en.retry}')));
      await tester.pump();
      await tester.pump();

      expect(prepared, 1, reason: 'the audio session starts once');
      expect(built, 2);
      expect(find.text('The app'), findsOneWidget);
    });

    testWidgets('the error widget is the default again afterwards', (
      tester,
    ) async {
      final before = ErrorWidget.builder;
      await start(tester, prepare: () async => 'ready', build: (_) => app);
      await tester.pump();

      expect(ErrorWidget.builder, same(before));
    });

    testWidgets('a widget that breaks later does not replace the app', (
      tester,
    ) async {
      late StateSetter rebuild;
      var broken = false;
      await start(
        tester,
        prepare: () async => 'ready',
        build: (_) => StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return broken
                ? throw StateError('a tile broke')
                : const Text('The app', textDirection: TextDirection.ltr);
          },
        ),
      );
      await tester.pump();
      expect(find.text('The app'), findsOneWidget);

      rebuild(() => broken = true);
      await tester.pump();

      expect(tester.takeException(), isStateError);
      expect(failure(), findsNothing, reason: 'the app was up already');
    });
  });

  group('the screen', () {
    for (final scale in [1.0, kMaxTextScale, 3.0]) {
      testWidgets('fits a phone at text size $scale', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        await start(
          tester,
          prepare: () async => throw StateError('x'),
          build: (_) => app,
        );

        expect(tester.takeException(), isNull, reason: 'no overflow');
        expect(failure(), findsOneWidget);
        // The button is on screen, not scrolled out of reach.
        final retry = find.bySemanticsLabel(RegExp('^${en.retry}'));
        expect(tester.getRect(retry).bottom, lessThanOrEqualTo(1920 / 3));
      });
    }

    testWidgets('has a Retry that is a button for a screen reader', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await start(
        tester,
        prepare: () async => throw StateError('x'),
        build: (_) => app,
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('^${en.retry}'))),
        matchesSemantics(
          label: '${en.retry} · ${pa.retry}',
          isButton: true,
          hasTapAction: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
      handle.dispose();
    });
  });
}
