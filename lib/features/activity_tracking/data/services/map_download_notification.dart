import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Offline map downloads in the notification tray: a progress bar while the
/// pack downloads (it keeps going with the app in the background, as long
/// as Android keeps the app's process), then a short "ready" note.
///
/// No foreground service: if Android ends the app the download stops and
/// the next app start (or the tracking screen) picks it up again.
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
  /// SDK reports many times a second. [name]: an area the user picked.
  Future<void> progress(double fraction, {String? name}) async {
    final percent = (fraction.clamp(0.0, 1.0) * 100).floor();
    if (percent == _lastPercent) return;
    _lastPercent = percent;
    await _show(
      title: name == null ? 'Downloading offline map' : 'Downloading $name',
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

  /// Replaces the progress with a note; a tap opens Offline maps (where
  /// more places can be saved: the first one is how most users hear of
  /// it).
  Future<void> done({String? name}) async {
    _lastPercent = -1;
    await _show(
      title: name == null ? 'Offline map ready' : '$name is ready offline',
      body: name == null
          ? 'Your area works without signal. Tap to save more places.'
          : 'The map works there without signal.',
      payload: jsonEncode({'route': 'offline-maps'}),
      details: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.low,
        priority: Priority.low,
        silent: true,
        autoCancel: true,
      ),
    );
  }

  /// A failed download is retried later; nothing to report.
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
    String? payload,
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
        payload: payload,
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
