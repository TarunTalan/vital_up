import 'dart:convert';
import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vital_up/core/database/collections/water_log_cache.dart';
import 'package:vital_up/core/database/isar_service.dart';
import 'package:vital_up/features/reminders/data/reminder_scheduler.dart';

/// The signed-in user a reminder was scheduled for, from its payload.
String? reminderUserId(NotificationResponse response) {
  try {
    final data = jsonDecode(response.payload ?? '') as Map<String, dynamic>;
    return data['user'] as String?;
  } catch (_) {
    return null;
  }
}

/// "+250 ml" tapped on a water reminder while the app was closed. Runs in a
/// background isolate, so it writes straight to Isar; the entry is backed up
/// the next time the app syncs.
@pragma('vm:entry-point')
Future<void> reminderActionBackground(NotificationResponse response) async {
  if (response.actionId != ReminderScheduler.logWaterAction) return;
  final userId = reminderUserId(response);
  if (userId == null) return;
  DartPluginRegistrant.ensureInitialized();
  final isar =
      Isar.getInstance() ??
      await Isar.open(
        IsarService.schemas,
        directory: (await getApplicationDocumentsDirectory()).path,
      );
  await isar.writeTxn(
    () => isar.waterLogCaches.put(
      WaterLogCache()
        ..userId = userId
        ..amountMl = ReminderScheduler.logWaterMl
        ..timestamp = DateTime.now()
        ..isSynced = false,
    ),
  );
}
