import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/database/collections/sleep_log_cache.dart';
import 'package:vital_up/core/database/collections/water_log_cache.dart';
import 'package:vital_up/core/database/isar_service.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/features/dashboard/data/services/sleep_bedtime.dart';
import 'package:vital_up/features/reminders/data/reminder_scheduler.dart';
import 'package:vital_up/features/vita/domain/entities/vita_insights.dart';

/// The signed-in user a reminder was scheduled for, from its payload.
String? reminderUserId(NotificationResponse response) {
  try {
    final data = jsonDecode(response.payload ?? '');
    final user = data is Map ? data['user'] : null;
    return user is String && user.isNotEmpty ? user : null;
  } catch (_) {
    return null;
  }
}

/// A notification action tapped while the app was closed: "+250 ml" on a
/// water reminder, "Going to bed" / "I'm up" for sleep.
@pragma('vm:entry-point')
Future<void> reminderActionBackground(NotificationResponse response) async {
  // No signed-in user in the payload (signed out, old notification): do
  // nothing rather than log data for nobody.
  final userId = reminderUserId(response);
  if (userId == null) return;
  // Nothing can show an error here; log instead of crashing the isolate.
  try {
    switch (response.actionId) {
      case ReminderScheduler.logWaterAction:
        await addWaterInBackground(userId, ReminderScheduler.logWaterMl);
      case ReminderScheduler.bedtimeAction:
        await markBedtimeInBackground(userId);
      case ReminderScheduler.wakeAction:
        await saveWakeInBackground(userId);
    }
  } catch (e) {
    debugPrint('Reminder action ${response.actionId} failed: $e');
  }
}

/// Stores "in bed now" and shows the in-bed notification with "I'm up".
Future<void> markBedtimeInBackground(String userId) async {
  DartPluginRegistrant.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final now = DateTime.now();
  await writeBedtime(prefs, userId, now);
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ),
  );
  await ReminderScheduler.showInBed(plugin, since: now, userId: userId);
}

/// Saves the night from the stored bedtime until now ("I'm up"). The entry
/// is backed up the next time the app syncs. False when no bedtime is open.
Future<bool> saveWakeInBackground(String userId) async {
  DartPluginRegistrant.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final now = DateTime.now();
  final bed = readBedtime(prefs, userId, now);
  await clearBedtime(prefs, userId);
  if (bed == null || now.difference(bed) < minTimeInBed) return false;
  final isar =
      Isar.getInstance() ??
      await Isar.open(
        IsarService.schemas,
        directory: (await getApplicationDocumentsDirectory()).path,
      );
  await isar.writeTxn(
    () => isar.sleepLogCaches.put(
      SleepLogCache()
        ..userId = userId
        ..startTime = bed
        ..endTime = now
        ..durationMinutes = now.difference(bed).inMinutes
        ..source = 'manual'
        ..isSynced = false,
    ),
  );
  return true;
}

/// Logs water from a background isolate (notification action, home screen
/// widget) by writing straight to Isar; the entry is backed up the next
/// time the app syncs. Returns today's total in ml.
Future<int> addWaterInBackground(String userId, int ml) async {
  DartPluginRegistrant.ensureInitialized();
  if (ml < InputLimits.waterMlMin || ml > InputLimits.waterMlMax) {
    debugPrint('Ignored water amount out of range: $ml');
    return getTodayWaterInBackground(userId);
  }
  final isar =
      Isar.getInstance() ??
      await Isar.open(
        IsarService.schemas,
        directory: (await getApplicationDocumentsDirectory()).path,
      );
  final now = DateTime.now();
  await isar.writeTxn(
    () => isar.waterLogCaches.put(
      WaterLogCache()
        ..userId = userId
        ..amountMl = ml
        ..timestamp = now
        ..isSynced = false,
    ),
  );
  final today = await isar.waterLogCaches
      .filter()
      .userIdEqualTo(userId)
      .timestampGreaterThan(DateTime(now.year, now.month, now.day))
      .findAll();
  return today.fold<int>(0, (sum, l) => sum + l.amountMl);
}

/// Reads today's water total from Isar in a background isolate.
Future<int> getTodayWaterInBackground(String userId) async {
  DartPluginRegistrant.ensureInitialized();
  final isar =
      Isar.getInstance() ??
      await Isar.open(
        IsarService.schemas,
        directory: (await getApplicationDocumentsDirectory()).path,
      );
  final now = DateTime.now();
  final today = await isar.waterLogCaches
      .filter()
      .userIdEqualTo(userId)
      .timestampGreaterThan(DateTime(now.year, now.month, now.day))
      .findAll();
  return today.fold<int>(0, (sum, l) => sum + l.amountMl);
}

/// Saves a stress/mood check-in from a background isolate into SharedPreferences (database).
/// Returns the updated streak count.
Future<int> saveMoodInBackground(
  String userId,
  int level,
  List<StressTag> tags,
) async {
  DartPluginRegistrant.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final key = checkInsKey(userId);
  final checkIns = readStoredCheckIns(prefs, userId);

  final now = DateTime.now();
  final checkIn =
      StressCheckIn(date: now, level: level.clamp(1, 5), tags: tags);
  final cutoff = now.subtract(const Duration(days: 90));
  final updated = checkIns
      .where((c) =>
          c.date.isAfter(cutoff) &&
          !(c.date.year == now.year &&
              c.date.month == now.month &&
              c.date.day == now.day))
      .toList()
    ..add(checkIn);

  await prefs.setString(
    key,
    jsonEncode(updated.map((c) => c.toJson()).toList()),
  );
  return stressStreak(updated, now: now);
}

/// Removes today's stress check-in in background (e.g. on widget Edit button).
/// Returns the updated streak count.
Future<int> resetMoodInBackground(String userId) async {
  DartPluginRegistrant.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final key = checkInsKey(userId);
  final checkIns = readStoredCheckIns(prefs, userId);

  final now = DateTime.now();
  final updated = checkIns
      .where((c) =>
          !(c.date.year == now.year &&
              c.date.month == now.month &&
              c.date.day == now.day))
      .toList();

  await prefs.setString(
    key,
    jsonEncode(updated.map((c) => c.toJson()).toList()),
  );
  return stressStreak(updated, now: now);
}

/// Reads today's check-in from database in background.
Future<StressCheckIn?> getTodayMoodInBackground(String userId) async {
  DartPluginRegistrant.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final now = DateTime.now();
  return readStoredCheckIns(prefs, userId)
      .where((c) =>
          c.date.year == now.year &&
          c.date.month == now.month &&
          c.date.day == now.day)
      .lastOrNull;
}

/// SharedPreferences key of a user's stress check-ins (same as
/// `VitaLocalDataSource`).
String checkInsKey(String userId) => 'vita_checkins_$userId';

/// Stored check-ins; a malformed entry is skipped instead of discarding the
/// whole history (which the next save would then overwrite).
List<StressCheckIn> readStoredCheckIns(SharedPreferences prefs, String userId) {
  final raw = prefs.getString(checkInsKey(userId));
  if (raw == null) return [];
  final Object? list;
  try {
    list = jsonDecode(raw);
  } catch (e) {
    debugPrint('Stored check-ins unreadable: $e');
    return [];
  }
  if (list is! List) return [];
  return [
    for (final item in list.whereType<Map<String, dynamic>>()) ?_tryCheckIn(item),
  ];
}

StressCheckIn? _tryCheckIn(Map<String, dynamic> json) {
  try {
    return StressCheckIn.fromJson(json);
  } catch (e) {
    debugPrint('Skipped a bad check-in: $e');
    return null;
  }
}
