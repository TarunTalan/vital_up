import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/config/supabase_config.dart';
import 'package:vital_up/core/database/collections/meal_log_cache.dart';
import 'package:vital_up/core/database/collections/weight_log_cache.dart';
import 'package:vital_up/core/database/isar_service.dart';
import 'package:vital_up/core/di/injection_container.dart' as di;
import 'package:vital_up/features/home_widget/data/widget_data.dart';
import 'package:vital_up/features/home_widget/home_widget_service.dart';
import 'package:vital_up/features/reminders/data/reminder_actions.dart';

/// Runs when a widget button is tapped (or a widget asks for a refresh), in
/// a background isolate.
///
/// - Refresh (the header button, and stale widgets) starts the app's
///   services and runs the same full refresh as the app
///   ([HomeWidgetService.refresh]: Health Connect, the server, goals).
/// - Add water and mood apply the action, then re-read on-device data
///   (water, meals, mood, weight), which is instant.
///
/// Either way, if the full refresh can't run, the on-device refresh does.
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
    if (uri.path == '/refresh' &&
        await _refreshWithAppServices().timeout(
          const Duration(seconds: 25),
          onTimeout: () => false,
        )) {
      return;
    }
    await refreshFromDevice(userId).timeout(timeout);
  } catch (e) {
    debugPrint('Home widget background action failed: $e');
    // Always redraw so the spinner clears.
    try {
      await endWidgetRefresh();
    } catch (e) {
      debugPrint('Home widget redraw failed: $e');
    }
  }
}

/// The app's services in this isolate (one background engine can run many
/// widget actions, so they are set up once).
bool _appServicesReady = false;
bool _supabaseReady = false;

/// Full refresh, as the app does it. False if it couldn't run (e.g. the
/// session didn't restore), so the caller falls back to on-device data and
/// the widgets never flip to "signed out" by mistake.
Future<bool> _refreshWithAppServices() async {
  try {
    // Separate flags: if DI fails after Supabase started, the next tap must
    // not initialise Supabase a second time.
    if (!_supabaseReady) {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
      );
      _supabaseReady = true;
    }
    if (!_appServicesReady) {
      await di.initDependencies();
      _appServicesReady = true;
    }
    if (Supabase.instance.client.auth.currentUser == null) return false;
    await di.sl<HomeWidgetService>().refresh();
    return true;
  } catch (e) {
    debugPrint('Full widget refresh unavailable, using device data: $e');
    return false;
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
