import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:isar_community/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/database/collections/user_profile_cache.dart';
import 'package:vital_up/core/database/isar_service.dart';
import 'package:vital_up/core/events/habit_events.dart';
import 'package:vital_up/core/router/app_router.dart';
import 'package:vital_up/features/activity_goals/domain/entities/activity_goal.dart';
import 'package:vital_up/features/activity_goals/domain/repositories/activity_goals_repository.dart';
import 'package:vital_up/features/dashboard/data/services/sleep_service.dart';
import 'package:vital_up/features/dashboard/data/services/water_intake_service.dart';
import 'package:vital_up/features/dashboard/domain/entities/trend_series.dart';
import 'package:vital_up/features/diet_plan/domain/usecases/get_active_meal_plan.dart';
import 'package:vital_up/features/food_scanner/domain/usecases/get_meal_log_history.dart';
import 'package:vital_up/features/home_widget/data/widget_background.dart';
import 'package:vital_up/features/home_widget/data/widget_data.dart';
import 'package:vital_up/features/vita/domain/entities/vita_insights.dart';
import 'package:vital_up/features/vita/domain/repositories/vita_repository.dart';
import 'package:vital_up/features/weight/data/weight_service.dart';

export 'package:vital_up/features/home_widget/data/widget_background.dart'
    show homeWidgetCallback;

/// Keeps the Android home screen widgets current and routes their taps.
///
/// The app does the full refresh (repositories, so server data and goals
/// are included) when it starts, after anything is logged, on sign-in or
/// out, and when it is resumed or backgrounded. Widget buttons and stale
/// widgets refresh from on-device data in the background
/// ([homeWidgetCallback]).
class HomeWidgetService {
  final SupabaseClient _client;
  final WaterIntakeService _water;
  final SleepService _sleep;
  final WeightService _weight;
  final ActivityGoalsRepository _activityGoals;
  final GetMealLogHistory _mealLogs;
  final GetActiveMealPlan _activePlan;
  final IsarService _isar;
  final VitaRepository _vita;

  HomeWidgetService(
    this._client,
    this._water,
    this._sleep,
    this._weight,
    this._activityGoals,
    this._mealLogs,
    this._activePlan,
    this._isar,
    this._vita,
  );

  static bool get supported => Platform.isAndroid;

  AppLifecycleListener? _lifecycle;
  StreamSubscription<HabitLogged>? _habits;
  StreamSubscription<AuthState>? _auth;

  /// Refreshes now and whenever the data behind the widgets may change.
  void start(Stream<HabitLogged> habits) {
    if (!supported || _lifecycle != null) return;
    HomeWidget.registerInteractivityCallback(homeWidgetCallback);
    _lifecycle = AppLifecycleListener(onHide: refresh, onResume: refresh);
    _habits = habits.listen((_) => refresh());
    _auth = _client.auth.onAuthStateChange.listen((_) => refresh());
    refresh();
  }

  void dispose() {
    _lifecycle?.dispose();
    _habits?.cancel();
    _auth?.cancel();
  }

  Future<void>? _running;
  bool _again = false;

  /// Collects today's figures and redraws every widget. Calls made while
  /// one is running are folded into a single follow-up refresh.
  Future<void> refresh() async {
    if (!supported) return;
    if (_running != null) {
      _again = true;
      return _running;
    }
    _running = _refresh();
    try {
      await _running;
    } finally {
      _running = null;
    }
    if (_again) {
      _again = false;
      await refresh();
    }
  }

  Future<void> _refresh() async {
    final now = DateTime.now();
    final today = WidgetInputs.dayOf(now);
    final user = _client.auth.currentUser;
    try {
      await HomeWidget.saveWidgetData<String>('user_id', user?.id);
      if (user == null) {
        await publishWidgets(WidgetInputs(signedIn: false, day: today));
        return;
      }
      await startWidgetRefresh();
      // Anything that fails or times out keeps its last saved value.
      final last = (await WidgetInputs.load())?.forDay(today);
      const timeout = Duration(seconds: 6);
      Future<T?> safe<T>(Future<T> f) =>
          f.timeout(timeout).then<T?>((v) => v).catchError((Object e) {
            debugPrint('Home widget value failed: $e');
            return null;
          });

      final (
        activity,
        meals,
        calorieGoal,
        water,
        sleep,
        mood,
        weight,
        unit,
      ) = await (
        safe(_activityGoals.getProgress(TrendRange.week)),
        safe(_mealLogs(now)),
        safe(_calorieGoal()),
        safe(_water.getTodayLogs(user.id)),
        safe(_sleep.getSleepDataForLastNight(requestPermission: false)),
        safe(_todayMood()),
        safe(_weight.latest()),
        safe(_weight.unit()),
      ).wait;

      // Home's Today card: today's step goal, else the first goal.
      final goals = activity?.goals ?? const <GoalProgress>[];
      final headline =
          goals
              .where(
                (g) =>
                    g.goal.metric == GoalMetric.steps &&
                    g.goal.period == GoalPeriod.daily,
              )
              .firstOrNull ??
          goals.firstOrNull;
      final calories = meals
          ?.fold<double?>(
            (_) => null,
            (entries) => entries.fold<double>(0, (s, e) => s + e.totalCalories),
          )
          ?.round();

      await publishWidgets(
        WidgetInputs(
          signedIn: true,
          day: today,
          activityMetric: activity == null
              ? last?.activityMetric
              : headline?.goal.metric.name,
          activityCurrent: activity == null
              ? last?.activityCurrent
              : headline?.current,
          activityTarget: activity == null
              ? last?.activityTarget
              : headline?.goal.target,
          caloriesEaten: calories ?? last?.caloriesEaten,
          caloriesGoal: calorieGoal ?? last?.caloriesGoal,
          waterMl: water == null
              ? last?.waterMl
              : water.fold<int>(0, (s, l) => s + l.amountMl),
          waterGoalMl: _water.getDailyGoal(),
          sleepMinutes: sleep?.duration.inMinutes ?? last?.sleepMinutes,
          sleepGoalMinutes: _sleep.getGoalMinutes(),
          moodLevel: mood?.level,
          moodAt: mood?.date,
          weightKg: weight?.weightKg ?? last?.weightKg,
          weightAt: weight?.timestamp ?? last?.weightAt,
          weightUnit: unit?.label ?? last?.weightUnit ?? 'kg',
        ),
        now: now,
      );
    } catch (e) {
      debugPrint('Home widget refresh failed: $e');
      await endWidgetRefresh();
    }
  }

  /// Same goal Home shows: the active meal plan, else the profile's goal.
  Future<int?> _calorieGoal() async {
    final plan = await _activePlan();
    if (plan != null) return plan.totalCalories.round();
    final profile = await _isar.isar.userProfileCaches.where().findFirst();
    return profile?.dailyCalorieGoal;
  }

  Future<StressCheckIn?> _todayMood() async {
    await _vita.reload();
    final now = DateTime.now();
    return _vita
        .getStressCheckIns()
        .where(
          (c) =>
              c.date.year == now.year &&
              c.date.month == now.month &&
              c.date.day == now.day,
        )
        .firstOrNull;
  }

  // -------------------------------------------------------------------------
  // Deep links: vitalup://widget/open?route=<name>
  //
  // Flutter hands these to GoRouter as /open?route=... (see app_router.dart),
  // the only place widget taps are handled. Before the app has signed in and
  // reached Home (cold start), the route waits; Home then opens it on top of
  // itself so Back returns Home.
  // -------------------------------------------------------------------------

  static String? _pending;
  static DateTime? _pendingAt;
  static bool _ready = false;

  /// Routes a widget may open, plus aliases from older widget versions.
  static const _routes = <String, String>{
    'dashboard': 'dashboard',
    'home': 'dashboard',
    'login': 'login',
    'activity-goals': 'activity-goals',
    'activity-tracking': 'activity-tracking',
    'diet-progress': 'diet-progress',
    'food-scan': 'food-scan',
    'water-trends': 'water-trends',
    'water-log': 'water-trends',
    'water': 'water-trends',
    'sleep-trends': 'sleep-trends',
    'stress-trends': 'stress-trends',
    'weight-trends': 'weight-trends',
    'vita-chat': 'vita-chat',
    'home-widgets': 'home-widgets',
  };

  /// The app route a widget link opens; unknown targets open Home.
  static String routeOf(Uri uri) {
    final target =
        uri.queryParameters['route'] ?? uri.queryParameters['feature'];
    return _routes[target?.toLowerCase().trim()] ?? 'dashboard';
  }

  /// GoRouter redirect for /open and /widget/open.
  static String handleLink(Uri uri) {
    final route = routeOf(uri);
    if (!_ready) {
      _pending = route;
      _pendingAt = DateTime.now();
      return '/splash';
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => open(route));
    return '/dashboard';
  }

  /// Home is showing: open a route that arrived during start-up.
  static void markReady() {
    _ready = true;
    final route = _pending;
    final at = _pendingAt;
    _pending = null;
    _pendingAt = null;
    if (route == null || at == null) return;
    // A tap from minutes ago (e.g. before signing in) is no longer wanted.
    if (DateTime.now().difference(at) > const Duration(minutes: 2)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => open(route));
  }

  /// Leaving Home for sign-in: links wait for the next time it shows.
  static void markNotReady() => _ready = false;

  /// Opens [route] above Home; signed-out users go to sign-in.
  static void open(String route) {
    final router = AppRouter.router;
    final signedIn = Supabase.instance.client.auth.currentUser != null;
    if (!signedIn) {
      router.goNamed('login');
      return;
    }
    router.goNamed('dashboard');
    if (route != 'dashboard' && route != 'login') router.pushNamed(route);
  }
}
