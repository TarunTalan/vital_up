import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:vital_up/core/theme/app_colors.dart';
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

  /// Large icon size in px (the system scales it down).
  static const _iconPx = 192;

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
    final icon = await _icon(tip.iconAsset);
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
          largeIcon: icon == null ? null : ByteArrayAndroidBitmap(icon),
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

  /// PNG bytes of [asset] in white on a brand-coloured circle; null if the
  /// SVG can't be read (the notification then shows without it).
  static Future<Uint8List?> _icon(String asset) async {
    try {
      final info = await vg.loadPicture(SvgAssetLoader(asset), null);
      const size = _iconPx * 1.0;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawCircle(
        const ui.Offset(size / 2, size / 2),
        size / 2,
        ui.Paint()..color = AppColors.primary,
      );
      const glyph = size * 0.5;
      final scale = glyph / info.size.longestSide;
      canvas.save();
      canvas.translate(
        (size - info.size.width * scale) / 2,
        (size - info.size.height * scale) / 2,
      );
      canvas.scale(scale);
      canvas.saveLayer(
        ui.Offset.zero & info.size,
        ui.Paint()
          ..colorFilter = const ui.ColorFilter.mode(
            AppColors.white,
            BlendMode.srcIn,
          ),
      );
      canvas.drawPicture(info.picture);
      canvas.restore();
      canvas.restore();
      info.picture.dispose();
      final image = await recorder.endRecording().toImage(_iconPx, _iconPx);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return png?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Feature tips: icon failed: $e');
      return null;
    }
  }
}
