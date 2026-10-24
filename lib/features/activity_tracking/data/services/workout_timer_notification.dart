import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/features/activity_tracking/data/services/workout_timer_store.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/workout_timer.dart';

/// Shows the workout being timed in the notification tray.
abstract class WorkoutTimerNotifier {
  Future<void> show(WorkoutTimer timer, DateTime now);
  Future<void> cancel();
}

/// The timer as an ongoing notification: a live system chronometer while
/// it runs (no app code ticking), the time so far while paused, and Pause /
/// Resume buttons that work with the app closed
/// ([handleWorkoutTimerAction]). Tapping it opens the timer screen.
class LocalWorkoutTimerNotifier implements WorkoutTimerNotifier {
  static const notificationId = 7301;
  static const pauseAction = 'workout_pause';
  static const resumeAction = 'workout_resume';
  static const route = 'workout-timer';

  static const _channel = AndroidNotificationChannel(
    'vitalup_workout_timer',
    'Workout timer',
    description: 'The time of a workout you are timing',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
    showBadge: false,
  );

  final FlutterLocalNotificationsPlugin plugin;
  bool _channelReady = false;

  LocalWorkoutTimerNotifier(this.plugin);

  /// HH:MM:SS, as on the timer screen.
  static String _clock(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes.remainder(60))}:'
        '${two(d.inSeconds.remainder(60))}';
  }

  static bool handles(String? actionId) =>
      actionId == pauseAction || actionId == resumeAction;

  @override
  Future<void> show(WorkoutTimer timer, DateTime now) async {
    try {
      if (!_channelReady) {
        await plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.createNotificationChannel(_channel);
        _channelReady = true;
      }
      final elapsed = timer.elapsed(now);
      final running = timer.isRunning && !timer.isAtLimit(now);
      final body = running
          ? 'Timing. Tap to finish.'
          : timer.isAtLimit(now)
          ? 'Stopped at 6 hours. Tap to save it.'
          : 'Paused at ${_clock(elapsed)}';
      await plugin.show(
        id: notificationId,
        title: '${timer.type.label} workout',
        body: body,
        payload: jsonEncode({'route': route}),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.low,
            priority: Priority.low,
            category: AndroidNotificationCategory.stopwatch,
            ongoing: true,
            autoCancel: false,
            silent: true,
            onlyAlertOnce: true,
            // The system counts up from here, so the tray stays right
            // without the app running.
            showWhen: running,
            usesChronometer: running,
            when: running ? now.subtract(elapsed).millisecondsSinceEpoch : null,
            // The plugin removes a notification when one of its buttons is
            // tapped unless told not to; the action shows it again instead.
            actions: [
              if (running)
                const AndroidNotificationAction(
                  pauseAction,
                  'Pause',
                  cancelNotification: false,
                )
              else if (!timer.isAtLimit(now))
                const AndroidNotificationAction(
                  resumeAction,
                  'Resume',
                  cancelNotification: false,
                ),
            ],
          ),
          iOS: const DarwinNotificationDetails(presentSound: false),
        ),
      );
    } catch (e) {
      debugPrint('Workout timer notification failed: $e');
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await plugin.cancel(id: notificationId);
    } catch (e) {
      debugPrint('Cancelling workout timer notification failed: $e');
    }
  }
}

/// Pause / Resume tapped on the timer notification. Updates the saved timer
/// and the notification; an open timer screen follows the store.
/// [prefs] and [plugin] are passed in when the app is running; a background
/// isolate (app closed) makes its own. [clock] is for tests.
Future<void> handleWorkoutTimerAction(
  String actionId, {
  SharedPreferences? prefs,
  FlutterLocalNotificationsPlugin? plugin,
  DateTime Function() clock = DateTime.now,
}) async {
  final background = prefs == null;
  if (background) DartPluginRegistrant.ensureInitialized();
  final store = WorkoutTimerStore(
    prefs ?? await SharedPreferences.getInstance(),
  );
  // Another isolate (the app or an earlier action) may have written since.
  await store.prefs.reload();

  var notifications = plugin;
  if (notifications == null) {
    notifications = FlutterLocalNotificationsPlugin();
    await notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }
  final notifier = LocalWorkoutTimerNotifier(notifications);

  final timer = store.read();
  if (timer == null) {
    // Finished or discarded elsewhere: the notification is stale.
    await notifier.cancel();
    return;
  }
  final now = clock();
  final updated = switch (actionId) {
    LocalWorkoutTimerNotifier.pauseAction => timer.pause(now),
    LocalWorkoutTimerNotifier.resumeAction when !timer.isAtLimit(now) =>
      timer.resume(now),
    _ => timer,
  };
  await store.write(updated);
  await notifier.show(updated, now);
  // On Android the buttons always run in a background engine, even with the
  // app open: tell an open timer screen to re-read the store.
  if (background) WorkoutTimerStore.notifyOtherIsolates();
}
