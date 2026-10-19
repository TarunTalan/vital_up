import 'dart:async';
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
    if (data is Map) {
      final text = data['text'];
      if (text is! String) return;
      FlutterForegroundTask.updateService(
        notificationTitle: ForegroundServiceManager._title,
        notificationText: text,
        notificationButtons: ForegroundServiceManager._buttons(
          paused: data['paused'] == true,
        ),
      );
    }
  }

  /// Pause / Resume in the tray: the workout runs in the app's isolate, so
  /// hand the press over ([ForegroundServiceManager.buttonPresses]).
  @override
  void onNotificationButtonPressed(String id) {
    FlutterForegroundTask.sendDataToMain(id);
  }
}

class ForegroundServiceManager {
  /// The service is for workouts only. It's declared as a location service
  /// (Android 14+ checks the type), so it can't also carry audio downloads:
  /// starting it for one without location permission crashes the app.
  static bool _trackingActive = false;
  static String? _lastStatsText;
  static bool? _lastPaused;

  static const _title = 'VitalUp Active Workout';
  static const pauseButton = 'gps_workout_pause';
  static const resumeButton = 'gps_workout_resume';

  static List<NotificationButton> _buttons({required bool paused}) => [
    paused
        ? const NotificationButton(id: resumeButton, text: 'Resume')
        : const NotificationButton(id: pauseButton, text: 'Pause'),
  ];

  static final _buttonPresses = StreamController<String>.broadcast();
  static bool _listening = false;

  /// Pause / Resume tapped on the workout notification ([pauseButton] or
  /// [resumeButton]).
  static Stream<String> get buttonPresses {
    if (!_listening && Platform.isAndroid) {
      _listening = true;
      FlutterForegroundTask.addTaskDataCallback(handleTaskData);
    }
    return _buttonPresses.stream;
  }

  /// Data the service sent to the app; only button presses are expected.
  @visibleForTesting
  static void handleTaskData(Object data) {
    if (data == pauseButton || data == resumeButton) {
      _buttonPresses.add(data as String);
    }
  }

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
    bool paused = false,
  }) async {
    if (!Platform.isAndroid) return;
    _trackingActive = true;
    // The port is found by name, and any other engine that runs main()
    // takes the name over: claim it again for the isolate running the
    // workout, or Pause / Resume presses go there instead.
    FlutterForegroundTask.initCommunicationPort();
    _lastStatsText = null;
    _lastPaused = paused;
    final text = paused
        ? 'Paused'
        : 'Tracking your $activityName...';

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
        notificationTitle: _title,
        notificationText: text,
        notificationButtons: _buttons(paused: paused),
      );
      return;
    }

    _configure(
      channelId: 'activity_tracking_channel',
      channelName: 'Activity Tracking Service',
      channelDescription: 'Keeps activity tracking GPS alive in background',
    );

    await FlutterForegroundTask.startService(
      notificationTitle: _title,
      notificationText: text,
      notificationButtons: _buttons(paused: paused),
      notificationIcon: const NotificationIcon(
        metaDataName: 'com.pravera.flutter_foreground_task.NOTIFICATION_ICON',
      ),
      callback: startCallback,
    );
  }

  /// [paused] picks the notification's button (Resume, or Pause).
  static Future<void> update(String statsText, {bool paused = false}) async {
    if (!Platform.isAndroid || !_trackingActive) return;
    // Called on every tick and GPS fix; skip the platform round-trip when
    // nothing shown has changed.
    if (statsText == _lastStatsText && paused == _lastPaused) return;
    _lastStatsText = statsText;
    _lastPaused = paused;
    // Callers don't await this; a failed notification update must never
    // surface as an uncaught error mid-workout.
    try {
      if (await FlutterForegroundTask.isRunningService) {
        FlutterForegroundTask.sendDataToTask({
          'text': statsText,
          'paused': paused,
        });
      }
    } catch (e) {
      debugPrint('Workout notification update failed: $e');
    }
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    _trackingActive = false;
    _lastStatsText = null;
    _lastPaused = null;
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}
