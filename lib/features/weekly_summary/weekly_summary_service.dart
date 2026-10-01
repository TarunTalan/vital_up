import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/database/collections/water_log_cache.dart';
import 'package:vital_up/core/utils/date_range_utils.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/activity_repository.dart';
import 'package:vital_up/features/dashboard/data/services/sleep_service.dart';
import 'package:vital_up/features/dashboard/data/services/water_intake_service.dart';
import 'package:vital_up/features/food_scanner/domain/usecases/get_meal_log_history.dart';
import 'package:vital_up/features/weight/data/weight_service.dart';

/// One week of habits, computed from what's on the device.
class WeekStats extends Equatable {
  final DateTime from;
  final int workouts;
  final int activeMinutes;
  final double distanceKm;

  /// Average night, or null when no sleep was recorded.
  final Duration? avgSleep;
  final int waterGoalDays;
  final int waterMl;
  final int meals;
  final int mealDays;

  /// Last weight minus first weight this week, if weighed twice.
  final double? weightChangeKg;

  const WeekStats({
    required this.from,
    this.workouts = 0,
    this.activeMinutes = 0,
    this.distanceKm = 0,
    this.avgSleep,
    this.waterGoalDays = 0,
    this.waterMl = 0,
    this.meals = 0,
    this.mealDays = 0,
    this.weightChangeKg,
  });

  bool get isEmpty =>
      workouts == 0 && avgSleep == null && waterMl == 0 && meals == 0;

  @override
  List<Object?> get props => [
    from,
    workouts,
    activeMinutes,
    distanceKm,
    avgSleep,
    waterGoalDays,
    waterMl,
    meals,
    mealDays,
    weightChangeKg,
  ];
}

class WeeklySummary {
  final WeekStats thisWeek;
  final WeekStats lastWeek;

  const WeeklySummary(this.thisWeek, this.lastWeek);
}

/// Builds the in-app weekly summary and tells the server the user's time
/// zone, so the Sunday-evening recap (send_weekly_summaries) arrives at
/// 18:00 local time.
class WeeklySummaryService {
  final SupabaseClient _client;
  final ActivityRepository _activity;
  final WaterIntakeService _water;
  final SleepService _sleep;
  final GetMealLogHistory _meals;
  final WeightService _weight;

  WeeklySummaryService(
    this._client,
    this._activity,
    this._water,
    this._sleep,
    this._meals,
    this._weight,
  );

  /// Last 7 days (ending today) and the 7 before them.
  Future<WeeklySummary> load({DateTime? now}) async {
    final days = lastNDays(14, now: now);
    final lastFrom = days.first;
    final thisFrom = days[7];
    final to = nextDay(days.last);

    final sessions = await _activity.getSessions();
    final userId = _client.auth.currentUser?.id;
    final water = userId == null
        ? const <WaterLogCache>[]
        : await _water.getLogsBetween(userId, lastFrom, to);
    final sleep = await _sleep.getSleepBetween(lastFrom, to);
    final meals = (await _meals.callAll()).getOrElse(() => const []);
    final weights = await _weight.between(lastFrom, to);
    final goal = _water.getDailyGoal();

    WeekStats week(DateTime from, DateTime until) {
      bool inWeek(DateTime t) => !t.isBefore(from) && t.isBefore(until);
      final waterByDay = <DateTime, int>{};
      for (final l in water) {
        if (!inWeek(l.timestamp)) continue;
        waterByDay.update(
          startOfDay(l.timestamp),
          (ml) => ml + l.amountMl,
          ifAbsent: () => l.amountMl,
        );
      }
      return weekStats(
        from: from,
        sessions: sessions.where((s) => inWeek(s.startTime)),
        waterByDay: waterByDay,
        waterGoalMl: goal,
        sleep: [
          for (final s in sleep)
            if (inWeek(s.wakeTime)) s.duration,
        ],
        mealTimes: [
          for (final m in meals)
            if (inWeek(m.capturedAt)) m.capturedAt,
        ],
        weights: [
          for (final w in weights.reversed)
            if (inWeek(w.timestamp)) w.weightKg,
        ],
      );
    }

    return WeeklySummary(week(thisFrom, to), week(lastFrom, thisFrom));
  }

  /// Saves the device time zone on the profile (once per app start).
  Future<void> reportTimezone() async {
    if (_client.auth.currentUser == null) return;
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      await _client.rpc('set_my_timezone', params: {'p_tz': zone.identifier});
    } catch (e) {
      debugPrint('Time zone not reported: $e');
    }
  }
}

/// Pure aggregation, separated for tests. [weights] oldest first.
WeekStats weekStats({
  required DateTime from,
  required Iterable<ActivitySession> sessions,
  required Map<DateTime, int> waterByDay,
  required int waterGoalMl,
  required List<Duration> sleep,
  required List<DateTime> mealTimes,
  required List<double> weights,
}) {
  final finished = sessions.where((s) => s.endTime != null).toList();
  return WeekStats(
    from: from,
    workouts: finished.length,
    activeMinutes:
        finished.fold<int>(0, (sum, s) => sum + s.totalDurationSeconds) ~/ 60,
    distanceKm:
        finished.fold<double>(0, (sum, s) => sum + s.totalDistanceMeters) /
        1000,
    avgSleep: sleep.isEmpty
        ? null
        : Duration(
            minutes:
                sleep.fold<int>(0, (sum, d) => sum + d.inMinutes) ~/
                sleep.length,
          ),
    waterGoalDays: waterByDay.values.where((ml) => ml >= waterGoalMl).length,
    waterMl: waterByDay.values.fold(0, (sum, ml) => sum + ml),
    meals: mealTimes.length,
    mealDays: {for (final t in mealTimes) startOfDay(t)}.length,
    weightChangeKg: weights.length < 2 ? null : weights.last - weights.first,
  );
}
