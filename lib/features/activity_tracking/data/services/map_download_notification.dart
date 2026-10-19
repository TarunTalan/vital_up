import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Offline map downloads in the notification tray: a progress bar while the
/// pack downloads (it keeps going with the app in the background, as long
/// as Android keeps the app's process), then a short "ready" note.
///
/// No foreground service: if Android ends the app the download stops and
/// the tracking screen picks it up again on its next visit.
class MapDownloadNotifier {
  static const notificationId = 7302;

  static const _channel = AndroidNotificationChannel(
    'vitalup_map_downloads',
    'Offline map downloads',
    description: 'Progress of the offline map for workouts without signal',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
    showBadge: false,
  );

  final FlutterLocalNotificationsPlugin plugin;
  bool _channelReady = false;
  int _lastPercent = -1;

  MapDownloadNotifier(this.plugin);

  /// [fraction] 0-1. Only redrawn when the whole percent changes: the map
  /// SDK reports many times a second.
  Future<void> progress(double fraction) async {
    final percent = (fraction.clamp(0.0, 1.0) * 100).floor();
    if (percent == _lastPercent) return;
    _lastPercent = percent;
    await _show(
      title: 'Downloading offline map',
      body: '$percent%',
      details: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.low,
        priority: Priority.low,
        category: AndroidNotificationCategory.progress,
        ongoing: true,
        autoCancel: false,
        silent: true,
        onlyAlertOnce: true,
        showWhen: false,
        showProgress: true,
        maxProgress: 100,
        progress: percent,
        indeterminate: percent == 0,
      ),
    );
  }

  /// Replaces the progress with a note that dismisses itself.
  Future<void> done() async {
    _lastPercent = -1;
    await _show(
      title: 'Offline map ready',
      body: 'Your area is saved for workouts without signal.',
      details: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.low,
        priority: Priority.low,
        silent: true,
        autoCancel: true,
        timeoutAfter: 10000,
      ),
    );
  }

  /// A failed download is retried on the next visit; nothing to report.
  Future<void> cancel() async {
    _lastPercent = -1;
    try {
      await plugin.cancel(id: notificationId);
    } catch (e) {
      debugPrint('Cancelling map download notification failed: $e');
    }
  }

  Future<void> _show({
    required String title,
    required String body,
    required AndroidNotificationDetails details,
  }) async {
    try {
      if (!_channelReady) {
        await plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.createNotificationChannel(_channel);
        _channelReady = true;
      }
      await plugin.show(
        id: notificationId,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: details,
          iOS: const DarwinNotificationDetails(presentSound: false),
        ),
      );
    } catch (e) {
      debugPrint('Map download notification failed: $e');
    }
  }
}
