import 'dart:io';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void startCallback() {
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
  static void init() {
    if (Platform.isAndroid) {
      FlutterForegroundTask.initCommunicationPort();
    }
  }

  static Future<void> start({
    required String activityName,
  }) async {
    if (!Platform.isAndroid) return;

    // Request notification permission for Android 13+
    final reqResult = await FlutterForegroundTask.checkNotificationPermission();
    if (reqResult != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    final ignoringBatteryOptimizations =
        await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    if (!ignoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'activity_tracking_channel',
        channelName: 'Activity Tracking Service',
        channelDescription: 'Keeps activity tracking GPS alive in background',
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

    await FlutterForegroundTask.startService(
      notificationTitle: 'VitalUp Active Workout',
      notificationText: 'Tracking your $activityName...',
      notificationIcon: const NotificationIcon(
        metaDataName: 'com.example.vital_up.MainActivity',
      ),
      callback: startCallback,
    );
  }

  static Future<void> update(String statsText) async {
    if (!Platform.isAndroid) return;
    if (await FlutterForegroundTask.isRunningService) {
      FlutterForegroundTask.sendDataToTask(statsText);
    }
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}
