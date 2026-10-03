import 'dart:convert';
import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/database/collections/water_log_cache.dart';
import 'package:vital_up/core/database/isar_service.dart';
import 'package:vital_up/features/reminders/data/reminder_scheduler.dart';
import 'package:vital_up/features/vita/domain/entities/vita_insights.dart';

/// The signed-in user a reminder was scheduled for, from its payload.
String? reminderUserId(NotificationResponse response) {
  try {
    final data = jsonDecode(response.payload ?? '') as Map<String, dynamic>;
    return data['user'] as String?;
  } catch (_) {
    return null;
  }
}

/// "+250 ml" tapped on a water reminder while the app was closed.
@pragma('vm:entry-point')
Future<void> reminderActionBackground(NotificationResponse response) async {
  if (response.actionId != ReminderScheduler.logWaterAction) return;
  final userId = reminderUserId(response);
  if (userId == null) return;
  await addWaterInBackground(userId, ReminderScheduler.logWaterMl);
}

/// Logs water from a background isolate (notification action, home screen
/// widget) by writing straight to Isar; the entry is backed up the next
/// time the app syncs. Returns today's total in ml.
Future<int> addWaterInBackground(String userId, int ml) async {
  DartPluginRegistrant.ensureInitialized();
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
  final key = 'vita_checkins_$userId';
  final raw = prefs.getString(key);
  List<StressCheckIn> checkIns = [];
  if (raw != null) {
    try {
      final list = jsonDecode(raw) as List;
      checkIns = list
          .map((e) => StressCheckIn.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {}
  }

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
  final key = 'vita_checkins_$userId';
  final raw = prefs.getString(key);
  List<StressCheckIn> checkIns = [];
  if (raw != null) {
    try {
      final list = jsonDecode(raw) as List;
      checkIns = list
          .map((e) => StressCheckIn.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {}
  }

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
  final key = 'vita_checkins_$userId';
  final raw = prefs.getString(key);
  if (raw == null) return null;
  try {
    final list = jsonDecode(raw) as List;
    final checkIns = list
        .map((e) => StressCheckIn.fromJson(e as Map<String, dynamic>))
        .toList();
    final now = DateTime.now();
    return checkIns
        .where((c) =>
            c.date.year == now.year &&
            c.date.month == now.month &&
            c.date.day == now.day)
        .firstOrNull;
  } catch (_) {
    return null;
  }
}

