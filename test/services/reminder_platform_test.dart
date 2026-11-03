import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/models/reminder_time.dart';
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

    test('uses the zone the phone names', () async {
      zone = 'Australia/Sydney';
      final platform = platformOn(TargetPlatform.android);

      await platform.schedule(ReminderTime.standard, text);

      expect(argumentsOf('zonedSchedule')['timeZoneName'], 'Australia/Sydney');
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
}
