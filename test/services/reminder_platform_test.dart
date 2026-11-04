import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/core/history_schedule.dart';
import 'package:live_darbar/src/models/reminder_time.dart';
import 'package:live_darbar/src/models/sgpc_day.dart';
import 'package:live_darbar/src/services/reminder_platform.dart';
import 'package:timezone/timezone.dart' as tz;

/// What the app really sends to the notification plugin.
///
/// The plugin's native side is out of reach of a Dart test, so these stand in
/// for it on the plugin's own channel and check the messages it would get:
/// inexact, repeating each day on the wall clock, and no question to the
/// listener until the app asks.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const notifications =
      MethodChannel('dexterous.com/flutter/local_notifications');
  const timezoneChannel = MethodChannel('flutter_timezone');

  final calls = <MethodCall>[];
  late Map<String, Object?> answers;
  late Object? zone;

  const text = ReminderText(
    title: 'Today’s Hukamnama',
    body: 'Read the Hukamnama from Sri Darbar Sahib.',
    channelName: 'Daily Hukamnama',
    channelDescription: 'A reminder each day to read the Hukamnama.',
  );

  const historyText = HistoryText(
    title: 'Today in Sikh history',
    channelName: 'Today in Sikh history',
    channelDescription: 'A quiet notice on days with an event in Sikh history.',
  );

  /// The notice for the SGPC day [ahead] days from today. A negative number
  /// is a day that has gone.
  HistoryNotice noticeIn(int ahead) {
    final now = DateTime.now().toUtc();
    return HistoryNotice(
      day: DateTime.utc(now.year, now.month, now.day + ahead),
      body: 'First event\nSecond event $ahead',
    );
  }

  Iterable<Map<dynamic, dynamic>> sent(String method) => calls
      .where((c) => c.method == method)
      .map((c) => c.arguments as Map<dynamic, dynamic>);

  /// What the phone says it holds: the daily reminder, and these ids.
  void holding(List<int> ids) => answers['pendingNotificationRequests'] = [
        for (final id in ids) {'id': id, 'title': 't', 'body': 'b'},
      ];

  Map<String, dynamic> argumentsOf(String method) => Map<String, dynamic>.from(
        calls.lastWhere((c) => c.method == method).arguments as Map,
      );

  LocalNotificationsReminderPlatform platformOn(TargetPlatform target) {
    debugDefaultTargetPlatformOverride = target;
    if (target == TargetPlatform.android) {
      AndroidFlutterLocalNotificationsPlugin.registerWith();
    } else {
      IOSFlutterLocalNotificationsPlugin.registerWith();
    }
    return LocalNotificationsReminderPlatform();
  }

  setUp(() {
    calls.clear();
    zone = 'Asia/Kolkata';
    answers = {
      'initialize': true,
      'zonedSchedule': null,
      'cancel': null,
      'pendingNotificationRequests': <Object?>[],
      'requestNotificationsPermission': true,
      'areNotificationsEnabled': true,
      'requestPermissions': true,
      'checkPermissions': {'isEnabled': true},
      'getNotificationAppLaunchDetails': null,
    };
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(notifications, (call) async {
      calls.add(call);
      return answers[call.method];
    });
    messenger.setMockMethodCallHandler(timezoneChannel, (call) async {
      final value = zone;
      if (value is Exception) throw value;
      return value;
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(notifications, null);
    messenger.setMockMethodCallHandler(timezoneChannel, null);
  });

  test('works on Android and iPhone only', () {
    for (final (target, supported) in [
      (TargetPlatform.android, true),
      (TargetPlatform.iOS, true),
      (TargetPlatform.macOS, false),
      (TargetPlatform.windows, false),
      (TargetPlatform.linux, false),
    ]) {
      debugDefaultTargetPlatformOverride = target;
      expect(
        LocalNotificationsReminderPlatform().isSupported,
        supported,
        reason: '$target',
      );
    }
  });

  group('on Android', () {
    test('repeats each day on the wall clock, and is inexact', () async {
      final platform = platformOn(TargetPlatform.android);

      await platform.schedule(ReminderTime.standard, text);

      final sent = argumentsOf('zonedSchedule');
      expect(sent['id'], 1);
      expect(sent['title'], text.title);
      expect(sent['body'], text.body);
      expect(sent['payload'], LocalNotificationsReminderPlatform.payload);
      expect(
        sent['matchDateTimeComponents'],
        DateTimeComponents.time.index,
        reason: 'daily, on the time alone',
      );
      final android =
          Map<String, dynamic>.from(sent['platformSpecifics'] as Map);
      expect(
        android['scheduleMode'],
        'inexactAllowWhileIdle',
        reason: 'no exact-alarm permission',
      );
      expect(android['channelId'], 'daily_hukamnama');
      expect(android['channelName'], text.channelName);
      expect(android['channelDescription'], text.channelDescription);
      expect(android['importance'], Importance.defaultImportance.value);
      expect(android['category'], 'reminder');
      expect(sent['timeZoneName'], 'Asia/Kolkata');
      expect(
        (sent['scheduledDateTime'] as String).split('T').last,
        '07:00:00',
      );
    });

    test('schedules a first moment that is ahead', () async {
      final platform = platformOn(TargetPlatform.android);

      await platform.schedule(const ReminderTime(23, 59), text);

      final sent = argumentsOf('zonedSchedule');
      final first = DateTime.parse(sent['scheduledDateTimeISO8601'] as String);
      expect(first.isAfter(DateTime.now()), isTrue);
    });

    test('sets one reminder: setting it again replaces it', () async {
      final platform = platformOn(TargetPlatform.android);

      await platform.schedule(ReminderTime.standard, text);
      await platform.schedule(const ReminderTime(6, 0), text);

      final ids = calls
          .where((c) => c.method == 'zonedSchedule')
          .map((c) => (c.arguments as Map)['id']);
      expect(ids, [1, 1]);
    });

    test('starts the plugin with the notification icon, and asks nothing',
        () async {
      final platform = platformOn(TargetPlatform.android);

      await platform.start(() {});

      expect(argumentsOf('initialize')['defaultIcon'], 'ic_notification');
      expect(
        calls.map((c) => c.method),
        isNot(contains('requestNotificationsPermission')),
      );
    });

    test('starts once, however often it is asked', () async {
      final platform = platformOn(TargetPlatform.android);

      await platform.start(() {});
      await platform.start(() {});
      await platform.schedule(ReminderTime.standard, text);

      expect(calls.where((c) => c.method == 'initialize'), hasLength(1));
    });

    test('uses the zone the phone names, for a time on the listener’s clock',
        () async {
      zone = 'Australia/Sydney';
      final platform = platformOn(TargetPlatform.android);

      await platform.schedule(const ReminderTime(7, 0), text);

      final sent = argumentsOf('zonedSchedule');
      expect(sent['timeZoneName'], 'Australia/Sydney');
      expect((sent['scheduledDateTime'] as String).split('T').last, '07:00:00');
    });

    test('keeps Amritsar time in Amritsar’s zone, whatever the phone does', () async {
      // A listener in Sydney, whose clocks change in October and April.
      zone = 'Australia/Sydney';
      final platform = platformOn(TargetPlatform.android);

      await platform.schedule(ReminderTime.standard, text);

      final sent = argumentsOf('zonedSchedule');
      expect(sent['timeZoneName'], 'Asia/Kolkata',
          reason: 'the daily repeat is read in that zone, so Sydney daylight '
              'saving never moves it');
      expect((sent['scheduledDateTime'] as String).split('T').last, '07:00:00');
      expect(sent['matchDateTimeComponents'], DateTimeComponents.time.index);
    });

    test(
        'falls back to a zone with the phone’s offset when the name is unknown',
        () async {
      zone = 'Mars/Olympus_Mons';
      final platform = platformOn(TargetPlatform.android);

      await platform.start(() {});

      expect(
        tz.TZDateTime.now(tz.local).timeZoneOffset,
        DateTime.now().timeZoneOffset,
        reason: 'the wall clock must match, or 7:00 lands at the wrong hour',
      );
    });

    test('falls back the same way when the phone cannot say', () async {
      zone = PlatformException(code: 'no');
      final platform = platformOn(TargetPlatform.android);

      await platform.start(() {});

      expect(
        tz.TZDateTime.now(tz.local).timeZoneOffset,
        DateTime.now().timeZoneOffset,
      );
    });

    test('asks for permission and returns the answer', () async {
      final platform = platformOn(TargetPlatform.android);

      expect(await platform.requestPermission(), isTrue);
      answers['requestNotificationsPermission'] = false;
      expect(await platform.requestPermission(), isFalse);
    });

    test('reads whether notifications are on when the phone has no question',
        () async {
      final platform = platformOn(TargetPlatform.android);
      answers['requestNotificationsPermission'] = null;

      answers['areNotificationsEnabled'] = true;
      expect(await platform.requestPermission(), isTrue);
      answers['areNotificationsEnabled'] = false;
      expect(await platform.requestPermission(), isFalse);
    });

    test('checks permission without asking', () async {
      final platform = platformOn(TargetPlatform.android);
      answers['areNotificationsEnabled'] = false;

      expect(await platform.hasPermission(), isFalse);
      expect(
        calls.map((c) => c.method),
        isNot(contains('requestNotificationsPermission')),
      );
    });

    test('cancels reminder 1', () async {
      final platform = platformOn(TargetPlatform.android);

      await platform.cancel();

      expect(argumentsOf('cancel')['id'], 1);
    });

    test('sends a tap on the reminder, and only that, to the app', () async {
      final platform = platformOn(TargetPlatform.android);
      var taps = 0;
      await platform.start(() => taps++);

      Future<void> tapWith(String? payload) async {
        final message = const StandardMethodCodec().encodeMethodCall(
          MethodCall('didReceiveNotificationResponse', {
            'notificationId': 1,
            'actionId': null,
            'input': null,
            'payload': payload,
            'notificationResponseType': 0,
          }),
        );
        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(notifications.name, message, (_) {});
      }

      await tapWith(LocalNotificationsReminderPlatform.payload);
      expect(taps, 1);
      await tapWith('something else');
      await tapWith(null);
      expect(taps, 1);
    });

    test('knows when a tap on the reminder started the app', () async {
      final platform = platformOn(TargetPlatform.android);

      answers['getNotificationAppLaunchDetails'] = {
        'notificationLaunchedApp': true,
        'notificationResponse': {
          'notificationId': 1,
          'actionId': null,
          'input': null,
          'notificationResponseType': 0,
          'payload': LocalNotificationsReminderPlatform.payload,
        },
      };
      expect(await platform.openedByReminder(), isTrue);

      answers['getNotificationAppLaunchDetails'] = {
        'notificationLaunchedApp': true,
        'notificationResponse': {
          'notificationId': 7,
          'actionId': null,
          'input': null,
          'notificationResponseType': 0,
          'payload': 'something else',
        },
      };
      expect(await platform.openedByReminder(), isFalse);

      answers['getNotificationAppLaunchDetails'] = {
        'notificationLaunchedApp': false,
      };
      expect(await platform.openedByReminder(), isFalse);

      answers['getNotificationAppLaunchDetails'] = null;
      expect(await platform.openedByReminder(), isFalse);
    });
  });

  group('on iPhone', () {
    test('starting the plugin does not ask for permission', () async {
      final platform = platformOn(TargetPlatform.iOS);

      await platform.start(() {});

      final init = argumentsOf('initialize');
      expect(init['requestAlertPermission'], isFalse);
      expect(init['requestSoundPermission'], isFalse);
      expect(init['requestBadgePermission'], isFalse);
      expect(
        calls.map((c) => c.method),
        isNot(contains('requestPermissions')),
      );
    });

    test('asks for alerts and sound, not badges, when the app asks', () async {
      final platform = platformOn(TargetPlatform.iOS);

      expect(await platform.requestPermission(), isTrue);

      final asked = argumentsOf('requestPermissions');
      expect(asked['alert'], isTrue);
      expect(asked['sound'], isTrue);
      expect(asked['badge'], isFalse);
    });

    test('reads a refusal', () async {
      final platform = platformOn(TargetPlatform.iOS);
      answers['requestPermissions'] = false;
      expect(await platform.requestPermission(), isFalse);

      answers['checkPermissions'] = {'isEnabled': false};
      expect(await platform.hasPermission(), isFalse);
      answers['checkPermissions'] = {'isEnabled': true};
      expect(await platform.hasPermission(), isTrue);
    });

    test('repeats each day, and shows while the app is open', () async {
      final platform = platformOn(TargetPlatform.iOS);

      await platform.schedule(ReminderTime.standard, text);

      final sent = argumentsOf('zonedSchedule');
      expect(sent['matchDateTimeComponents'], DateTimeComponents.time.index);
      final details =
          Map<String, dynamic>.from(sent['platformSpecifics'] as Map);
      expect(details['presentAlert'], isTrue);
      expect(details['presentBanner'], isTrue);
      expect(details['presentSound'], isTrue);
      expect((sent['scheduledDateTime'] as String).split('T').last, '07:00:00');
    });
  });
  group('Today in Sikh history', () {
    test('fires once on its day at the time, and does not repeat', () async {
      final platform = platformOn(TargetPlatform.android);
      final notice = noticeIn(2);

      await platform.scheduleHistory(
        ReminderTime.standard,
        [notice],
        historyText,
      );

      final one = argumentsOf('zonedSchedule');
      expect(one['id'], LocalNotificationsReminderPlatform.firstHistoryId);
      expect(one['title'], historyText.title);
      expect(one['body'], notice.body);
      expect(one['payload'], LocalNotificationsReminderPlatform.historyPayload);
      expect(
        one['payload'],
        isNot(LocalNotificationsReminderPlatform.payload),
        reason: 'a tap opens the app, not the Hukamnama reader',
      );
      expect(one['matchDateTimeComponents'], isNull, reason: 'once');
      expect(
        one['scheduledDateTime'],
        '${sgpcDayIso(notice.day)}T07:00:00',
        reason: 'the date of the notice, on the phone\'s clock',
      );
      expect(one['timeZoneName'], 'Asia/Kolkata');
    });

    test('fires on the event’s day in Amritsar, for a listener in Sydney',
        () async {
      zone = 'Australia/Sydney';
      final platform = platformOn(TargetPlatform.android);
      final notice = noticeIn(3);

      await platform.scheduleHistory(
        ReminderTime.standard,
        [notice],
        historyText,
      );

      final one = argumentsOf('zonedSchedule');
      expect(one['timeZoneName'], 'Asia/Kolkata');
      expect(
        one['scheduledDateTime'],
        '${sgpcDayIso(notice.day)}T07:00:00',
        reason: '7:00 on the SGPC day, so it is that morning in Amritsar',
      );
    });

    test('keeps a time the listener picked on the phone’s own clock', () async {
      zone = 'Australia/Sydney';
      final platform = platformOn(TargetPlatform.android);
      final notice = noticeIn(3);

      await platform.scheduleHistory(
        const ReminderTime(8, 15),
        [notice],
        historyText,
      );

      final one = argumentsOf('zonedSchedule');
      expect(one['timeZoneName'], 'Australia/Sydney');
      expect(
        one['scheduledDateTime'],
        '${sgpcDayIso(notice.day)}T08:15:00',
      );
    });

    test('is quiet on Android, and shows every event when opened out',
        () async {
      final platform = platformOn(TargetPlatform.android);

      await platform.scheduleHistory(
        ReminderTime.standard,
        [noticeIn(2)],
        historyText,
      );

      final android = Map<String, dynamic>.from(
        argumentsOf('zonedSchedule')['platformSpecifics'] as Map,
      );
      expect(android['channelId'], 'sikh_history');
      expect(android['channelName'], historyText.channelName);
      expect(android['channelDescription'], historyText.channelDescription);
      expect(android['importance'], Importance.low.value);
      expect(android['scheduleMode'], 'inexactAllowWhileIdle');
      expect(android['styleInformation'], isNotNull);
      expect(
        (android['styleInformation'] as Map)['bigText'],
        noticeIn(2).body,
      );
    });

    test('is quiet on iPhone, and does not repeat', () async {
      final platform = platformOn(TargetPlatform.iOS);

      await platform.scheduleHistory(
        ReminderTime.standard,
        [noticeIn(2)],
        historyText,
      );

      final one = argumentsOf('zonedSchedule');
      expect(one['matchDateTimeComponents'], isNull);
      final details =
          Map<String, dynamic>.from(one['platformSpecifics'] as Map);
      expect(details['presentAlert'], isTrue);
      expect(details['presentSound'], isFalse);
    });

    test('gives each day its own id, from 100 up', () async {
      final platform = platformOn(TargetPlatform.android);

      await platform.scheduleHistory(
        ReminderTime.standard,
        [noticeIn(1), noticeIn(3), noticeIn(9)],
        historyText,
      );

      expect(sent('zonedSchedule').map((a) => a['id']), [100, 101, 102]);
    });

    test('sets no notification for a day whose time has gone', () async {
      final platform = platformOn(TargetPlatform.android);

      await platform.scheduleHistory(
        ReminderTime.standard,
        [noticeIn(-3), noticeIn(-1), noticeIn(2)],
        historyText,
      );

      final ids = sent('zonedSchedule').map((a) => a['id']);
      expect(ids, [100], reason: 'the next id goes to the next live day');
    });

    test('keeps at most 30, far under the 64 that iOS holds', () async {
      final platform = platformOn(TargetPlatform.iOS);

      await platform.scheduleHistory(
        ReminderTime.standard,
        [for (var i = 1; i <= 45; i++) noticeIn(i)],
        historyText,
      );

      expect(sent('zonedSchedule'), hasLength(30));
      expect(sent('zonedSchedule').map((a) => a['id']).last, 129);
    });

    test('removes the old ones that the new schedule does not replace',
        () async {
      holding([1, 100, 101, 102, 103]);
      final platform = platformOn(TargetPlatform.android);

      await platform.scheduleHistory(
        ReminderTime.standard,
        [noticeIn(2), noticeIn(4)],
        historyText,
      );

      expect(
        sent('cancel').map((a) => a['id']),
        [102, 103],
        reason: 'the daily reminder (1) and the 2 replaced ids stay',
      );
    });

    test('cancels none when there is nothing left over', () async {
      holding([1, 100, 101]);
      final platform = platformOn(TargetPlatform.android);

      await platform.scheduleHistory(
        ReminderTime.standard,
        [noticeIn(2), noticeIn(4)],
        historyText,
      );

      expect(sent('cancel'), isEmpty);
    });

    test('cancelHistory removes all of them and leaves the reminder', () async {
      holding([1, 100, 101, 129, 130, 5]);
      final platform = platformOn(TargetPlatform.android);

      await platform.cancelHistory();

      expect(
        sent('cancel').map((a) => a['id']),
        [100, 101, 129],
        reason: 'not the reminder (1), and not an id outside the range',
      );
    });

    test('an empty list removes the old ones and sets none', () async {
      holding([100, 101]);
      final platform = platformOn(TargetPlatform.android);

      await platform.scheduleHistory(ReminderTime.standard, [], historyText);

      expect(sent('zonedSchedule'), isEmpty);
      expect(sent('cancel').map((a) => a['id']), [100, 101]);
    });

    test('never asks the phone for permission', () async {
      final platform = platformOn(TargetPlatform.android);

      await platform.scheduleHistory(
        ReminderTime.standard,
        [noticeIn(2)],
        historyText,
      );
      await platform.cancelHistory();

      expect(
        calls.map((c) => c.method),
        isNot(contains('requestNotificationsPermission')),
      );
    });
  });
}
