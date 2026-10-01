import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:vital_up/features/reminders/domain/entities/reminder.dart';
import 'package:vital_up/features/reminders/domain/reminder_schedule.dart';

/// Puts reminders into the system notification schedule. The only code that
/// talks to the plugin for reminders.
class ReminderScheduler {
  final FlutterLocalNotificationsPlugin _plugin;

  ReminderScheduler(this._plugin);

  static const _channel = AndroidNotificationChannel(
    'vitalup_reminders',
    'Reminders',
    description: 'Your daily activity, meal, water and sleep reminders',
  );

  bool _ready = false;

  /// Call once at startup, after the plugin is initialised (PushService).
  Future<void> init() async {
    if (_ready) return;
    tz_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (e) {
      debugPrint('Reminder time zone unknown, using UTC: $e');
    }
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
    _ready = true;
  }

  /// Asks for notification permission. True when granted (or not needed).
  Future<bool> requestPermission() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? true;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        return await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
    } catch (e) {
      debugPrint('Reminder permission request failed: $e');
    }
    return true;
  }

  /// Notification action on water reminders: logs a glass without opening
  /// the app (see `handleReminderAction`).
  static const logWaterAction = 'log_water';
  static const logWaterMl = 250;

  /// iOS category carrying [logWaterAction]; registered at plugin start-up.
  static const waterCategory = 'water_reminder';

  static final darwinCategories = [
    DarwinNotificationCategory(
      waterCategory,
      actions: [
        DarwinNotificationAction.plain(logWaterAction, '+$logWaterMl ml'),
      ],
    ),
  ];

  /// Schedules [plan], returning the ids that were scheduled. Reminders in
  /// [skippedToday] start tomorrow (the habit is already done today).
  Future<List<int>> schedule(
    ReminderSchedulePlan plan, {
    Set<String> skippedToday = const {},
    String? userId,
  }) async {
    if (!_ready) await init();
    final now = tz.TZDateTime.now(tz.local);
    final tomorrow = tz.TZDateTime(tz.local, now.year, now.month, now.day + 1);
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final scheduled = <int>[];
    for (final entry in plan.entries) {
      final r = entry.reminder;
      final skip = skippedToday.contains(r.id);
      final water = r.kind == ReminderKind.water;
      // iOS repeating triggers can't start on a later day, so a skipped
      // reminder becomes a one-off for its next time; the next resync
      // (app start, any change) makes it repeating again.
      final repeat = !(skip && isIOS);
      try {
        await _plugin.zonedSchedule(
          id: entry.id,
          title: r.title,
          body: r.body.isEmpty ? null : r.body,
          scheduledDate: _nextInstance(skip ? tomorrow : now, entry),
          payload: jsonEncode({
            'type': 'reminder',
            'route': r.route,
            if (userId != null) 'user': userId,
          }),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: !repeat
              ? null
              : entry.weekday == null
              ? DateTimeComponents.time
              : DateTimeComponents.dayOfWeekAndTime,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              category: AndroidNotificationCategory.reminder,
              actions: [
                if (water && userId != null)
                  const AndroidNotificationAction(
                    logWaterAction,
                    '+$logWaterMl ml',
                    cancelNotification: true,
                  ),
              ],
            ),
            iOS: DarwinNotificationDetails(
              categoryIdentifier: water && userId != null
                  ? waterCategory
                  : null,
            ),
          ),
        );
        scheduled.add(entry.id);
      } catch (e) {
        debugPrint('Scheduling reminder ${r.id} failed: $e');
      }
    }
    return scheduled;
  }

  Future<void> cancel(Iterable<int> ids) async {
    for (final id in ids) {
      try {
        await _plugin.cancel(id: id);
      } catch (e) {
        debugPrint('Cancelling reminder $id failed: $e');
      }
    }
  }

  static tz.TZDateTime _nextInstance(
    tz.TZDateTime now,
    ScheduledReminder entry,
  ) {
    var date = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      entry.time.hour,
      entry.time.minute,
    );
    while (!date.isAfter(now) ||
        (entry.weekday != null && date.weekday != entry.weekday)) {
      date = tz.TZDateTime(
        tz.local,
        date.year,
        date.month,
        date.day + 1,
        entry.time.hour,
        entry.time.minute,
      );
    }
    return date;
  }
}
