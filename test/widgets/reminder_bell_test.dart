import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/reminder_controller.dart';
import 'package:live_darbar/src/models/reminder_time.dart';
import 'package:live_darbar/src/views/app_router.dart';
import 'package:live_darbar/src/views/screens/home_screen.dart';
import 'package:live_darbar/src/views/screens/hukamnama_screen.dart';
import 'package:live_darbar/src/views/widgets/reminder_bell.dart';
import 'package:live_darbar/src/views/widgets/reminder_sheet.dart';

import '../support/app_harness.dart';
import '../support/fake_reminder_platform.dart';
import '../support/load_fonts.dart';

/// The bell in the top bar of the Hukamnama screen: the always-there way to
/// set the daily reminder up, or to change it, after the first question.
void main() {
  // The real fonts, because the largest text size is a question of whether
  // text fits on a phone. The test font is about 1.7 times as wide as Geist.
  setUpAll(loadAppFonts);

  late FakeReminderPlatform phone;
  final l10n = lookupAppLocalizations(const Locale('en'));

  /// A listener in Sydney in summer: 7:00 in Amritsar is 12:30 here.
  Duration sydney(DateTime _) => const Duration(hours: 11);

  /// The reader, open over Home, for a listener who has been asked already
  /// (unless [asked] is false).
  Future<void> openReader(
    WidgetTester tester, {
    String locale = 'en',
    bool asked = true,
    Map<String, Object> prefs = const {},
  }) async {
    await pumpApp(
      tester,
      locale: locale,
      reminders: phone,
      localOffset: sydney,
      prefs: {if (asked) 'reminder_asked': true, ...prefs},
    );
    unawaited(
      Navigator.of(
        tester.element(find.byType(HomeScreen)),
      ).pushNamed(AppRoutes.hukamnama),
    );
    await tester.pumpAndSettle();
  }

  ProviderContainer container(WidgetTester tester) => ProviderScope.containerOf(
        tester.element(find.byType(HukamnamaScreen)),
        listen: false,
      );

  Finder bell() => find.byType(ReminderBell);
  Finder bellIcon(IconData icon) =>
      find.descendant(of: bell(), matching: find.byIcon(icon));

  setUp(() => phone = FakeReminderPlatform());

  testWidgets('is in the top bar, next to the reading options', (
    tester,
  ) async {
    await openReader(tester);

    expect(bell(), findsOneWidget);
    expect(bellIcon(CupertinoIcons.bell), findsOneWidget);
    final bellBox = tester.getRect(bell());
    final larger = tester.getRect(find.byKey(const ValueKey('reader-options')));
    expect(bellBox.right, lessThanOrEqualTo(larger.left), reason: 'before Aa');
    expect(
      (bellBox.center.dy - larger.center.dy).abs(),
      lessThan(4),
      reason: 'on the same line',
    );
  });

  testWidgets('is there for a listener who said not now', (tester) async {
    await openReader(tester, asked: false);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.reminder_prompt_no));
    await tester.pumpAndSettle();

    expect(bell(), findsOneWidget);
  });

  testWidgets('is not there where the phone cannot remind', (tester) async {
    phone.supported = false;
    await openReader(tester);

    expect(bell(), findsOneWidget, reason: 'the widget is in the bar');
    expect(find.byIcon(CupertinoIcons.bell), findsNothing);
    expect(find.byIcon(CupertinoIcons.bell_fill), findsNothing);
  });

  testWidgets('is a labelled button of 44 points, off or on', (tester) async {
    final semantics = tester.ensureSemantics();
    await openReader(tester);

    var node =
        tester.getSemantics(find.bySemanticsLabel(l10n.reminder_setting));
    expect(node.label, l10n.reminder_setting);
    expect(node.value, l10n.reminder_off);
    expect(tester.getSize(find.bySemanticsLabel(l10n.reminder_setting)).height,
        greaterThanOrEqualTo(44));

    await container(tester).read(reminderProvider.notifier).turnOn();
    await tester.pumpAndSettle();

    node = tester.getSemantics(find.bySemanticsLabel(l10n.reminder_setting));
    expect(node.value, l10n.reminder_on);
    semantics.dispose();
  });

  group('when the reminder is off', () {
    testWidgets('opens the question, and Remind me turns it on',
        (tester) async {
      await openReader(tester);

      await tester.tap(bell());
      await tester.pumpAndSettle();

      expect(find.text(l10n.reminder_prompt_title), findsOneWidget);
      expect(find.text(l10n.reminder_prompt_yes), findsOneWidget);
      expect(find.text(l10n.reminder_prompt_no), findsOneWidget);

      await tester.tap(find.text(l10n.reminder_prompt_yes));
      await tester.pumpAndSettle();

      expect(phone.scheduled, ReminderTime.standard);
      expect(bellIcon(CupertinoIcons.bell_fill), findsOneWidget,
          reason: 'a filled bell says the reminder is on');
    });

    testWidgets('Not now closes it and changes nothing', (tester) async {
      await openReader(tester);

      await tester.tap(bell());
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.reminder_prompt_no));
      await tester.pumpAndSettle();

      expect(find.byType(ReminderPrompt), findsNothing);
      expect(phone.calls, isNot(contains('request')));
      expect(bellIcon(CupertinoIcons.bell), findsOneWidget);
    });
  });

  group('when the reminder is on', () {
    const on = {'reminder_enabled': true};

    testWidgets('shows a filled bell, and when it comes', (tester) async {
      await openReader(tester, prefs: on);

      expect(bellIcon(CupertinoIcons.bell_fill), findsOneWidget);

      await tester.tap(bell());
      await tester.pumpAndSettle();

      expect(
        find.text(
          l10n.reminder_on_body('7:00 AM in Amritsar, 12:30 PM here'),
        ),
        findsOneWidget,
      );
      expect(find.text(l10n.reminder_change_time), findsOneWidget);
      expect(find.text(l10n.reminder_turn_off), findsOneWidget);
      expect(find.text(l10n.reminder_prompt_yes), findsNothing);
    });

    testWidgets('Turn off removes the reminder and closes the sheet', (
      tester,
    ) async {
      await openReader(tester, prefs: on);
      await tester.tap(bell());
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.reminder_turn_off));
      await tester.pumpAndSettle();

      expect(phone.calls, contains('cancel'));
      expect(find.byType(ReminderPrompt), findsNothing);
      expect(bellIcon(CupertinoIcons.bell), findsOneWidget);
    });

    testWidgets('Change time opens the wheel, and a pick moves the reminder', (
      tester,
    ) async {
      await openReader(tester, prefs: on);
      await tester.tap(bell());
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.reminder_change_time));
      await tester.pumpAndSettle();

      expect(find.byType(ReminderPrompt), findsNothing);
      expect(find.byType(CupertinoDatePicker), findsOneWidget);
      final picker = tester.widget<CupertinoDatePicker>(
        find.byType(CupertinoDatePicker),
      );
      expect(
        [picker.initialDateTime.hour, picker.initialDateTime.minute],
        [12, 30],
        reason: 'the wheel starts at 7:00 in Amritsar on a Sydney clock',
      );
      picker.onDateTimeChanged(DateTime(2026, 1, 1, 5, 45));
      await tester.tap(find.text(l10n.reminder_done));
      await tester.pumpAndSettle();

      expect(phone.scheduled, const ReminderTime(5, 45));
    });

    testWidgets('says so when the phone has blocked notifications', (
      tester,
    ) async {
      phone.allowed = false;
      await openReader(tester, prefs: on);
      await container(tester).read(reminderProvider.notifier).resync();
      await tester.pumpAndSettle();

      await tester.tap(bell());
      await tester.pumpAndSettle();

      expect(find.text(l10n.reminder_blocked_hint), findsOneWidget);
    });

    testWidgets('keeps the same sheet while Turn off works', (tester) async {
      await openReader(tester, prefs: on);
      await tester.tap(bell());
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.reminder_turn_off));
      await tester.pump(const Duration(milliseconds: 100));

      // Mid-close the sheet still has the on-state buttons, not the question.
      expect(find.text(l10n.reminder_prompt_yes), findsNothing);
      await tester.pumpAndSettle();
    });
  });

  for (final locale in ['en', 'pa']) {
    testWidgets('reads in $locale at the largest text size', (tester) async {
      final text = lookupAppLocalizations(Locale(locale));
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await openReader(tester, locale: locale, prefs: const {});
      await tester.tap(bell());
      await tester.pumpAndSettle();

      expect(find.text(text.reminder_prompt_title), findsOneWidget);
      expect(find.text(text.reminder_prompt_yes), findsOneWidget);
      expect(
        tester.takeException(),
        isNull,
        reason: 'no overflow in Home, the reader or the sheet',
      );
    });
  }
}
