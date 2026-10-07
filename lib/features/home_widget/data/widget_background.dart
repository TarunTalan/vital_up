import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vital_up/core/database/collections/meal_log_cache.dart';
import 'package:vital_up/core/database/collections/weight_log_cache.dart';
import 'package:vital_up/core/database/isar_service.dart';
import 'package:vital_up/features/home_widget/data/widget_data.dart';
import 'package:vital_up/features/reminders/data/reminder_actions.dart';

/// Runs when a widget button is tapped (or a widget asks for a refresh),
/// in a background isolate without the app's services. It applies the
/// action, re-reads what is stored on the device (water, meals, mood,
/// weight) and redraws every widget. Server data is refreshed by the app.
///
/// URIs: vitalup://widget/refresh, /add-water?ml=250, /mood?level=1..5,
/// /mood-reset.
@pragma('vm:entry-point')
Future<void> homeWidgetCallback(Uri? uri) async {
  if (uri == null || uri.host != 'widget') return;
  DartPluginRegistrant.ensureInitialized();
  try {
    final userId = await HomeWidget.getWidgetData<String>('user_id');
    final signedIn = await HomeWidget.getWidgetData<bool>('signed_in') ?? false;
    if (userId == null || userId.isEmpty || !signedIn) {
      await endWidgetRefresh();
      return;
    }
    const timeout = Duration(seconds: 8);
    switch (uri.path) {
      case '/add-water':
        final ml = int.tryParse(uri.queryParameters['ml'] ?? '') ?? 250;
        await addWaterInBackground(userId, ml.clamp(1, 2000)).timeout(timeout);
      case '/mood':
        final level = int.tryParse(uri.queryParameters['level'] ?? '');
        if (level != null && level >= 1 && level <= 5) {
          await saveMoodInBackground(userId, level, const []).timeout(timeout);
        }
      case '/mood-reset':
        await resetMoodInBackground(userId).timeout(timeout);
    }
    await refreshFromDevice(userId).timeout(timeout);
  } catch (e) {
    debugPrint('Home widget background action failed: $e');
    // Always redraw so the spinner clears.
    await endWidgetRefresh();
  }
}

/// Rebuilds the widgets from on-device data, keeping the figures only the
/// app can fetch (activity, sleep, goals) from its last refresh.
Future<void> refreshFromDevice(String userId) async {
  final now = DateTime.now();
  final today = WidgetInputs.dayOf(now);
  final saved = await WidgetInputs.load();
  final base = (saved ?? WidgetInputs(signedIn: true, day: today)).forDay(
    today,
  );

  final isar = await _isar();
  final start = DateTime(now.year, now.month, now.day);
  final meals = await isar.mealLogCaches
      .where()
      .capturedAtBetween(start, start.add(const Duration(days: 1)))
      .findAll();
  final calories = meals.fold<double>(0, (sum, m) => sum + m.totalCalories);
  final weight = await isar.weightLogCaches
      .filter()
      .userIdEqualTo(userId)
      .sortByTimestampDesc()
      .findFirst();
  final water = await getTodayWaterInBackground(userId);
  final mood = await getTodayMoodInBackground(userId);

  await publishWidgets(
    base.copyWith(
      signedIn: true,
      waterMl: water,
      caloriesEaten: calories.round(),
      moodLevel: mood?.level,
      moodAt: mood?.date,
      clearMood: mood == null,
      weightKg: weight?.weightKg,
      weightAt: weight?.timestamp,
    ),
    now: now,
  );
}

Future<Isar> _isar() async =>
    Isar.getInstance() ??
    await Isar.open(
      IsarService.schemas,
      directory: (await getApplicationDocumentsDirectory()).path,
    );
