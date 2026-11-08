import 'dart:ui' show SemanticsAction;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/locale_controller.dart';
import 'package:live_darbar/src/controllers/reminder_controller.dart';
import 'package:live_darbar/src/core/amritsar_time.dart';
import 'package:live_darbar/src/core/app_theme.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/app_version.dart';
import 'package:live_darbar/src/models/reminder_time.dart';
import 'package:live_darbar/src/services/reminder_platform.dart';
import 'package:live_darbar/src/views/screens/about_screen.dart';
import 'package:live_darbar/src/views/widgets/reminder_setting.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/app_harness.dart' show reduceMotion;
import '../support/fake_reminder_platform.dart';

class _Locale extends LocaleController {
  _Locale(this.locale);

  final String locale;

  @override
  String build() => locale;
}

/// The default, read by a listener in Sydney in summer.
const _amritsarSeven = '7:00 AM in Amritsar, 12:30 PM here';

/// The daily reminder on the About screen: a switch, and the time under it
/// while it is on.
void main() {
  late FakeReminderPlatform phone;
  final en = lookupAppLocalizations(const Locale('en'));

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    String locale = 'en',
    Map<String, Object> saved = const {},
  }) async {
    SharedPreferences.setMockInitialValues(saved);
    AppType.tracking = locale != 'pa';
    addTearDown(() => AppType.tracking = true);
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        retry: (_, __) => null,
        overrides: [
          reminderPlatformProvider.overrideWithValue(phone),
          // A listener in Sydney in summer: 7:00 in Amritsar is 12:30 here.
          localOffsetProvider.overrideWithValue(
            (_) => const Duration(hours: 11),
          ),
          appVersionProvider.overrideWith((ref) async => '3.0.0 (10)'),
          // The app shell sets both to the same language.
          localeController.overrideWith(() => _Locale(locale)),
        ],
        child: MaterialApp(
          theme: AppTheme.material,
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AboutScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(AboutScreen)));
  }

  setUp(() => phone = FakeReminderPlatform());

  // About holds 2 switches: this one, and "Today in Sikh history" under it.
  final reminderSwitch = find.descendant(
    of: find.byType(ReminderSetting),
    matching: find.byType(CupertinoSwitch),
  );

  Finder row(String label) => find.bySemanticsLabel(label);

  testWidgets('is off at first, with no time under it', (tester) async {
    await pump(tester);

    expect(find.text(en.reminder_setting), findsOneWidget);
    expect(find.text(en.reminder_time), findsNothing);
    expect(phone.calls, isEmpty, reason: 'looking asks nothing of the phone');
  });

  testWidgets('a tap turns it on at 7:00 in Amritsar and shows the time', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text(en.reminder_setting));
    await tester.pumpAndSettle();

    expect(phone.calls, ['request', 'schedule 07:00 IST']);
    expect(find.text(en.reminder_time), findsOneWidget);
    expect(find.text(_amritsarSeven), findsOneWidget);
  });

  testWidgets('a tap on the switch itself does the same', (tester) async {
    await pump(tester);

    // The switch only shows the state; the row takes the tap. Hence no hit.
    await tester.tap(reminderSwitch, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(phone.scheduled, ReminderTime.standard);
    expect(
      tester.widget<CupertinoSwitch>(reminderSwitch).value,
      isTrue,
    );
  });

  testWidgets('a second tap turns it off and the time goes', (tester) async {
    await pump(tester);
    await tester.tap(find.text(en.reminder_setting));
    await tester.pumpAndSettle();

    await tester.tap(find.text(en.reminder_setting));
    await tester.pumpAndSettle();

    expect(phone.calls.last, 'cancel');
    expect(phone.scheduled, isNull);
    expect(find.text(en.reminder_time), findsNothing);
    expect(
      tester.widget<CupertinoSwitch>(reminderSwitch).value,
      isFalse,
    );
  });

  testWidgets('stays off and says why when the phone does not allow it', (
    tester,
  ) async {
    phone.allowed = false;
    await pump(tester);

    await tester.tap(find.text(en.reminder_setting));
    await tester.pumpAndSettle();

    expect(find.text(en.reminder_blocked_hint), findsOneWidget);
    expect(find.text(en.reminder_time), findsNothing);
    expect(phone.scheduled, isNull);
    expect(
      tester.widget<CupertinoSwitch>(reminderSwitch).value,
      isFalse,
    );
  });

  testWidgets('works once the listener allows notifications and tries again', (
    tester,
  ) async {
    phone.allowed = false;
    await pump(tester);
    await tester.tap(find.text(en.reminder_setting));
    await tester.pumpAndSettle();

    phone.allowed = true;
    await tester.tap(find.text(en.reminder_setting));
    await tester.pumpAndSettle();

    expect(find.text(en.reminder_blocked_hint), findsNothing);
    expect(find.text(en.reminder_time), findsOneWidget);
    expect(phone.scheduled, ReminderTime.standard);
  });

  testWidgets('says so when the phone cannot set the reminder', (tester) async {
    phone.scheduleError = StateError('no');
    await pump(tester);

    await tester.tap(find.text(en.reminder_setting));
    await tester.pumpAndSettle();

    expect(find.text(en.reminder_failed_hint), findsOneWidget);
    expect(
      tester.widget<CupertinoSwitch>(reminderSwitch).value,
      isFalse,
    );
  });

  testWidgets('shows the saved choice when it is on', (tester) async {
    await pump(
      tester,
      saved: {
        'reminder_asked': true,
        'reminder_enabled': true,
        'reminder_minutes': 5 * 60 + 45,
        'reminder_zone': 'local',
      },
    );

    expect(find.text(en.reminder_time), findsOneWidget);
    expect(find.text('5:45 AM'), findsOneWidget,
        reason: 'a time the listener picked is on their own clock');
    expect(
      tester.widget<CupertinoSwitch>(reminderSwitch).value,
      isTrue,
    );
  });

  testWidgets('keeps the switch on and explains when the phone has blocked it',
      (
    tester,
  ) async {
    phone.allowed = false;
    final container = await pump(
      tester,
      saved: {'reminder_asked': true, 'reminder_enabled': true},
    );

    await container.read(reminderProvider.notifier).resync();
    await tester.pumpAndSettle();

    expect(find.text(en.reminder_blocked_hint), findsOneWidget);
    expect(find.text(en.reminder_time), findsOneWidget);
    expect(
      tester.widget<CupertinoSwitch>(reminderSwitch).value,
      isTrue,
    );
  });

  group('the time', () {
    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.text(en.reminder_time));
      await tester.pumpAndSettle();
    }

    testWidgets('opens a sheet with a wheel at the saved time', (tester) async {
      await pump(
        tester,
        saved: {
          'reminder_asked': true,
          'reminder_enabled': true,
          'reminder_minutes': 6 * 60 + 30,
          'reminder_zone': 'local',
        },
      );

      await openSheet(tester);

      final picker = tester.widget<CupertinoDatePicker>(
        find.byType(CupertinoDatePicker),
      );
      expect(picker.mode, CupertinoDatePickerMode.time);
      expect(picker.initialDateTime.hour, 6);
      expect(picker.initialDateTime.minute, 30);
      expect(find.text(en.reminder_done), findsOneWidget);
    });

    testWidgets(
        'starts on the listener’s own clock for the Amritsar default, and '
        'says what it is now', (tester) async {
      await pump(
        tester,
        saved: {'reminder_asked': true, 'reminder_enabled': true},
      );

      await openSheet(tester);

      final picker = tester.widget<CupertinoDatePicker>(
        find.byType(CupertinoDatePicker),
      );
      expect(picker.initialDateTime.hour, 12);
      expect(picker.initialDateTime.minute, 30);
      expect(find.text(en.reminder_time_note(_amritsarSeven)), findsOneWidget);
      expect(find.text(en.reminder_use_amritsar), findsNothing);
    });

    testWidgets('says the wheel’s time in Amritsar, and follows the wheel', (
      tester,
    ) async {
      await pump(
        tester,
        saved: {
          'reminder_asked': true,
          'reminder_enabled': true,
          'reminder_minutes': 6 * 60 + 30,
          'reminder_zone': 'local',
        },
      );
      await openSheet(tester);

      // Sydney in summer is 5:30 ahead of Amritsar.
      expect(
        find.text(en.reminder_wheel_amritsar('6:30 AM', '1:00 AM')),
        findsOneWidget,
      );

      tester
          .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
          .onDateTimeChanged(DateTime(2026, 1, 1, 13, 30));
      await tester.pump();

      expect(
        find.text(en.reminder_wheel_amritsar('1:30 PM', '8:00 AM')),
        findsOneWidget,
      );
      expect(
        find.text(en.reminder_wheel_amritsar('6:30 AM', '1:00 AM')),
        findsNothing,
      );
    });

    testWidgets('a pick is the listener’s own clock, and stays there', (
      tester,
    ) async {
      await pump(
        tester,
        saved: {'reminder_asked': true, 'reminder_enabled': true},
      );
      await openSheet(tester);

      tester
          .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
          .onDateTimeChanged(DateTime(2026, 1, 1, 6, 15));
      await tester.tap(find.text(en.reminder_done));
      await tester.pumpAndSettle();

      expect(phone.scheduled, const ReminderTime(6, 15));
      expect(phone.scheduled!.zone, ReminderZone.local);
      expect(find.text('6:15 AM'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('reminder_zone'), 'local');
    });

    testWidgets('Done with no turn of the wheel keeps Amritsar time', (
      tester,
    ) async {
      await pump(
        tester,
        saved: {'reminder_asked': true, 'reminder_enabled': true},
      );
      await openSheet(tester);

      await tester.tap(find.text(en.reminder_done));
      await tester.pumpAndSettle();

      expect(phone.scheduled, isNull, reason: 'nothing changed');
      expect(find.text(_amritsarSeven), findsOneWidget);
    });

    testWidgets('a time on the listener’s clock can go back to Amritsar', (
      tester,
    ) async {
      await pump(
        tester,
        saved: {
          'reminder_asked': true,
          'reminder_enabled': true,
          'reminder_minutes': 6 * 60 + 30,
          'reminder_zone': 'local',
        },
      );
      await openSheet(tester);
      expect(find.text(en.reminder_time_note(_amritsarSeven)), findsNothing);

      await tester.tap(find.text(en.reminder_use_amritsar));
      await tester.pumpAndSettle();

      expect(phone.scheduled, ReminderTime.standard);
      expect(find.text(_amritsarSeven), findsOneWidget);
    });

    testWidgets('Done saves the time the wheel shows, and moves the reminder', (
      tester,
    ) async {
      await pump(
        tester,
        saved: {'reminder_asked': true, 'reminder_enabled': true},
      );
      await openSheet(tester);

      tester
          .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
          .onDateTimeChanged(DateTime(2026, 1, 1, 18, 5));
      await tester.tap(find.text(en.reminder_done));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoDatePicker), findsNothing);
      expect(find.text('6:05 PM'), findsOneWidget);
      expect(phone.scheduled, const ReminderTime(18, 5));
    });

    testWidgets('turns with a finger', (tester) async {
      await pump(
        tester,
        saved: {'reminder_asked': true, 'reminder_enabled': true},
      );
      await openSheet(tester);

      // The first wheel is the hour. 2 rows up is 2 hours later.
      await tester.drag(
        find.byType(CupertinoPicker).first,
        const Offset(0, -64),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.reminder_done));
      await tester.pumpAndSettle();

      // The wheel starts at 12:30, the default on a Sydney clock.
      expect(phone.scheduled, const ReminderTime(14, 30));
      expect(find.text('2:30 PM'), findsOneWidget);
    });

    testWidgets('Done with no change asks nothing of the phone',
        (tester) async {
      await pump(
        tester,
        saved: {'reminder_asked': true, 'reminder_enabled': true},
      );
      await openSheet(tester);
      phone.calls.clear();

      await tester.tap(find.text(en.reminder_done));
      await tester.pumpAndSettle();

      expect(phone.calls, isEmpty);
      expect(find.text(_amritsarSeven), findsOneWidget);
    });

    testWidgets('a swipe away keeps the old time', (tester) async {
      await pump(
        tester,
        saved: {'reminder_asked': true, 'reminder_enabled': true},
      );
      await openSheet(tester);
      tester
          .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
          .onDateTimeChanged(DateTime(2026, 1, 1, 18, 5));

      await tester.tapAt(const Offset(20, 40));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoDatePicker), findsNothing);
      expect(find.text(_amritsarSeven), findsOneWidget);
      expect(phone.calls, isEmpty);
    });
  });

  testWidgets('is not on a platform that cannot remind', (tester) async {
    phone.supported = false;
    await pump(tester);

    expect(find.text(en.reminder_setting), findsNothing);
    expect(reminderSwitch, findsNothing);
    expect(phone.calls, isEmpty);
  });

  testWidgets('tells a screen reader its name, its state and that it taps', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(tester);

    var node = tester.getSemantics(row(en.reminder_setting));
    expect(node.label, en.reminder_setting);
    expect(node.value, en.reminder_off);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    await tester.tap(find.text(en.reminder_setting));
    await tester.pumpAndSettle();

    node = tester.getSemantics(row(en.reminder_setting));
    expect(node.value, en.reminder_on);
    final time = tester.getSemantics(row(en.reminder_time));
    expect(time.value, _amritsarSeven);
    expect(time.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    semantics.dispose();
  });

  testWidgets('has rows at least 48 points high', (tester) async {
    await pump(tester,
        saved: {'reminder_asked': true, 'reminder_enabled': true});

    for (final label in [en.reminder_setting, en.reminder_time]) {
      expect(
        tester.getSize(find.bySemanticsLabel(label)).height,
        greaterThanOrEqualTo(48),
        reason: label,
      );
    }
  });

  testWidgets('shows the time at once under Reduce Motion', (tester) async {
    reduceMotion(tester);
    await pump(tester);

    await tester.tap(find.text(en.reminder_setting));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text(en.reminder_time), findsOneWidget);
  });

  testWidgets('reads in Punjabi', (tester) async {
    final pa = lookupAppLocalizations(const Locale('pa'));
    await pump(tester, locale: 'pa');

    expect(find.text(pa.reminder_setting), findsOneWidget);
    await tester.tap(find.text(pa.reminder_setting));
    await tester.pumpAndSettle();

    expect(find.text(pa.reminder_time), findsOneWidget);
    expect(phone.text!.title, pa.reminder_notification_title);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reads in Punjabi when it has to explain', (tester) async {
    final pa = lookupAppLocalizations(const Locale('pa'));
    phone.allowed = false;
    await pump(tester, locale: 'pa');

    await tester.tap(find.text(pa.reminder_setting));
    await tester.pumpAndSettle();

    expect(find.text(pa.reminder_blocked_hint), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
