import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:vital_up/core/monitoring/crash_reporter.dart';

@pragma('vm:entry-point')
void startCallback() {
  CrashReporter.hookCurrentIsolate();
  FlutterForegroundTask.setTaskHandler(LocationTaskHandler());
}

class LocationTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Service started successfully
  }

  @override
  void onRepeatEvent(DateTime timestamp) async {
    // Run periodically to keep CPU active if needed
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // Handle destruction/cleanup
  }

  @override
  void onReceiveData(Object data) {
    if (data is String) {
      FlutterForegroundTask.updateService(
        notificationTitle: 'VitalUp Active Workout',
        notificationText: data,
      );
    }
  }
}

class ForegroundServiceManager {
  /// The service is for workouts only. It's declared as a location service
  /// (Android 14+ checks the type), so it can't also carry audio downloads:
  /// starting it for one without location permission crashes the app.
  static bool _trackingActive = false;
  static String? _lastStatsText;

  static void init() {
    if (Platform.isAndroid) {
      FlutterForegroundTask.initCommunicationPort();
    }
  }

  static void _configure({
    required String channelId,
    required String channelName,
    required String channelDescription,
  }) {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: channelId,
        channelName: channelName,
        channelDescription: channelDescription,
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
      ),
    );
  }

  static Future<void> start({
    required String activityName,
  }) async {
    if (!Platform.isAndroid) return;
    _trackingActive = true;
    _lastStatsText = null;

    // Request notification permission for Android 13+
    final reqResult = await FlutterForegroundTask.checkNotificationPermission();
    if (reqResult != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    // No battery-optimisation exemption: a location foreground service
    // keeps GPS running under Doze, and Play restricts that permission.

    if (await FlutterForegroundTask.isRunningService) {
      // Still up from an earlier workout: take over its notification.
      await FlutterForegroundTask.updateService(
        notificationTitle: 'VitalUp Active Workout',
        notificationText: 'Tracking your $activityName...',
      );
      return;
    }

    _configure(
      channelId: 'activity_tracking_channel',
      channelName: 'Activity Tracking Service',
      channelDescription: 'Keeps activity tracking GPS alive in background',
    );

    await FlutterForegroundTask.startService(
      notificationTitle: 'VitalUp Active Workout',
      notificationText: 'Tracking your $activityName...',
      notificationIcon: const NotificationIcon(
        metaDataName: 'com.pravera.flutter_foreground_task.NOTIFICATION_ICON',
      ),
      callback: startCallback,
    );
  }

  static Future<void> update(String statsText) async {
    if (!Platform.isAndroid || !_trackingActive) return;
    // Called on every tick and GPS fix; skip the platform round-trip when
    // the text hasn't changed.
    if (statsText == _lastStatsText) return;
    _lastStatsText = statsText;
    // Callers don't await this; a failed notification update must never
    // surface as an uncaught error mid-workout.
    try {
      if (await FlutterForegroundTask.isRunningService) {
        FlutterForegroundTask.sendDataToTask(statsText);
      }
    } catch (e) {
      debugPrint('Workout notification update failed: $e');
    }
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    _trackingActive = false;
    _lastStatsText = null;
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}
