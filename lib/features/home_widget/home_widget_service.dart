import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/events/habit_events.dart';
import 'package:vital_up/features/dashboard/data/services/water_intake_service.dart';
import 'package:vital_up/features/gamification/domain/repositories/gamification_repository.dart';
import 'package:vital_up/features/reminders/data/reminder_actions.dart';

/// Android provider class (android/app/src/main/kotlin/.../VitalUpWidgetProvider.kt).
const _provider = 'com.tarun_siddhi.vital_up.VitalUpWidgetProvider';

/// Widget "+250 ml" button: runs in a background isolate.
@pragma('vm:entry-point')
Future<void> homeWidgetCallback(Uri? uri) async {
  if (uri?.host != 'widget' || uri?.path != '/add-water') return;
  final userId = await HomeWidget.getWidgetData<String>('user_id');
  if (userId == null || userId.isEmpty) return;
  final total = await addWaterInBackground(userId, HomeWidgetService.addMl);
  await HomeWidget.saveWidgetData<int>('water_ml', total);
  await HomeWidget.updateWidget(qualifiedAndroidName: _provider);
}

/// Keeps the Android home screen widget (today's water, streak, points) up
/// to date. iOS has no widget yet (needs a WidgetKit extension in Xcode).
class HomeWidgetService {
  final SupabaseClient _client;
  final WaterIntakeService _water;
  final GamificationRepository _game;

  HomeWidgetService(this._client, this._water, this._game);

  static const addMl = 250;

  AppLifecycleListener? _lifecycle;
  StreamSubscription<HabitLogged>? _habits;
  StreamSubscription<AuthState>? _auth;

  bool get _supported => Platform.isAndroid;

  /// Refreshes now, after water is logged, on sign-in / out and whenever
  /// the app goes to the background.
  void start(Stream<HabitLogged> habits) {
    if (!_supported || _lifecycle != null) return;
    HomeWidget.registerInteractivityCallback(homeWidgetCallback);
    _lifecycle = AppLifecycleListener(onHide: refresh);
    _habits = habits
        .where((e) => e.habit == Habit.water)
        .listen((_) => refresh());
    _auth = _client.auth.onAuthStateChange.listen((_) => refresh());
    refresh();
  }

  void dispose() {
    _lifecycle?.dispose();
    _habits?.cancel();
    _auth?.cancel();
  }

  Future<void> refresh() async {
    if (!_supported) return;
    try {
      final userId = _client.auth.currentUser?.id;
      await HomeWidget.saveWidgetData<bool>('signed_in', userId != null);
      await HomeWidget.saveWidgetData<String>('user_id', userId ?? '');
      if (userId != null) {
        final today = await _water.getTodayLogs(userId);
        await HomeWidget.saveWidgetData<int>(
          'water_ml',
          today.fold<int>(0, (sum, l) => sum + l.amountMl),
        );
        await HomeWidget.saveWidgetData<int>(
          'water_goal_ml',
          _water.getDailyGoal(),
        );
        // Cache-first: served from the copy the app last loaded unless it
        // is stale; keeps the last values when offline with nothing cached.
        try {
          final (stats, points) = await (
            _game.getStats(),
            _game.getPointsForDay(DateTime.now()),
          ).wait;
          await HomeWidget.saveWidgetData<int>('streak', stats.streak);
          await HomeWidget.saveWidgetData<int>(
            'points_today',
            points.values.fold<int>(0, (sum, p) => sum + p),
          );
        } catch (_) {}
      }
      await HomeWidget.updateWidget(qualifiedAndroidName: _provider);
    } catch (e) {
      debugPrint('Home widget update failed: $e');
    }
  }

  /// The in-app route a widget tap asks for (`vitalup://widget/open?route=`).
  static String? routeOf(Uri? uri) =>
      uri?.host == 'widget' && uri?.path == '/open'
      ? uri?.queryParameters['route']
      : null;
}
