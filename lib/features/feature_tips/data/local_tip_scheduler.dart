import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:vital_up/core/services/notification_icons.dart';
import 'package:vital_up/features/feature_tips/data/feature_tips_service.dart';
import 'package:vital_up/features/feature_tips/domain/feature_tip.dart';
import 'package:vital_up/features/reminders/data/reminder_scheduler.dart';

/// Feature tips as local notifications on their own quiet channel (no
/// sound or pop-up), so they can be switched off in the system settings
/// apart from reminders. The tip's icon is drawn as the large icon: its
/// glyph in white on a brand circle.
class LocalTipScheduler implements TipScheduler {
  static const notificationId = 7401;

  static const _channel = AndroidNotificationChannel(
    'vitalup_feature_tips',
    'Feature tips',
    description: 'Now and then, a feature you may not have tried',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
    showBadge: false,
  );

  final FlutterLocalNotificationsPlugin plugin;

  /// Owns the time zone setup and the permission check.
  final ReminderScheduler reminders;
  bool _channelReady = false;

  LocalTipScheduler(this.plugin, this.reminders);

  @override
  Future<bool?> permitted() => reminders.permissionGranted();

  @override
  Future<void> schedule(FeatureTip tip, DateTime at) async {
    // Time zones loaded and the device's zone current.
    await reminders.init();
    if (!_channelReady) {
      await plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);
      _channelReady = true;
    }
    final icon = await NotificationIcons.largeIcon(tip.iconAsset);
    await plugin.zonedSchedule(
      id: notificationId,
      title: tip.title,
      body: tip.body,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      payload: jsonEncode({'type': 'tip', 'route': ?tip.route}),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.low,
          priority: Priority.low,
          category: AndroidNotificationCategory.recommendation,
          autoCancel: true,
          largeIcon: icon,
          styleInformation: BigTextStyleInformation(tip.body),
        ),
        iOS: const DarwinNotificationDetails(presentSound: false),
      ),
    );
  }

  @override
  Future<void> cancel() async {
    try {
      await plugin.cancel(id: notificationId);
    } catch (e) {
      debugPrint('Feature tips: cancel failed: $e');
    }
  }
}
