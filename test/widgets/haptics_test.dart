import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/views/app_router.dart';
import 'package:live_darbar/src/views/screens/hukamnama_screen.dart';
import 'package:live_darbar/src/views/widgets/reminder_bell.dart';

import '../support/app_harness.dart';
import '../support/fake_reminder_platform.dart';

/// A small tick under the thumb for 3 choices, and nowhere else: the language
/// switch, the reader's meaning toggle and its A- and A+ buttons. A tick on
/// every tap would turn into noise, and the play buttons, the source switcher
/// and the sound quality choices already have theirs.
void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  /// Every haptic the app asks the phone for, as its type.
  List<String> haptics(WidgetTester tester) {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          calls.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    return calls;
  }

  const tick = 'HapticFeedbackType.selectionClick';

  Future<void> openReader(WidgetTester tester) async {
    await pumpApp(tester, initialRoute: AppRoutes.hukamnama);
    await tester.pumpAndSettle();
    expect(find.byType(HukamnamaScreen), findsOneWidget);
  }

  group('the language switch', () {
    testWidgets('ticks when the other language is chosen', (tester) async {
      final calls = haptics(tester);
      await pumpApp(tester);

      await tester.tap(find.text('ਪੰਜਾਬੀ'));
      await tester.pump();

      expect(calls, [tick]);
    });

    testWidgets('is quiet for the language already chosen', (tester) async {
      final calls = haptics(tester);
      await pumpApp(tester);

      await tester.tap(find.text('English'));
      await tester.pump();

      expect(calls, isEmpty);
    });

    testWidgets('ticks in About too, where the same switch sits', (
      tester,
    ) async {
      final calls = haptics(tester);
      await pumpApp(tester, initialRoute: AppRoutes.about);
      await tester.pumpAndSettle();

      await tester.tap(find.text('ਪੰਜਾਬੀ'));
      await tester.pump();

      expect(calls, [tick]);
    });
  });

  group('the meaning toggle', () {
    Finder option(String label) => find.descendant(
          of: find.byType(HukamnamaScreen),
          matching: find.text(label),
        );

    Future<void> showToggle(WidgetTester tester) => tester.scrollUntilVisible(
          option('ਪੰਜਾਬੀ'),
          300,
          scrollable: find.byType(Scrollable).first,
        );

    testWidgets('ticks when the other language is chosen', (tester) async {
      await openReader(tester);
      await showToggle(tester);
      final calls = haptics(tester);

      await tester.tap(option('ਪੰਜਾਬੀ'));
      await tester.pump();

      expect(calls, [tick]);
    });

    testWidgets('is quiet for the language already chosen', (tester) async {
      await openReader(tester);
      await showToggle(tester);
      final calls = haptics(tester);

      await tester.tap(option('English'));
      await tester.pump();

      expect(calls, isEmpty);
    });
  });

  group('the text size buttons', () {
    testWidgets('A+ ticks, and A- ticks once it can shrink', (tester) async {
      await openReader(tester);
      final calls = haptics(tester);

      await tester.tap(find.text('A+'));
      await tester.pump();
      expect(calls, [tick]);

      await tester.tap(find.text('A−'));
      await tester.pump();
      expect(calls, [tick, tick]);
    });

    testWidgets('A- is quiet at the smallest size', (tester) async {
      await openReader(tester);
      final calls = haptics(tester);

      await tester.tap(find.text('A−'));
      await tester.pump();

      expect(calls, isEmpty, reason: 'it is already the smallest');
    });

    testWidgets('A+ is quiet at the largest size', (tester) async {
      await openReader(tester);
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.text('A+'));
        await tester.pump();
      }
      final calls = haptics(tester);

      await tester.tap(find.text('A+'));
      await tester.pump();

      expect(calls, isEmpty, reason: 'it is already the largest');
    });
  });

  group('nowhere else', () {
    testWidgets('opening a page is quiet', (tester) async {
      final calls = haptics(tester);
      await pumpApp(tester);

      await tester.tap(find.text(l10n.about_this_app));
      await tester.pumpAndSettle();

      expect(calls, isEmpty);
    });

    testWidgets('the reminder bell is quiet', (tester) async {
      await pumpApp(
        tester,
        initialRoute: AppRoutes.hukamnama,
        reminders: FakeReminderPlatform(),
        prefs: const {'reminder_asked': true},
      );
      await tester.pumpAndSettle();
      final calls = haptics(tester);

      await tester.tap(find.byType(ReminderBell));
      await tester.pumpAndSettle();

      expect(calls, isEmpty);
    });
  });
}
