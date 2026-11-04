import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:live_darbar/src/core/history_schedule.dart';
import 'package:live_darbar/src/core/reminder_schedule.dart';
import 'package:live_darbar/src/models/reminder_time.dart';
import 'package:timezone/data/latest_10y.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// The words of the notification, in the app's language at the time it is set.
///
/// A repeating notification keeps the text it was scheduled with, so the
/// controller sets it again when the language changes.
@immutable
class ReminderText {
  const ReminderText({
    required this.title,
    required this.body,
    required this.channelName,
    required this.channelDescription,
  });

  final String title;
  final String body;

  /// The Android channel's name and description, which the phone shows in its
  /// notification settings.
  final String channelName;
  final String channelDescription;
}

/// The words that "Today in Sikh history" shares on every day, in the app's
/// language at the time it is set. The words of each day are in
/// [HistoryNotice].
@immutable
class HistoryText {
  const HistoryText({
    required this.title,
    required this.channelName,
    required this.channelDescription,
  });

  final String title;

  /// The Android channel's name and description, which the phone shows in its
  /// notification settings.
  final String channelName;
  final String channelDescription;
}

/// What the daily reminder, and "Today in Sikh history", need from the phone.
///
/// An interface, so the controllers' rules run in a test with no phone. The one
/// real implementation is [LocalNotificationsReminderPlatform], and it is the
/// only code that knows the notification plugin.
abstract interface class ReminderPlatform {
  /// Whether this platform can show a reminder when the app is closed. Android
  /// and iPhone can. The web cannot, so it never asks.
  bool get isSupported;

  /// Gets the plugin ready, and sends each tap on the reminder to [onTap].
  /// Safe to call again.
  Future<void> start(VoidCallback onTap);

  /// Asks the phone to let the app show notifications, if it has not been
  /// asked. True when notifications are allowed.
  Future<bool> requestPermission();

  /// Whether the phone lets the app show notifications now. Asks nothing.
  Future<bool> hasPermission();

  /// Sets the reminder to repeat each day at [time], and replaces the one set
  /// before. The time is read on the clock of its zone: Amritsar's, whatever
  /// the phone does with daylight saving, or the phone's own.
  Future<void> schedule(ReminderTime time, ReminderText text);

  /// Removes the reminder.
  Future<void> cancel();

  /// Sets 1 quiet notification for each of [notices], to fire once on its day
  /// at [time], and replaces the ones set before. The day and the time are read
  /// on the clock of the time's zone. A
  /// day whose [time] has passed gets none. The daily reminder is not touched.
  ///
  /// The phone keeps at most [kHistoryDays] of them. A longer list is cut
  /// there.
  Future<void> scheduleHistory(
    ReminderTime time,
    List<HistoryNotice> notices,
    HistoryText text,
  );

  /// Removes every "Today in Sikh history" notification.
  Future<void> cancelHistory();

  /// Whether a tap on the reminder started the app, from closed. A tap while
  /// the app runs goes to the callback given to [start] instead.
  Future<bool> openedByReminder();
}

final reminderPlatformProvider = Provider<ReminderPlatform>(
  (ref) => LocalNotificationsReminderPlatform(),
);

/// Android and iPhone, through `flutter_local_notifications`.
///
/// One notification, repeating daily on the wall-clock time. The system keeps
/// it and shows it with the app closed. On Android the plugin sets it again
/// after a reboot and after an app update, with receivers that the manifest
/// declares. On iPhone the system keeps it.
class LocalNotificationsReminderPlatform implements ReminderPlatform {
  LocalNotificationsReminderPlatform([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// What the notification carries, so a tap is known to be this one.
  @visibleForTesting
  static const payload = 'open_hukamnama';

  /// What a "Today in Sikh history" notification carries. A tap on it opens
  /// the app and nothing more, so it is not [payload].
  @visibleForTesting
  static const historyPayload = 'open_history';

  /// The zone of Amritsar in the `timezone` package.
  static const _amritsarZone = 'Asia/Kolkata';

  static const _id = 1;
  static const _channelId = 'daily_hukamnama';

  /// "Today in Sikh history" uses the ids from [firstHistoryId] up, 1 for each
  /// day, so the daily reminder's id is never touched.
  @visibleForTesting
  static const firstHistoryId = 100;
  static const _historyChannelId = 'sikh_history';

  /// The small icon on Android. `res/raw/keep.xml` stops the release build
  /// from removing it, because only a name in this string points to it.
  static const _androidIcon = 'ic_notification';

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _ready;
  VoidCallback? _onTap;

  @override
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<void> start(VoidCallback onTap) {
    _onTap = onTap;
    return _initialize();
  }

  Future<void> _initialize() => _ready ??= _initializeOnce();

  Future<void> _initializeOnce() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(await _deviceLocation());
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(_androidIcon),
        // Initialising must not ask. The listener says yes in the app first,
        // and the phone's question comes after that.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == payload) _onTap?.call();
      },
    );
  }

  /// The clock that [time] is read on. Amritsar's is `Asia/Kolkata` and never
  /// moves. The phone's own is where the phone is now.
  tz.Location _clockOf(ReminderTime time) => time.zone == ReminderZone.amritsar
      ? tz.getLocation(_amritsarZone)
      : tz.local;

  /// The phone's time zone, as the `timezone` package knows it.
  ///
  /// If the phone's name for its zone is one the package does not know, the
  /// zone is the first one that has the phone's offset now. That keeps the
  /// wall-clock time right. UTC would put a 7:00 reminder at the wrong hour
  /// for everyone, silently.
  Future<tz.Location> _deviceLocation() async {
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      return tz.getLocation(zone.identifier);
    } catch (e) {
      debugPrint('[reminder] time zone not found by name: $e');
    }
    final offset = DateTime.now().timeZoneOffset;
    for (final location in tz.timeZoneDatabase.locations.values) {
      if (tz.TZDateTime.now(location).timeZoneOffset == offset) {
        return location;
      }
    }
    return tz.UTC;
  }

  @override
  Future<bool> requestPermission() async {
    await _initialize();
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        // Android 12 and older have no question to ask. The call answers
        // with whether notifications are on.
        return await android?.requestNotificationsPermission() ??
            await android?.areNotificationsEnabled() ??
            false;
      case TargetPlatform.iOS:
        return await _plugin
                .resolvePlatformSpecificImplementation<
                    IOSFlutterLocalNotificationsPlugin>()
                ?.requestPermissions(alert: true, sound: true) ??
            false;
      default:
        return false;
    }
  }

  @override
  Future<bool> hasPermission() async {
    await _initialize();
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return await _plugin
                .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin>()
                ?.areNotificationsEnabled() ??
            false;
      case TargetPlatform.iOS:
        final options = await _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.checkPermissions();
        return options?.isEnabled ?? false;
      default:
        return false;
    }
  }

  @override
  Future<void> schedule(ReminderTime time, ReminderText text) async {
    await _initialize();
    await _plugin.zonedSchedule(
      id: _id,
      title: text.title,
      body: text.body,
      scheduledDate: nextReminder(tz.TZDateTime.now(_clockOf(time)), time),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          text.channelName,
          channelDescription: text.channelDescription,
          // The default level: a sound and a place in the shade, but no
          // pop-up over whatever the listener is doing.
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          category: AndroidNotificationCategory.reminder,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentList: true,
          presentSound: true,
        ),
      ),
      // Inexact: the system may move it by a few minutes to save power. That
      // needs no alarm permission, and a morning reminder does not need the
      // second. It still fires in Doze.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
  }

  @override
  Future<void> cancel() async {
    await _initialize();
    await _plugin.cancel(id: _id);
  }

  @override
  Future<void> scheduleHistory(
    ReminderTime time,
    List<HistoryNotice> notices,
    HistoryText text,
  ) async {
    await _initialize();
    final now = tz.TZDateTime.now(_clockOf(time));
    var used = 0;
    for (final notice in notices.take(kHistoryDays)) {
      final at = timeOnDay(now, notice.day, time);
      if (at == null) continue;
      await _plugin.zonedSchedule(
        // The same id replaces the notification set before it.
        id: firstHistoryId + used,
        title: text.title,
        body: notice.body,
        scheduledDate: at,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _historyChannelId,
            text.channelName,
            channelDescription: text.channelDescription,
            // Quiet: a place in the shade, with no sound and no pop-up. It is
            // something to read, not something to answer.
            importance: Importance.low,
            priority: Priority.low,
            category: AndroidNotificationCategory.recommendation,
            // Shows every event when the notification is opened out.
            styleInformation: BigTextStyleInformation(notice.body),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBanner: true,
            presentList: true,
            presentSound: false,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: historyPayload,
      );
      used++;
    }
    await _cancelHistoryFrom(used);
  }

  @override
  Future<void> cancelHistory() async {
    await _initialize();
    await _cancelHistoryFrom(0);
  }

  /// Removes the history notifications from number [used] on: the ones that
  /// the latest schedule did not replace.
  Future<void> _cancelHistoryFrom(int used) async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (request.id >= firstHistoryId + used &&
          request.id < firstHistoryId + kHistoryDays) {
        await _plugin.cancel(id: request.id);
      }
    }
  }

  @override
  Future<bool> openedByReminder() async {
    await _initialize();
    final details = await _plugin.getNotificationAppLaunchDetails();
    return details != null &&
        details.didNotificationLaunchApp &&
        details.notificationResponse?.payload == payload;
  }
}
