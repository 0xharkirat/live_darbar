import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/locale_controller.dart';
import 'package:live_darbar/src/controllers/reminder_controller.dart';
import 'package:live_darbar/src/core/app_theme.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/models/reminder_settings.dart';
import 'package:live_darbar/src/services/reminder_platform.dart';
import 'package:live_darbar/src/views/widgets/reminder_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/app_harness.dart' show reduceMotion;
import '../support/fake_reminder_platform.dart';

class _Locale extends LocaleController {
  _Locale(this.locale);

  final String locale;

  @override
  String build() => locale;
}

/// The one question about the daily reminder, and when it is right to ask.
void main() {
  final navigatorKey = GlobalKey<NavigatorState>();
  late FakeReminderPlatform phone;
  late ProviderContainer container;

  Future<void> pump(
    WidgetTester tester, {
    String locale = 'en',
    double textScale = 1,
  }) async {
    AppType.tracking = locale != 'pa';
    addTearDown(() => AppType.tracking = true);
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    container = ProviderContainer(
      retry: (_, __) => null,
      overrides: [
        reminderPlatformProvider.overrideWithValue(phone),
        localeController.overrideWith(() => _Locale(locale)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          theme: AppTheme.material,
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: const Scaffold(body: Text('home')),
        ),
      ),
    );
  }

  /// Runs the check the app runs at launch. The result arrives when the sheet
  /// closes, or at once when nothing is shown.
  Future<bool> ask(
    WidgetTester tester, {
    bool foreground = true,
    Duration settle = Duration.zero,
  }) async {
    final result = showReminderPromptIfNeeded(
      container: container,
      navigatorKey: navigatorKey,
      settle: settle,
      isForeground: () => foreground,
    );
    var shown = false;
    var done = false;
    // ignore: unawaited_futures
    result.then((value) {
      shown = value;
      done = true;
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 400));
    if (!find.byType(ReminderPrompt).evaluate().isNotEmpty) {
      // Not shown: the check has ended by now.
      expect(done, isTrue,
          reason: 'the check should end when it shows nothing');
    }
    return shown;
  }

  Future<ReminderSettings> state() => container.read(reminderProvider.future);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    phone = FakeReminderPlatform();
  });

  final l10n = lookupAppLocalizations(const Locale('en'));

  testWidgets('asks on the first launch, and counts it as asked at once', (
    tester,
  ) async {
    await pump(tester);

    await ask(tester);

    expect(find.text(l10n.reminder_prompt_title), findsOneWidget);
    expect(
      find.text(
        l10n.reminder_prompt_body('7:00 AM'),
      ),
      findsOneWidget,
    );
    expect(find.text(l10n.reminder_prompt_yes), findsOneWidget);
    expect(find.text(l10n.reminder_prompt_no), findsOneWidget);
    expect((await state()).asked, isTrue,
        reason: 'a swipe away or a crash must not bring it back');
    expect(phone.calls, isEmpty, reason: 'the phone has not been asked');
  });

  testWidgets('Remind me asks the phone, sets 7:00 and closes', (tester) async {
    await pump(tester);
    await ask(tester);

    await tester.tap(find.text(l10n.reminder_prompt_yes));
    await tester.pumpAndSettle();

    expect(phone.calls, ['request', 'schedule 07:00']);
    expect(find.byType(ReminderPrompt), findsNothing);
    final s = await state();
    expect(s.enabled, isTrue);
  });

  testWidgets('Not now closes it and the question never comes back', (
    tester,
  ) async {
    await pump(tester);
    await ask(tester);

    await tester.tap(find.text(l10n.reminder_prompt_no));
    await tester.pumpAndSettle();

    expect(find.byType(ReminderPrompt), findsNothing);
    expect(phone.calls, isEmpty);
    expect((await state()).enabled, isFalse);

    expect(await ask(tester), isFalse);
    expect(find.byType(ReminderPrompt), findsNothing);
  });

  testWidgets('does not come back on the next launch either', (tester) async {
    await pump(tester);
    await ask(tester);
    await tester.tap(find.text(l10n.reminder_prompt_no));
    await tester.pumpAndSettle();

    // A new process: new providers, the same saved settings.
    await tester.pumpWidget(const SizedBox());
    await pump(tester);

    expect(await ask(tester), isFalse);
    expect(find.byType(ReminderPrompt), findsNothing);
  });

  testWidgets('a tap on the dimmed area means not now', (tester) async {
    await pump(tester);
    await ask(tester);

    await tester.tapAt(const Offset(20, 40));
    await tester.pumpAndSettle();

    expect(find.byType(ReminderPrompt), findsNothing);
    expect(await ask(tester), isFalse);
    expect(phone.calls, isEmpty);
  });

  testWidgets('a swipe down means not now', (tester) async {
    await pump(tester);
    await ask(tester);

    await tester.drag(
      find.text(l10n.reminder_prompt_title),
      const Offset(0, 600),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(find.byType(ReminderPrompt), findsNothing);
    expect(await ask(tester), isFalse);
  });

  testWidgets('says why when the phone does not allow notifications', (
    tester,
  ) async {
    phone.allowed = false;
    await pump(tester);
    await ask(tester);

    await tester.tap(find.text(l10n.reminder_prompt_yes));
    await tester.pumpAndSettle();

    expect(find.text(l10n.reminder_blocked_hint), findsOneWidget);
    expect(find.text(l10n.reminder_prompt_yes), findsNothing);
    expect(find.text(l10n.reminder_prompt_no), findsNothing);
    expect(phone.scheduled, isNull);

    await tester.tap(find.text(l10n.reminder_done));
    await tester.pumpAndSettle();
    expect(find.byType(ReminderPrompt), findsNothing);
    final s = await state();
    expect(s.enabled, isFalse);
    expect(s.asked, isTrue);
    expect(await ask(tester), isFalse, reason: 'it never asks again');
  });

  testWidgets('says so when the phone cannot set the reminder', (tester) async {
    phone.scheduleError = StateError('no');
    await pump(tester);
    await ask(tester);

    await tester.tap(find.text(l10n.reminder_prompt_yes));
    await tester.pumpAndSettle();

    expect(find.text(l10n.reminder_failed_hint), findsOneWidget);
  });

  group('when it does not ask', () {
    testWidgets('on a platform that cannot remind', (tester) async {
      phone.supported = false;
      await pump(tester);

      expect(await ask(tester), isFalse);

      expect(find.byType(ReminderPrompt), findsNothing);
      expect((await state()).asked, isFalse);
    });

    testWidgets('after the listener answered in About', (tester) async {
      SharedPreferences.setMockInitialValues({
        'reminder_asked': true,
        'reminder_enabled': true,
      });
      await pump(tester);

      expect(await ask(tester), isFalse);
      expect(find.byType(ReminderPrompt), findsNothing);
    });

    testWidgets('with the app off screen, and asks when it is back', (
      tester,
    ) async {
      await pump(tester);

      expect(await ask(tester, foreground: false), isFalse);
      expect((await state()).asked, isFalse,
          reason: 'the one question must not be spent unseen');

      await ask(tester);
      expect(find.byType(ReminderPrompt), findsOneWidget);
    });

    testWidgets('over a page the listener is on, and asks once it is gone', (
      tester,
    ) async {
      await pump(tester);
      navigatorKey.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Text('reader')),
      );
      await tester.pumpAndSettle();

      expect(await ask(tester), isFalse);
      expect(find.byType(ReminderPrompt), findsNothing);
      expect((await state()).asked, isFalse);

      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      await ask(tester);
      expect(find.byType(ReminderPrompt), findsOneWidget);
    });

    testWidgets('twice when two checks run together', (tester) async {
      await pump(tester);

      final first = showReminderPromptIfNeeded(
        container: container,
        navigatorKey: navigatorKey,
        settle: Duration.zero,
        isForeground: () => true,
      );
      final second = showReminderPromptIfNeeded(
        container: container,
        navigatorKey: navigatorKey,
        settle: Duration.zero,
        isForeground: () => true,
      );
      await tester.pumpAndSettle();

      expect(find.byType(ReminderPrompt), findsOneWidget);
      expect(await second, isFalse);
      await tester.tap(find.text(l10n.reminder_prompt_no));
      await tester.pumpAndSettle();
      expect(await first, isTrue);
    });
  });

  testWidgets('waits for the home screen before it appears', (tester) async {
    await pump(tester);

    final result = showReminderPromptIfNeeded(
      container: container,
      navigatorKey: navigatorKey,
      isForeground: () => true,
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ReminderPrompt), findsNothing);

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.byType(ReminderPrompt), findsOneWidget);

    await tester.tap(find.text(l10n.reminder_prompt_no));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
  });

  testWidgets('shows under Reduce Motion, as a fade', (tester) async {
    reduceMotion(tester);
    await pump(tester);

    await ask(tester);

    expect(find.byType(ReminderPrompt), findsOneWidget);
    expect(find.text(l10n.reminder_prompt_title), findsOneWidget);
  });

  testWidgets('has labelled targets of at least 48 points', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester);
    await ask(tester);

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
    testWidgets('reads in $locale at the largest text size', (tester) async {
      final text = lookupAppLocalizations(Locale(locale));
      await pump(tester, locale: locale, textScale: 2);

      await ask(tester);

      expect(find.text(text.reminder_prompt_title), findsOneWidget);
      expect(find.text(text.reminder_prompt_yes), findsOneWidget);
      expect(find.text(text.reminder_prompt_no), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'no overflow');
    });
  }
}
