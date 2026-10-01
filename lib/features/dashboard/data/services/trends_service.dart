import 'package:vital_up/core/database/collections/water_log_cache.dart';
import 'package:vital_up/core/utils/date_range_utils.dart';
import 'package:vital_up/features/dashboard/data/services/sleep_service.dart';
import 'package:vital_up/features/dashboard/data/services/water_intake_service.dart';
import 'package:vital_up/features/dashboard/domain/entities/sleep_session_info.dart';
import 'package:vital_up/features/dashboard/domain/entities/trend_series.dart';
import 'package:vital_up/features/diet_plan/domain/usecases/get_active_meal_plan.dart';
import 'package:vital_up/features/food_scanner/domain/entities/meal_log_entry.dart';
import 'package:vital_up/features/food_scanner/domain/usecases/get_meal_log_history.dart';
import 'package:vital_up/features/vita/domain/entities/vita_insights.dart';
import 'package:vital_up/features/vita/domain/repositories/vita_repository.dart';

/// Builds per-day trend series for the dashboard cards and trend pages.
class TrendsService {
  final WaterIntakeService _water;
  final SleepService _sleep;
  final VitaRepository _vita;
  final GetMealLogHistory _meals;
  final GetActiveMealPlan _activePlan;

  TrendsService(
    this._water,
    this._sleep,
    this._vita,
    this._meals,
    this._activePlan,
  );

  /// Range covering the last [range] days, up to the end of today.
  static (DateTime, DateTime) window(int days) {
    final daysList = lastNDays(days);
    return (daysList.first, nextDay(daysList.last));
  }

  /// Millilitres per day; days with no logs are 0 (water is always tracked).
  Future<TrendData<WaterLogCache>> water(String userId, TrendRange range) async {
    final (from, to) = window(range.days);
    final logs = await _water.getLogsBetween(userId, from, to);
    final series = TrendSeries.sum<WaterLogCache>(
      days: range.days,
      items: logs,
      dateOf: (l) => l.timestamp,
      valueOf: (l) => l.amountMl.toDouble(),
      goal: _water.getDailyGoal().toDouble(),
      zeroWhenEmpty: true,
    );
    return TrendData(series, logs.reversed.toList());
  }

  /// Hours slept per wake-up day; nights without data are gaps.
  Future<TrendData<SleepSessionInfo>> sleep(TrendRange range) async {
    final (from, to) = window(range.days);
    final sessions = await _sleep.getSleepBetween(from, to);
    final series = TrendSeries.sum<SleepSessionInfo>(
      days: range.days,
      items: sessions,
      dateOf: (s) => s.wakeTime,
      valueOf: (s) => s.duration.inMinutes / 60,
      goal: _sleep.getGoalMinutes() / 60,
    );
    return TrendData(series, sessions);
  }

  /// Calories eaten per day vs the active plan's target; days with no meal
  /// logs are gaps.
  Future<TrendData<MealLogEntry>> calories(TrendRange range) async {
    final (from, to) = window(range.days);
    final all = (await _meals.callAll()).getOrElse(() => const []);
    final logs = [
      for (final m in all)
        if (!m.capturedAt.isBefore(from) && m.capturedAt.isBefore(to)) m,
    ]..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    final plan = await _activePlan();
    final series = TrendSeries.sum<MealLogEntry>(
      days: range.days,
      items: logs,
      dateOf: (m) => m.capturedAt,
      valueOf: (m) => m.totalCalories,
      goal: plan?.totalCalories.toDouble(),
      direction: GoalDirection.near,
    );
    return TrendData(series, logs);
  }

  /// Check-in level (1–5) per day; days without a check-in are gaps.
  Future<TrendData<StressCheckIn>> stress(TrendRange range) async {
    final (from, _) = window(range.days);
    final checkIns =
        _vita.getStressCheckIns().where((c) => !c.date.isBefore(from)).toList();
    final byDay = {for (final c in checkIns) startOfDay(c.date): c};
    final series = TrendSeries(
      [
        for (final day in lastNDays(range.days))
          DailyPoint(day, byDay[day]?.level.toDouble()),
      ],
      direction: GoalDirection.down,
    );
    return TrendData(series, checkIns.reversed.toList());
  }
}
