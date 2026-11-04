import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/reminder_controller.dart';
import 'package:live_darbar/src/core/store_links.dart';
import 'package:live_darbar/src/models/app_update.dart';
import 'package:live_darbar/src/models/reminder_settings.dart';
import 'package:live_darbar/src/views/app_router.dart';
import 'package:live_darbar/src/views/screens/home_screen.dart';
import 'package:live_darbar/src/views/screens/hukamnama_screen.dart';
import 'package:live_darbar/src/views/widgets/reminder_sheet.dart';
import 'package:live_darbar/src/views/widgets/update_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/app_harness.dart';
import '../support/fake_reminder_platform.dart';

/// A listener in Sydney in summer: 11 hours ahead of UTC, so 7:00 in Amritsar
/// is 12:30 on their clock.
Duration _sydneySummer(DateTime _) => const Duration(hours: 11);

const _update = AppUpdate(
  version: '3.1.0',
  build: 11,
  storeUrl: kPlayStoreUrl,
  notesEn: ['A new release.'],
  notesPa: ['ਨਵਾਂ ਰੀਲੀਜ਼।'],
);

/// The one question about the daily reminder. It comes the first time the
/// listener opens the Hukamnama reader, and never on Home.
///
/// This replaces the question on Home at launch. On the demo build the update
/// offer is on top at launch (it is a route on the navigator), and the launch
/// check saw a page over Home and gave up. Nothing asked again when the offer
/// closed, so the question never appeared.
void main() {
  late FakeReminderPlatform phone;
  final l10n = lookupAppLocalizations(const Locale('en'));

  Future<void> launch(
    WidgetTester tester, {
    String locale = 'en',
    AppUpdate? update,
    Duration settle = Duration.zero,
    Map<String, Object> prefs = const {},
  }) => pumpApp(
    tester,
    locale: locale,
    update: update,
    reminders: phone,
    reminderSettle: settle,
    prefs: prefs,
    localOffset: _sydneySummer,
  );

  // Home is under the reader once it opens, so it is off stage then.
  ProviderContainer container(WidgetTester tester) => ProviderScope.containerOf(
    tester.element(find.byType(HomeScreen, skipOffstage: false)),
    listen: false,
  );

  void background(WidgetTester tester) {
    for (final s in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
  }

  void foreground(WidgetTester tester) {
    for (final s in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
  }

  Future<ReminderSettings> state(WidgetTester tester) =>
      container(tester).read(reminderProvider.future);

  /// Opens the reader the way a tap on the Hukamnama card does, and lets the
  /// page slide in and the check run.
  Future<void> pushReader(WidgetTester tester) async {
    unawaited(
      Navigator.of(
        tester.element(find.byType(HomeScreen)),
      ).pushNamed(AppRoutes.hukamnama),
    );
    await tester.pump();
  }

  Future<void> openReader(WidgetTester tester) async {
    await pushReader(tester);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  Future<void> closeReader(WidgetTester tester) async {
    Navigator.of(tester.element(find.byType(HukamnamaScreen))).pop();
    await tester.pumpAndSettle();
  }

  setUp(() => phone = FakeReminderPlatform());

  group('on the reader, the first time', () {
    testWidgets('asks, and counts it as asked at once', (tester) async {
      await launch(tester);
      expect(await state(tester), isNot(predicate<ReminderSettings>((s) => s.asked)));

      await openReader(tester);

      expect(find.text(l10n.reminder_prompt_title), findsOneWidget);
      expect(
        find.text(
          l10n.reminder_prompt_body('7:00 AM in Amritsar, 12:30 PM here'),
        ),
        findsOneWidget,
        reason: 'Sydney in summer is 5.5 hours ahead of Amritsar',
      );
      expect(find.text(l10n.reminder_prompt_yes), findsOneWidget);
      expect(find.text(l10n.reminder_prompt_no), findsOneWidget);
      expect((await state(tester)).asked, isTrue,
          reason: 'a swipe away or a crash must not bring it back');
      expect(phone.calls, isNot(contains('request')),
          reason: 'the phone has not been asked');
    });

    testWidgets('Remind me asks the phone, sets 7:00 in Amritsar, and closes', (
      tester,
    ) async {
      await launch(tester);
      await openReader(tester);

      await tester.tap(find.text(l10n.reminder_prompt_yes));
      await tester.pumpAndSettle();

      expect(phone.calls, containsAllInOrder(['request', 'schedule 07:00 IST']));
      expect(find.byType(ReminderPrompt), findsNothing);
      expect((await state(tester)).enabled, isTrue);
    });

    testWidgets('Not now closes it, and it never asks again', (tester) async {
      await launch(tester);
      await openReader(tester);

      await tester.tap(find.text(l10n.reminder_prompt_no));
      await tester.pumpAndSettle();

      expect(find.byType(ReminderPrompt), findsNothing);
      expect(phone.calls, isNot(contains('request')));
      expect((await state(tester)).enabled, isFalse);

      await closeReader(tester);
      await openReader(tester);
      expect(find.byType(ReminderPrompt), findsNothing);
      expect((await state(tester)).asked, isTrue);
    });

    testWidgets('does not come back on the next launch', (tester) async {
      await launch(tester);
      await openReader(tester);
      await tester.tap(find.text(l10n.reminder_prompt_no));
      await tester.pumpAndSettle();

      // A new process: new providers, the saved settings.
      final saved = (await SharedPreferences.getInstance());
      await tester.pumpWidget(const SizedBox());
      await launch(
        tester,
        prefs: {for (final k in saved.getKeys()) k: saved.get(k)!},
      );
      await openReader(tester);

      expect(find.byType(ReminderPrompt), findsNothing);
    });

    testWidgets('a tap on the dimmed area means not now', (tester) async {
      await launch(tester);
      await openReader(tester);

      await tester.tapAt(const Offset(20, 40));
      await tester.pumpAndSettle();

      expect(find.byType(ReminderPrompt), findsNothing);
      await closeReader(tester);
      await openReader(tester);
      expect(find.byType(ReminderPrompt), findsNothing);
      expect(phone.calls, isNot(contains('request')));
    });

    testWidgets('a swipe down means not now', (tester) async {
      await launch(tester);
      await openReader(tester);

      await tester.drag(
        find.text(l10n.reminder_prompt_title),
        const Offset(0, 600),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(find.byType(ReminderPrompt), findsNothing);
      await closeReader(tester);
      await openReader(tester);
      expect(find.byType(ReminderPrompt), findsNothing);
    });

    testWidgets('says why when the phone does not allow notifications', (
      tester,
    ) async {
      phone.allowed = false;
      await launch(tester);
      await openReader(tester);

      await tester.tap(find.text(l10n.reminder_prompt_yes));
      await tester.pumpAndSettle();

      expect(find.text(l10n.reminder_blocked_hint), findsOneWidget);
      expect(find.text(l10n.reminder_prompt_yes), findsNothing);
      expect(find.text(l10n.reminder_prompt_no), findsNothing);
      expect(phone.scheduled, isNull);

      await tester.tap(find.text(l10n.reminder_done));
      await tester.pumpAndSettle();
      expect(find.byType(ReminderPrompt), findsNothing);
      final s = await state(tester);
      expect(s.enabled, isFalse);
      expect(s.asked, isTrue);
    });

    testWidgets('says so when the phone cannot set the reminder', (
      tester,
    ) async {
      phone.scheduleError = StateError('no');
      await launch(tester);
      await openReader(tester);

      await tester.tap(find.text(l10n.reminder_prompt_yes));
      await tester.pumpAndSettle();

      expect(find.text(l10n.reminder_failed_hint), findsOneWidget);
    });
  });

  group('never on Home', () {
    testWidgets('asks nothing at launch, however long Home stays open', (
      tester,
    ) async {
      await launch(tester);

      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      expect(find.byType(ReminderPrompt), findsNothing);
      expect((await state(tester)).asked, isFalse);
    });

    testWidgets('asks nothing when the app comes back to the front', (
      tester,
    ) async {
      await launch(tester);
      background(tester);
      foreground(tester);

      await tester.pump(const Duration(seconds: 10));

      expect(find.byType(ReminderPrompt), findsNothing);
      expect((await state(tester)).asked, isFalse);
    });
  });

  group('the bug: no question while the update offer is up', () {
    testWidgets(
      'the update offer at launch does not cost the question, which comes on '
      'the reader',
      (tester) async {
        await launch(tester, update: _update);
        await tester.pump(const Duration(seconds: 2));
        expect(find.text('A new release.'), findsOneWidget, reason: 'offer is up');

        // The listener answers the offer, then opens the Hukamnama.
        await tester.tap(find.text(l10n.update_later));
        await tester.pumpAndSettle();
        expect(find.byType(ReminderPrompt), findsNothing);
        await openReader(tester);

        expect(find.byType(ReminderPrompt), findsOneWidget);
      },
    );

    testWidgets('a sheet over the reader is waited out, not skipped', (
      tester,
    ) async {
      await launch(tester, settle: const Duration(seconds: 1));
      await pushReader(tester);
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(ReminderPrompt), findsNothing, reason: 'still settling');

      // The offer arrives late and opens over the reader, as Home's listener
      // does.
      unawaited(showUpdateSheet(
        tester.element(find.byType(HomeScreen, skipOffstage: false)),
        _update,
      ));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('A new release.'), findsOneWidget);
      expect(find.byType(ReminderPrompt), findsNothing);
      expect((await state(tester)).asked, isFalse,
          reason: 'the one question must not be spent under another sheet');

      await tester.tap(find.text(l10n.update_later));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(find.byType(ReminderPrompt), findsOneWidget);
    });
  });

  group('when it does not ask', () {
    testWidgets('on a platform that cannot remind', (tester) async {
      phone.supported = false;
      await launch(tester);
      await openReader(tester);

      expect(find.byType(ReminderPrompt), findsNothing);
      expect((await state(tester)).asked, isFalse);
    });

    testWidgets('after the listener answered', (tester) async {
      await launch(
        tester,
        prefs: {'reminder_asked': true, 'reminder_enabled': true},
      );
      await openReader(tester);

      expect(find.byType(ReminderPrompt), findsNothing);
    });

    testWidgets('with the app off screen, and asks when it is back', (
      tester,
    ) async {
      await launch(tester);
      background(tester);
      await openReader(tester);

      expect(find.byType(ReminderPrompt), findsNothing);
      expect((await state(tester)).asked, isFalse,
          reason: 'the one question must not be spent unseen');

      foreground(tester);
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await tester.pumpAndSettle();
      expect(find.byType(ReminderPrompt), findsOneWidget);
    });

    testWidgets('twice when two checks run together', (tester) async {
      await launch(tester);
      await openReader(tester);
      // The first check has the question open. A second reader cannot exist,
      // but a second check on the same context must not ask again.
      final reader = tester.element(find.byType(HukamnamaScreen));
      expect(find.byType(ReminderPrompt), findsOneWidget);
      expect(await askAboutReminderOnFirstOpen(reader), isFalse);
    });
  });

  testWidgets('waits for the page to settle before it appears', (tester) async {
    await launch(tester, settle: const Duration(seconds: 1));

    await pushReader(tester);
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byType(ReminderPrompt), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(ReminderPrompt), findsOneWidget);
  });

  testWidgets('shows under Reduce Motion, as a fade', (tester) async {
    reduceMotion(tester);
    await launch(tester);

    await openReader(tester);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(ReminderPrompt), findsOneWidget);
    expect(find.text(l10n.reminder_prompt_title), findsOneWidget);
  });

  testWidgets('has labelled targets of at least 48 points', (tester) async {
    final semantics = tester.ensureSemantics();
    await launch(tester);
    await openReader(tester);

    expect(find.bySemanticsLabel(l10n.reminder_prompt_yes), findsOneWidget);
    expect(find.bySemanticsLabel(l10n.reminder_prompt_no), findsOneWidget);
    expect(
      tester.getSize(find.bySemanticsLabel(l10n.reminder_prompt_yes)).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.bySemanticsLabel(l10n.reminder_prompt_no)).height,
      greaterThanOrEqualTo(48),
    );
    semantics.dispose();
  });

  for (final locale in ['en', 'pa']) {
    testWidgets('reads in $locale', (tester) async {
      final text = lookupAppLocalizations(Locale(locale));
      await launch(tester, locale: locale);

      await openReader(tester);

      expect(find.text(text.reminder_prompt_title), findsOneWidget);
      expect(find.text(text.reminder_prompt_yes), findsOneWidget);
      expect(find.text(text.reminder_prompt_no), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'no overflow');
    });
  }
}
