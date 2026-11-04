import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/locale_controller.dart';
import 'package:live_darbar/src/controllers/reminder_controller.dart';
import 'package:live_darbar/src/models/reminder_settings.dart';
import 'package:live_darbar/src/models/reminder_time.dart';
import 'package:live_darbar/src/services/reminder_platform.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_reminder_platform.dart';

/// The rules of the daily reminder: it asks once, it needs the phone's yes
/// before it is on, and what the listener chose survives a restart.
void main() {
  late FakeReminderPlatform phone;

  ProviderContainer containerFor(FakeReminderPlatform platform) {
    final container = ProviderContainer(
      // A failed build retries on a timer, and a test must not leave one.
      retry: (_, __) => null,
      overrides: [reminderPlatformProvider.overrideWithValue(platform)],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<ReminderSettings> settingsOf(ProviderContainer container) =>
      container.read(reminderProvider.future);

  ReminderController controllerOf(ProviderContainer container) =>
      container.read(reminderProvider.notifier);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    phone = FakeReminderPlatform();
  });

  group('asking once', () {
    test('a new listener has not been asked, and the reminder is off at 7:00 in '
        'Amritsar', () async {
      final settings = await settingsOf(containerFor(phone));

      expect(settings.asked, isFalse);
      expect(settings.enabled, isFalse);
      expect(settings.time, ReminderTime.standard);
      expect(settings.problem, ReminderProblem.none);
    });

    test('a listener who updated is asked once, whatever else they saved',
        () async {
      // The app before this feature saved these and nothing about reminders.
      SharedPreferences.setMockInitialValues({
        'locale': 'pa',
        'reader_scale': 1.3,
        'update_dismissed_build': 10,
      });

      final settings = await settingsOf(containerFor(phone));

      expect(settings.asked, isFalse);
      expect(settings.enabled, isFalse);
    });

    test('marking it asked is remembered by the next launch', () async {
      final first = containerFor(phone);
      await controllerOf(first).markAsked();

      final nextLaunch = containerFor(FakeReminderPlatform());
      expect((await settingsOf(nextLaunch)).asked, isTrue);
      expect((await settingsOf(nextLaunch)).enabled, isFalse);
    });

    test('marking it asked twice changes nothing', () async {
      final container = containerFor(phone);
      await controllerOf(container).markAsked();
      await controllerOf(container).markAsked();

      expect((await settingsOf(container)).asked, isTrue);
      expect(phone.calls, isEmpty, reason: 'it never touches the phone');
    });

    test('turning it on from About first counts as asked', () async {
      final container = containerFor(phone);

      await controllerOf(container).turnOn();

      expect((await settingsOf(container)).asked, isTrue);
    });

    test('turning it off from About first counts as asked', () async {
      final container = containerFor(phone);

      await controllerOf(container).turnOff();

      expect((await settingsOf(container)).asked, isTrue);
    });
  });

  group('turning it on', () {
    test('asks the phone first, then sets 7:00 in Amritsar, in English', () async {
      final container = containerFor(phone);

      final problem = await controllerOf(container).turnOn();

      expect(problem, ReminderProblem.none);
      expect(phone.calls, ['request', 'schedule 07:00 IST']);
      expect(phone.text!.title, 'Today’s Hukamnama');
      expect(phone.text!.body, 'Read the Hukamnama from Sri Darbar Sahib.');
      final settings = await settingsOf(container);
      expect(settings.enabled, isTrue);
      expect(settings.problem, ReminderProblem.none);
    });

    test('is remembered by the next launch', () async {
      await controllerOf(containerFor(phone)).turnOn();

      final settings = await settingsOf(containerFor(FakeReminderPlatform()));
      expect(settings.enabled, isTrue);
      expect(settings.asked, isTrue);
    });

    test('sets nothing when the phone says no, and says why', () async {
      phone.allowed = false;
      final container = containerFor(phone);

      final problem = await controllerOf(container).turnOn();

      expect(problem, ReminderProblem.blocked);
      expect(phone.calls, ['request']);
      expect(phone.scheduled, isNull);
      final settings = await settingsOf(container);
      expect(settings.enabled, isFalse);
      expect(settings.asked, isTrue);
      expect(settings.problem, ReminderProblem.blocked);
    });

    test('does not leave it on when the phone refuses to set it', () async {
      phone.scheduleError = StateError('invalid_icon');
      final container = containerFor(phone);

      final problem = await controllerOf(container).turnOn();

      expect(problem, ReminderProblem.failed);
      final settings = await settingsOf(container);
      expect(settings.enabled, isFalse);
      expect(settings.problem, ReminderProblem.failed);
    });

    test('works after the first no, when the listener allows it later',
        () async {
      phone.allowed = false;
      final container = containerFor(phone);
      await controllerOf(container).turnOn();

      phone.allowed = true;
      final problem = await controllerOf(container).turnOn();

      expect(problem, ReminderProblem.none);
      final settings = await settingsOf(container);
      expect(settings.enabled, isTrue);
      expect(settings.problem, ReminderProblem.none);
    });
  });

  group('turning it off', () {
    test('removes the reminder and remembers', () async {
      final container = containerFor(phone);
      await controllerOf(container).turnOn();

      await controllerOf(container).turnOff();

      expect(phone.scheduled, isNull);
      expect((await settingsOf(container)).enabled, isFalse);
      final nextLaunch = await settingsOf(containerFor(FakeReminderPlatform()));
      expect(nextLaunch.enabled, isFalse);
    });

    test('goes off even when the phone cannot cancel', () async {
      final container = containerFor(_CancelFails());
      await controllerOf(container).turnOn();

      await controllerOf(container).turnOff();

      expect((await settingsOf(container)).enabled, isFalse);
    });

    test('clears a message about the phone', () async {
      phone.allowed = false;
      final container = containerFor(phone);
      await controllerOf(container).turnOn();

      await controllerOf(container).turnOff();

      expect((await settingsOf(container)).problem, ReminderProblem.none);
    });
  });

  group('the time', () {
    test('moves the reminder when it is on', () async {
      final container = containerFor(phone);
      await controllerOf(container).turnOn();

      await controllerOf(container).setTime(const ReminderTime(5, 30));

      expect(phone.scheduled, const ReminderTime(5, 30));
      expect((await settingsOf(container)).time, const ReminderTime(5, 30));
    });

    test('is kept, and sets nothing, when the reminder is off', () async {
      final container = containerFor(phone);

      await controllerOf(container).setTime(const ReminderTime(5, 30));

      expect(phone.calls, isEmpty);
      expect((await settingsOf(container)).time, const ReminderTime(5, 30));
    });

    test('is the one the next launch schedules', () async {
      await controllerOf(containerFor(phone)).turnOn();
      await controllerOf(containerFor(phone))
          .setTime(const ReminderTime(18, 45));

      final next = FakeReminderPlatform();
      final container = containerFor(next);
      await controllerOf(container).resync();

      expect(next.scheduled, const ReminderTime(18, 45));
    });

    test('starts as 7:00 in Amritsar, which the phone keeps in Amritsar', () async {
      final container = containerFor(phone);

      final time = (await settingsOf(container)).time;
      expect(time, ReminderTime.standard);
      expect(time.zone, ReminderZone.amritsar);

      await controllerOf(container).turnOn();
      expect(phone.scheduled!.zone, ReminderZone.amritsar);
    });

    test('a time the listener picks is on their own clock, and is saved so',
        () async {
      final container = containerFor(phone);

      await controllerOf(container).setTime(const ReminderTime(8, 15));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('reminder_minutes'), 8 * 60 + 15);
      expect(prefs.getString('reminder_zone'), 'local');
      final next = containerFor(FakeReminderPlatform());
      expect((await settingsOf(next)).time.zone, ReminderZone.local);
    });

    test('going back to Amritsar time is saved too', () async {
      final container = containerFor(phone);
      await controllerOf(container).setTime(const ReminderTime(8, 15));

      await controllerOf(container).setTime(ReminderTime.standard);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('reminder_zone'), 'amritsar');
      expect((await settingsOf(containerFor(phone))).time,
          ReminderTime.standard);
    });

    test('is 7:00 again when the saved value is damaged', () async {
      SharedPreferences.setMockInitialValues({'reminder_minutes': 99999});

      expect(
          (await settingsOf(containerFor(phone))).time, ReminderTime.standard);
    });

    test('does nothing for the time it already has', () async {
      final container = containerFor(phone);
      await controllerOf(container).turnOn();
      phone.calls.clear();

      await controllerOf(container).setTime(ReminderTime.standard);

      expect(phone.calls, isEmpty);
    });

    test('says so when the phone cannot move it', () async {
      final container = containerFor(phone);
      await controllerOf(container).turnOn();
      phone.scheduleError = StateError('no');

      await controllerOf(container).setTime(const ReminderTime(6, 0));

      expect((await settingsOf(container)).problem, ReminderProblem.failed);
    });
  });

  group('syncing', () {
    test('sets the saved reminder again at launch', () async {
      SharedPreferences.setMockInitialValues({
        'reminder_asked': true,
        'reminder_enabled': true,
        'reminder_minutes': 6 * 60 + 15,
        'reminder_zone': 'local',
      });
      final container = containerFor(phone);

      await controllerOf(container).resync();

      expect(phone.scheduled, const ReminderTime(6, 15));
      expect((await settingsOf(container)).problem, ReminderProblem.none);
    });

    test('sets nothing for a listener who said no', () async {
      SharedPreferences.setMockInitialValues({'reminder_asked': true});
      final container = containerFor(phone);

      await controllerOf(container).resync();

      expect(phone.calls, isEmpty);
    });

    test('touches nothing for a listener who was never asked', () async {
      await controllerOf(containerFor(phone)).resync();

      expect(phone.calls, isEmpty);
    });

    test('notes it when the phone has since blocked notifications', () async {
      SharedPreferences.setMockInitialValues({
        'reminder_asked': true,
        'reminder_enabled': true,
      });
      phone.allowed = false;
      final container = containerFor(phone);

      await controllerOf(container).resync();

      final settings = await settingsOf(container);
      expect(settings.enabled, isTrue, reason: 'the choice stays');
      expect(settings.problem, ReminderProblem.blocked);
    });

    test('clears the note when the listener allows them again', () async {
      SharedPreferences.setMockInitialValues({
        'reminder_asked': true,
        'reminder_enabled': true,
      });
      phone.allowed = false;
      final container = containerFor(phone);
      await controllerOf(container).resync();

      phone.allowed = true;
      await controllerOf(container).resync();

      expect((await settingsOf(container)).problem, ReminderProblem.none);
    });

    test('does nothing on a platform that cannot remind', () async {
      SharedPreferences.setMockInitialValues({
        'reminder_asked': true,
        'reminder_enabled': true,
      });
      phone.supported = false;
      final container = containerFor(phone);

      await controllerOf(container).resync();

      expect(phone.calls, isEmpty);
    });

    test('says so when the phone cannot set it', () async {
      SharedPreferences.setMockInitialValues({
        'reminder_asked': true,
        'reminder_enabled': true,
      });
      phone.scheduleError = StateError('no');
      final container = containerFor(phone);

      await controllerOf(container).resync();

      expect((await settingsOf(container)).problem, ReminderProblem.failed);
    });

    test('sets the words again when the language changes', () async {
      SharedPreferences.setMockInitialValues({
        'reminder_asked': true,
        'reminder_enabled': true,
      });
      final container = containerFor(phone);
      await controllerOf(container).resync();
      expect(phone.text!.title, 'Today’s Hukamnama');

      await container.read(localeController.notifier).changeLocale('pa');
      await Future<void>.delayed(Duration.zero);

      final pa = lookupAppLocalizations(const Locale('pa'));
      expect(phone.text!.title, pa.reminder_notification_title);
      expect(phone.text!.body, pa.reminder_notification_body);
      expect(phone.text!.channelName, pa.reminder_channel_name);
      expect(phone.text!.title, isNot('Today’s Hukamnama'));
    });
  });

  group('one thing at a time', () {
    test('a sync that starts during the phone\'s question waits for the answer',
        () async {
      // Android gives the app back the moment the permission dialog closes,
      // and the app syncs then, while "Remind me" is still finishing.
      final slow = _SlowPermission();
      final container = containerFor(slow);
      await settingsOf(container);

      final turnedOn = controllerOf(container).turnOn();
      final synced = controllerOf(container).resync();
      await Future<void>.delayed(Duration.zero);
      expect(slow.calls, ['request'], reason: 'the sync waits its turn');

      slow.answer.complete(true);
      await turnedOn;
      await synced;

      expect(slow.scheduled, ReminderTime.standard,
          reason: 'the sync must not remove the reminder just set');
      expect(slow.calls, [
        'request',
        'schedule 07:00 IST',
        'has',
        'schedule 07:00 IST',
      ]);
      expect((await settingsOf(container)).enabled, isTrue);
    });

    test('turning it off during a sync leaves it off', () async {
      SharedPreferences.setMockInitialValues({
        'reminder_asked': true,
        'reminder_enabled': true,
      });
      final slow = _SlowPermission();
      final container = containerFor(slow);
      await settingsOf(container);

      final synced = controllerOf(container).resync();
      final turnedOff = controllerOf(container).turnOff();
      slow.answer.complete(true);
      await synced;
      await turnedOff;

      expect(slow.scheduled, isNull, reason: 'the cancel came last');
      expect((await settingsOf(container)).enabled, isFalse);
    });

    test('a job that throws does not stop the ones after it', () async {
      phone.scheduleError = StateError('no');
      final container = containerFor(phone);
      await controllerOf(container).turnOn();

      phone.scheduleError = null;
      final problem = await controllerOf(container).turnOn();

      expect(problem, ReminderProblem.none);
    });
  });

  group('starting the app', () {
    test('readies the phone, syncs, and sends taps on', () async {
      SharedPreferences.setMockInitialValues({
        'reminder_asked': true,
        'reminder_enabled': true,
      });
      final container = containerFor(phone);
      var opened = 0;

      await controllerOf(container).start(() => opened++);

      expect(phone.calls.first, 'start');
      expect(phone.scheduled, ReminderTime.standard);
      expect(opened, 0, reason: 'the app was not opened by a tap');

      phone.onTap!();
      expect(opened, 1);
    });

    test('opens the reader once when a tap on the reminder started the app',
        () async {
      phone.launchedByReminder = true;
      final container = containerFor(phone);
      var opened = 0;

      await controllerOf(container).start(() => opened++);

      expect(opened, 1);
    });

    test('does nothing on a platform that cannot remind', () async {
      phone.supported = false;
      final container = containerFor(phone);

      await controllerOf(container).start(() {});

      expect(phone.calls, isEmpty);
    });

    test('survives a phone that fails', () async {
      final container = containerFor(_StartFails());

      await controllerOf(container).start(() {});
    });
  });
}

/// A phone whose permission question stays open until the test answers it.
class _SlowPermission extends FakeReminderPlatform {
  final answer = Completer<bool>();

  @override
  Future<bool> requestPermission() async {
    calls.add('request');
    return answer.future;
  }
}

class _CancelFails extends FakeReminderPlatform {
  @override
  Future<void> cancel() async => throw StateError('no');
}

class _StartFails extends FakeReminderPlatform {
  @override
  Future<void> start(onTap) async => throw StateError('no');
}
