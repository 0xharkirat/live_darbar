import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/views/widgets/error_view.dart';

import '../support/load_fonts.dart';

/// A widget that fails to build used to leave a grey box in a release build,
/// and Flutter's red screen in a debug build. Release gets a small, calm box
/// in both languages. Debug keeps the red screen, because a developer needs
/// the message.

class _Broken extends StatelessWidget {
  const _Broken();

  @override
  Widget build(BuildContext context) => throw StateError('secret detail');
}

void main() {
  setUpAll(loadAppFonts);

  final en = lookupAppLocalizations(const Locale('en'));
  final pa = lookupAppLocalizations(const Locale('pa'));

  late FlutterExceptionHandler? onError;

  /// A test that runs with the release view installed. The binding checks
  /// the builder at the end of the test body, so it is put back here.
  void release(
    String name,
    Future<void> Function(WidgetTester tester) body,
  ) {
    testWidgets(name, (tester) async {
      final builder = ErrorWidget.builder;
      installErrorView(debug: false);
      try {
        await body(tester);
      } finally {
        ErrorWidget.builder = builder;
      }
    });
  }

  setUp(() => onError = FlutterError.onError);
  tearDown(() => FlutterError.onError = onError);

  Future<void> pumpBroken(WidgetTester tester, {Widget? around}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: around ?? const Center(child: _Broken())),
      ),
    );
    // The test binding keeps the build error for the test to look at.
    expect(tester.takeException(), isA<StateError>());
  }

  group('in a release build', () {
    release('the part that broke says so, in both languages', (
      tester,
    ) async {
      await pumpBroken(tester);

      expect(find.text(en.error_view_title), findsOneWidget);
      expect(find.text(pa.error_view_title), findsOneWidget);
    });

    release('it names no exception, no stack and no file', (tester) async {
      await pumpBroken(tester);

      expect(find.textContaining('secret detail'), findsNothing);
      expect(find.textContaining('StateError'), findsNothing);
      expect(find.textContaining('.dart'), findsNothing);
    });

    release('the rest of the screen stays', (tester) async {
      await pumpBroken(
        tester,
        around: const Column(
          children: [Text('Above'), _Broken(), Text('Below')],
        ),
      );

      expect(find.text('Above'), findsOneWidget);
      expect(find.text('Below'), findsOneWidget);
      expect(find.text(en.error_view_title), findsOneWidget);
    });

    release('the box is small, not a whole screen', (tester) async {
      await pumpBroken(tester);

      // The view centres its box in the space it is given. The box is small.
      final box = tester.getSize(
        find.descendant(
          of: find.byType(ErrorView),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect(box.width, lessThan(300));
      expect(box.height, lessThan(120));
    });

    release('it fits where a list gives it no height limit', (tester) async {
      await pumpBroken(
        tester,
        around: ListView(children: const [_Broken(), Text('Next')]),
      );

      expect(find.text(en.error_view_title), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
    });

    release('it fits where a row gives it no width limit', (tester) async {
      await pumpBroken(
        tester,
        around: const Row(children: [_Broken(), Text('Beside')]),
      );

      expect(find.text('Beside'), findsOneWidget);
    });

    release('it does not overflow in a tiny space', (tester) async {
      await pumpBroken(
        tester,
        around: const Center(
          child: SizedBox(width: 40, height: 20, child: _Broken()),
        ),
      );

      // An overflow would be a second exception.
      expect(tester.takeException(), isNull);
    });

    release('it works above the app, where there is no theme', (
      tester,
    ) async {
      await tester.pumpWidget(const _Broken());

      expect(tester.takeException(), isA<StateError>());
      expect(find.text(en.error_view_title), findsOneWidget);
    });
  });

  group('in a debug build', () {
    testWidgets('the builder is Flutter\'s own, with its red screen', (
      tester,
    ) async {
      final before = ErrorWidget.builder;
      addTearDown(() => ErrorWidget.builder = before);

      installErrorView(debug: true);

      expect(ErrorWidget.builder, same(before));
    });

    testWidgets('a broken widget shows the message to the developer', (
      tester,
    ) async {
      await pumpBroken(tester);

      expect(find.byType(ErrorView), findsNothing);
      expect(find.byType(ErrorWidget), findsOneWidget);
    });
  });

  test('a debug run is a debug run', () => expect(kDebugMode, isTrue));
}
