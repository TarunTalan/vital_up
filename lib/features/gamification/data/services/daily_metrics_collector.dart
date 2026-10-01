import 'package:isar_community/isar.dart';
import 'package:vital_up/core/database/collections/user_profile_cache.dart';
import 'package:vital_up/core/database/isar_service.dart';
import 'package:vital_up/core/utils/date_range_utils.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import 'package:vital_up/features/activity_goals/domain/entities/activity_goal.dart';
import 'package:vital_up/features/activity_goals/domain/repositories/activity_goals_repository.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/get_activity_history.dart';
import 'package:vital_up/features/dashboard/data/services/sleep_service.dart';
import 'package:vital_up/features/dashboard/data/services/water_intake_service.dart';
import 'package:vital_up/features/dashboard/domain/entities/diet_progress.dart';
import 'package:vital_up/features/dashboard/domain/entities/trend_series.dart';
import 'package:vital_up/features/diet_plan/domain/entities/meal_plan.dart';
import 'package:vital_up/features/diet_plan/domain/usecases/get_active_meal_plan.dart';
import 'package:vital_up/features/food_scanner/domain/entities/meal_log_entry.dart';
import 'package:vital_up/features/food_scanner/domain/usecases/get_meal_log_history.dart';
import 'package:vital_up/features/gamification/domain/entities/daily_metrics.dart';
import 'package:vital_up/features/vita/data/datasources/vita_local_datasource.dart';
import 'package:vital_up/features/vita/data/services/health_vitals_service.dart';

/// Gathers one day's metrics from the on-device stores the dashboard cards
/// already read. Every source is optional: a slow or failing one reports
/// zero rather than blocking the sync.
class DailyMetricsCollector {
  final ActivityGoalsRepository _goals;
  final GetActivityHistory _history;
  final HealthVitalsService _health;
  final GetMealLogHistory _meals;
  final GetActiveMealPlan _activePlan;
  final WaterIntakeService _water;
  final SleepService _sleep;
  final VitaLocalDataSource _vita;
  final IsarService _isar;

  /// Workouts shorter than this don't count.
  static const minWorkout = Duration(minutes: 10);

  /// Calories within this share of the goal count as on target.
  static const calorieTolerance = 0.10;

  /// Today's calories only count as on target from this hour, so a
  /// half-eaten day doesn't score.
  static const calorieCheckHour = 20;

  DailyMetricsCollector({
    required this._goals,
    required this._history,
    required this._health,
    required this._meals,
    required this._activePlan,
    required this._water,
    required this._sleep,
    required this._vita,
    required this._isar,
  });

  Future<DailyMetrics> collect(
    String userId,
    DateTime day, {
    DateTime? now,
  }) async {
    final clock = now ?? DateTime.now();
    final date = startOfDay(day);
    final end = nextDay(date);
    final isToday = date == startOfDay(clock);

    final (goals, history, healthSteps, meals, plan, water, sleep) = await (
      _goals
          .getProgress(TrendRange.week)
          .then<ActivityGoalsSnapshot?>((s) => s)
          .orFallback(null),
      _history().orFallback(const <HistoryEntry>[]),
      _health.readDailySteps([date]).orFallback(null),
      _meals(date)
          .then((r) => r.getOrElse(() => const <MealLogEntry>[]))
          .orFallback(const <MealLogEntry>[]),
      _activePlan().orFallback(null),
      _water.getLogsBetween(userId, date, end).orFallback(const []),
      _sleep.getSleepBetween(date, end).orFallback(const []),
    ).wait;

    // Fitness
    final sessions = [
      for (final e in history)
        if (!e.session.startTime.isBefore(date) &&
            e.session.startTime.isBefore(end))
          e.session,
    ];
    final sessionSteps = sessions.fold<int>(
      0,
      (sum, s) => sum + (s.stepCountReliable ? s.steps : 0),
    );
    final daily = <GoalMetric>{};
    final weekly = <GoalMetric>{};
    for (final g in goals?.goals ?? const <GoalProgress>[]) {
      if (g.goal.period == GoalPeriod.daily) {
        final point = g.series.points.where((p) => p.day == date).firstOrNull;
        if ((point?.value ?? 0) >= g.goal.target) daily.add(g.goal.metric);
      } else if (isToday && g.achieved) {
        // Weekly progress is only computed for the current week.
        weekly.add(g.goal.metric);
      }
    }

    // Nutrition
    final planned = plan == null
        ? const <PlannedMealStatus>[]
        : plannedMealStatuses(plan, meals);
    final waterMl = water.fold<int>(0, (sum, l) => sum + l.amountMl);

    // Lifestyle
    final checkIn = _vita
        .readCheckIns(userId)
        .where((c) => startOfDay(c.date) == date)
        .firstOrNull;
    final sleptMinutes = sleep.fold<int>(
      0,
      (best, s) => s.duration.inMinutes > best ? s.duration.inMinutes : best,
    );

    return DailyMetrics(
      day: date,
      steps: healthSteps?[date] ?? sessionSteps,
      distanceMeters: sessions
          .fold<double>(0, (sum, s) => sum + s.totalDistanceMeters)
          .round(),
      activeMinutes:
          (sessions.fold<int>(0, (sum, s) => sum + s.totalDurationSeconds) / 60)
              .round(),
      caloriesBurned: sessions.fold<int>(0, (sum, s) => sum + s.calories),
      workouts: sessions
          .where((s) => s.totalDurationSeconds >= minWorkout.inSeconds)
          .length,
      dailyGoalsAchieved: daily,
      weeklyGoalsAchieved: weekly,
      foodLogs: meals.length,
      waterLogs: water.length,
      waterGoalMet: waterMl > 0 && waterMl >= _water.getDailyGoal(),
      plannedMeals: planned.length,
      plannedMealsLogged: planned.where((p) => p.logged).length,
      calorieGoalMet:
          (!isToday || clock.hour >= calorieCheckHour) &&
          await _calorieGoalMet(meals, plan),
      sleepLogged: sleep.isNotEmpty,
      sleepHours: sleptMinutes / 60,
      moodCheckIn: checkIn != null,
      moodLevel: checkIn?.level ?? 0,
    );
  }

  Future<bool> _calorieGoalMet(List<MealLogEntry> meals, MealPlan? plan) async {
    if (meals.isEmpty) return false;
    final goal = plan?.totalCalories ?? await _profileCalorieGoal();
    if (goal == null || goal <= 0) return false;
    final eaten = meals.fold<double>(0, (sum, m) => sum + m.totalCalories);
    return (eaten - goal).abs() <= goal * calorieTolerance;
  }

  Future<int?> _profileCalorieGoal() async {
    try {
      final profiles = await _isar.isar.userProfileCaches.where().findAll();
      return profiles.firstOrNull?.dailyCalorieGoal;
    } catch (_) {
      return null;
    }
  }
}
