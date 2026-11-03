import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/locale_controller.dart';
import 'package:live_darbar/src/controllers/reminder_controller.dart';
import 'package:live_darbar/src/controllers/sgpc_events_controller.dart';
import 'package:live_darbar/src/controllers/sikh_history_controller.dart';
import 'package:live_darbar/src/core/clock.dart';
import 'package:live_darbar/src/models/history_settings.dart';
import 'package:live_darbar/src/models/reminder_settings.dart';
import 'package:live_darbar/src/models/reminder_time.dart';
import 'package:live_darbar/src/models/sgpc_event.dart';
import 'package:live_darbar/src/services/reminder_platform.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_reminder_platform.dart';

/// The rules of the "Today in Sikh history" notification: off until the
/// listener says yes, asks the phone only then, and keeps its schedule in step
/// with the day, the language and the reminder's time.
void main() {
  late FakeReminderPlatform phone;
  // 2 November 2026, 06:00 UTC: the morning at Amritsar.
  final morning = DateTime.utc(2026, 11, 2, 6);

  ProviderContainer containerFor(
    FakeReminderPlatform platform, {
    DateTime Function()? clock,
  }) {
    final container = ProviderContainer(
      // A failed build retries on a timer, and a test must not leave one.
      retry: (_, __) => null,
      overrides: [
        reminderPlatformProvider.overrideWithValue(platform),
        clockProvider.overrideWithValue(clock ?? () => morning),
        sgpcEventsProvider.overrideWith(
          (ref) async => SgpcEventTable.fromJsonString(
            File('assets/data/sgpc_events_558.json').readAsStringSync(),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  SikhHistoryController controllerOf(ProviderContainer container) =>
      container.read(sikhHistoryProvider.notifier);

  Future<HistorySettings> settingsOf(ProviderContainer container) =>
      container.read(sikhHistoryProvider.future);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    phone = FakeReminderPlatform();
  });

  group('off by default', () {
    test('a new listener has it off, and the phone is asked nothing', () async {
      final container = containerFor(phone);

      final settings = await settingsOf(container);
      await controllerOf(container).resync();

      expect(settings.enabled, isFalse);
      expect(phone.calls, isEmpty);
    });

    test('opening the app with it off sets no notification', () async {
      final container = containerFor(phone);
      await settingsOf(container);

      await controllerOf(container).resync();

      expect(phone.history, isNull);
      expect(phone.calls, isNot(contains(startsWith('history'))));
    });

    test('does nothing where the phone cannot notify, as on the web', () async {
      SharedPreferences.setMockInitialValues({'history_enabled': true});
      phone.supported = false;
      final container = containerFor(phone);

      await controllerOf(container).resync();

      expect(phone.calls, isEmpty);
    });
  });

  group('turning it on', () {
    test('asks for permission now, then sets the next 30 days', () async {
      final container = containerFor(phone);
      await settingsOf(container);
      expect(phone.calls, isEmpty);

      final problem = await controllerOf(container).turnOn();

      expect(problem, ReminderProblem.none);
      expect(phone.calls, ['request', 'history 07:00 x10']);
      expect((await settingsOf(container)).enabled, isTrue);
      expect(phone.history!.first.day, DateTime.utc(2026, 11, 3));
      expect(phone.history!.first.body.split('\n'), hasLength(3));
      expect(phone.history!.last.day, DateTime.utc(2026, 11, 30));
    });

    test('names the notification in the app\'s language', () async {
      final container = containerFor(phone);
      await controllerOf(container).turnOn();

      expect(phone.historyText!.title, 'Today in Sikh history');
      expect(phone.historyText!.channelName, 'Today in Sikh history');
    });

    test('is remembered by the next launch', () async {
      await controllerOf(containerFor(phone)).turnOn();

      final nextLaunch = containerFor(FakeReminderPlatform());

      expect((await settingsOf(nextLaunch)).enabled, isTrue);
    });

    test('stays off and says so when the phone does not allow it', () async {
      phone.allowed = false;
      final container = containerFor(phone);

      final problem = await controllerOf(container).turnOn();

      expect(problem, ReminderProblem.blocked);
      final settings = await settingsOf(container);
      expect(settings.enabled, isFalse);
      expect(settings.problem, ReminderProblem.blocked);
      expect(phone.history, isNull);
    });

    test('stays off and says so when the phone cannot set it', () async {
      phone.historyError = StateError('no');
      final container = containerFor(phone);

      final problem = await controllerOf(container).turnOn();

      expect(problem, ReminderProblem.failed);
      expect((await settingsOf(container)).enabled, isFalse);
    });

    test('does not touch the daily reminder', () async {
      final container = containerFor(phone);

      await controllerOf(container).turnOn();

      expect(phone.scheduled, isNull);
      expect(phone.calls.where((c) => c.startsWith('schedule')), isEmpty);
      expect(phone.calls, isNot(contains('cancel')));
    });

    test('sets nothing when no day in the next 30 has an event', () async {
      final container = containerFor(
        phone,
        // 1 March 2027: the calendar has nothing from here to the next year.
        clock: () => DateTime.utc(2027, 3, 1, 6),
      );

      await controllerOf(container).turnOn();

      expect(phone.history, isEmpty);
      expect((await settingsOf(container)).enabled, isTrue);
    });
  });

  group('turning it off', () {
    test('removes the notifications and stays off', () async {
      final container = containerFor(phone);
      await controllerOf(container).turnOn();

      await controllerOf(container).turnOff();

      expect(phone.calls.last, 'cancelHistory');
      expect(phone.history, isNull);
      expect((await settingsOf(container)).enabled, isFalse);
      expect(
        (await SharedPreferences.getInstance()).getBool('history_enabled'),
        isFalse,
      );
    });

    test('goes off even when the phone would not cancel', () async {
      final container = containerFor(_FailsToCancel());
      await controllerOf(container).turnOn();

      await controllerOf(container).turnOff();

      expect((await settingsOf(container)).enabled, isFalse);
    });
  });

  group('keeping the schedule up to date', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({'history_enabled': true});
    });

    test('sets it again each time the app opens', () async {
      final container = containerFor(phone);

      await controllerOf(container).resync();

      expect(phone.calls, ['has', 'history 07:00 x10']);
    });

    test('moves the window on with the day', () async {
      var now = morning;
      final container = containerFor(phone, clock: () => now);
      await controllerOf(container).resync();
      expect(phone.history!.first.day, DateTime.utc(2026, 11, 3));

      // 4 November in Amritsar: 3 November is behind it.
      now = DateTime.utc(2026, 11, 4, 6);
      await controllerOf(container).resync();

      expect(phone.history!.first.day, DateTime.utc(2026, 11, 8));
    });

    test('sets the words again when the language changes', () async {
      final container = containerFor(phone);
      await controllerOf(container).resync();
      expect(phone.history!.first.body, startsWith('Gurgaddi Divas'));

      await container.read(localeController.notifier).changeLocale('pa');
      await Future<void>.delayed(Duration.zero);

      final pa = lookupAppLocalizations(const Locale('pa'));
      expect(phone.historyText!.title, pa.history_title);
      expect(phone.historyText!.channelDescription,
          pa.history_channel_description);
      expect(phone.history!.first.body, startsWith('ਗੁਰਿਆਈ ਦਿਵਸ'));
      expect(phone.history!.first.body, isNot(contains('Gurgaddi')));
    });

    test('follows the time of the daily reminder', () async {
      final container = containerFor(phone);
      await container.read(reminderProvider.future);
      await controllerOf(container).resync();
      expect(phone.historyTime, ReminderTime.standard);

      await container
          .read(reminderProvider.notifier)
          .setTime(const ReminderTime(5, 30));
      await Future<void>.delayed(Duration.zero);

      expect(phone.historyTime, const ReminderTime(5, 30));
    });

    test('keeps at most 30 notifications, well under the 64 of iOS', () async {
      final container = containerFor(phone);

      await controllerOf(container).resync();

      expect(phone.history!.length, lessThanOrEqualTo(30));
    });

    test('says so when the phone no longer lets the app notify', () async {
      phone.allowed = false;
      final container = containerFor(phone);

      await controllerOf(container).resync();

      final settings = await settingsOf(container);
      expect(settings.enabled, isTrue);
      expect(settings.problem, ReminderProblem.blocked);
    });

    test('says so when the phone cannot set it', () async {
      phone.historyError = StateError('no');
      final container = containerFor(phone);

      await controllerOf(container).resync();

      expect((await settingsOf(container)).problem, ReminderProblem.failed);
    });
  });
}

class _FailsToCancel extends FakeReminderPlatform {
  @override
  Future<void> cancelHistory() async => throw StateError('no');
}
