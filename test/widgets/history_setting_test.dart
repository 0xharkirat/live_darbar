import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/locale_controller.dart';
import 'package:live_darbar/src/controllers/sgpc_events_controller.dart';
import 'package:live_darbar/src/core/app_theme.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/app_version.dart';
import 'package:live_darbar/src/core/clock.dart';
import 'package:live_darbar/src/models/sgpc_event.dart';
import 'package:live_darbar/src/services/reminder_platform.dart';
import 'package:live_darbar/src/views/screens/about_screen.dart';
import 'package:live_darbar/src/views/widgets/history_setting.dart';
import 'package:live_darbar/src/views/widgets/reminder_setting.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_reminder_platform.dart';

class _Locale extends LocaleController {
  _Locale(this.locale);

  final String locale;

  @override
  String build() => locale;
}

/// The "Today in Sikh history" switch on the About screen: off until the
/// listener turns it on, and the phone is asked only then.
void main() {
  late FakeReminderPlatform phone;
  final en = lookupAppLocalizations(const Locale('en'));
  final pa = lookupAppLocalizations(const Locale('pa'));

  final table = SgpcEventTable.fromJsonString(
    File('assets/data/sgpc_events_558.json').readAsStringSync(),
  );

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
          appVersionProvider.overrideWith((ref) async => '3.0.0 (10)'),
          localeController.overrideWith(() => _Locale(locale)),
          clockProvider.overrideWithValue(
            () => DateTime.utc(2026, 11, 2, 6),
          ),
          sgpcEventsProvider.overrideWith((ref) async => table),
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

  /// The switch of this setting, not the daily reminder's above it.
  Finder historySwitch() => find.descendant(
        of: find.byType(HistorySetting),
        matching: find.byType(CupertinoSwitch),
      );

  bool isOn(WidgetTester tester) =>
      tester.widget<CupertinoSwitch>(historySwitch()).value;

  setUp(() => phone = FakeReminderPlatform());

  testWidgets('is off at first, and looking asks nothing of the phone', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text(en.history_setting), findsOneWidget);
    expect(find.text(en.history_setting_detail), findsOneWidget);
    expect(isOn(tester), isFalse);
    expect(phone.calls, isEmpty);
  });

  testWidgets('sits under the daily reminder, as a second switch', (
    tester,
  ) async {
    await pump(tester);

    expect(find.byType(CupertinoSwitch), findsNWidgets(2));
    final reminder = tester.getTopLeft(find.text(en.reminder_setting)).dy;
    final history = tester.getTopLeft(find.text(en.history_setting)).dy;
    expect(history, greaterThan(reminder));
  });

  testWidgets('says Off to a screen reader, and names what it does', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester);

    final node = tester.getSemantics(
      find.bySemanticsLabel('${en.history_setting}. ${en.history_setting_detail}'),
    );
    expect(node.value, en.reminder_off);
    handle.dispose();
  });

  testWidgets('a tap asks for permission now, then turns it on', (
    tester,
  ) async {
    await pump(tester);
    expect(phone.calls, isEmpty);

    await tester.tap(find.text(en.history_setting));
    await tester.pumpAndSettle();

    expect(phone.calls, ['request', 'history 07:00 IST x10']);
    expect(isOn(tester), isTrue);
    expect(phone.historyText!.title, en.history_title);
  });

  testWidgets('leaves the daily reminder alone', (tester) async {
    await pump(tester);

    await tester.tap(find.text(en.history_setting));
    await tester.pumpAndSettle();

    expect(phone.scheduled, isNull);
    expect(find.text(en.reminder_time), findsNothing);
    final reminderSwitch = find.descendant(
      of: find.byType(ReminderSetting),
      matching: find.byType(CupertinoSwitch),
    );
    expect(tester.widget<CupertinoSwitch>(reminderSwitch).value, isFalse);
  });

  testWidgets('a tap on the switch itself does the same', (tester) async {
    await pump(tester);

    // The switch only shows the state; the row takes the tap.
    await tester.tap(historySwitch(), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(isOn(tester), isTrue);
    expect(phone.history, isNotEmpty);
  });

  testWidgets('a second tap turns it off and removes the notices', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text(en.history_setting));
    await tester.pumpAndSettle();

    await tester.tap(find.text(en.history_setting));
    await tester.pumpAndSettle();

    expect(phone.calls.last, 'cancelHistory');
    expect(phone.history, isNull);
    expect(isOn(tester), isFalse);
  });

  testWidgets('stays off and says why when the phone does not allow it', (
    tester,
  ) async {
    phone.allowed = false;
    await pump(tester);

    await tester.tap(find.text(en.history_setting));
    await tester.pumpAndSettle();

    expect(find.text(en.reminder_blocked_hint), findsOneWidget);
    expect(isOn(tester), isFalse);
    expect(phone.history, isNull);
  });

  testWidgets('stays off and says so when the phone cannot set it', (
    tester,
  ) async {
    phone.historyError = StateError('no');
    await pump(tester);

    await tester.tap(find.text(en.history_setting));
    await tester.pumpAndSettle();

    expect(find.text(en.history_failed_hint), findsOneWidget);
    expect(isOn(tester), isFalse);
  });

  testWidgets('shows a saved yes as on, without asking again', (tester) async {
    await pump(tester, saved: {'history_enabled': true});

    expect(isOn(tester), isTrue);
    expect(phone.calls, isEmpty, reason: 'the app syncs at launch, not here');
  });

  testWidgets('reads in Punjabi', (tester) async {
    await pump(tester, locale: 'pa');

    expect(find.text(pa.history_setting), findsOneWidget);
    expect(find.text(pa.history_setting_detail), findsOneWidget);
    expect(find.text(en.history_setting), findsNothing);
  });

  testWidgets('is not on the web, which cannot notify with the page closed', (
    tester,
  ) async {
    phone.supported = false;
    await pump(tester);

    expect(find.text(en.history_setting), findsNothing);
    expect(find.byType(CupertinoSwitch), findsNothing);
  });
}
