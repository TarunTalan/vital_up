import 'package:vital_up/core/utils/date_range_utils.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import 'package:vital_up/features/activity_goals/data/datasources/activity_goals_local_datasource.dart';
import 'package:vital_up/features/activity_goals/domain/entities/activity_goal.dart';
import 'package:vital_up/features/activity_goals/domain/repositories/activity_goals_repository.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/get_activity_history.dart';
import 'package:vital_up/features/dashboard/domain/entities/trend_series.dart';
import 'package:vital_up/features/vita/data/services/health_vitals_service.dart';

class ActivityGoalsRepositoryImpl implements ActivityGoalsRepository {
  final ActivityGoalsLocalDataSource _local;
  final GetActivityHistory _history;
  final HealthVitalsService _health;

  /// Finished days never change, so their step totals are read once.
  final Map<DateTime, int> _pastSteps = {};

  ActivityGoalsRepositoryImpl({
    required this._local,
    required this._history,
    required this._health,
  });

  @override
  List<ActivityGoal> getGoals() => [..._local.read()]
    ..sort((a, b) {
      final byPeriod = a.period.index.compareTo(b.period.index);
      return byPeriod != 0 ? byPeriod : a.metric.index.compareTo(b.metric.index);
    });

  @override
  Future<void> saveGoal(ActivityGoal goal) => _local.write([
        for (final g in _local.read())
          if (g.id != goal.id) g,
        goal,
      ]);

  @override
  Future<void> deleteGoal(ActivityGoal goal) =>
      _local.write([for (final g in _local.read()) if (g.id != goal.id) g]);

  @override
  Future<ActivityGoalsSnapshot> getProgress(TrendRange range) async {
    final today = startOfDay(DateTime.now());
    final weekStart = startOfWeek(today);
    // Charts show the range; weekly goals also need every day since Monday.
    final sinceMonday = today.difference(weekStart).inDays + 1;
    final days = lastNDays(range.days > sinceMonday ? range.days : sinceMonday);
    final from = days.first;

    // Each source is optional: a slow or failing one leaves its part empty
    // rather than holding up the whole card.
    final (history, healthSteps) = await (
      _history().orFallback(const <HistoryEntry>[]),
      _dailySteps(days).orFallback(null),
    ).wait;
    final sessions = [
      for (final e in history)
        if (!e.session.startTime.isBefore(from)) e.session,
    ];
    final byDay = bucketByDay<ActivitySession>(sessions, (s) => s.startTime);

    double valueOn(GoalMetric metric, DateTime day) {
      if (metric == GoalMetric.steps && healthSteps != null) {
        return (healthSteps[day] ?? 0).toDouble();
      }
      return (byDay[day] ?? const <ActivitySession>[])
          .fold(0.0, (sum, s) => sum + metric.fromSession(s));
    }

    final chartDays = days.sublist(days.length - range.days);
    final progress = [
      for (final goal in getGoals())
        GoalProgress(
          goal: goal,
          current: goal.period == GoalPeriod.daily
              ? valueOn(goal.metric, today)
              : days
                  .where((d) => !d.isBefore(weekStart))
                  .fold(0.0, (sum, d) => sum + valueOn(goal.metric, d)),
          series: TrendSeries(
            [for (final d in chartDays) DailyPoint(d, valueOn(goal.metric, d))],
            goal: goal.period == GoalPeriod.daily ? goal.target : null,
          ),
        ),
    ];

    return ActivityGoalsSnapshot(
      goals: progress,
      sessions: [
        for (final s in sessions)
          if (!s.startTime.isBefore(chartDays.first)) s,
      ],
      stepsFromHealth: healthSteps != null,
    );
  }

  Future<Map<DateTime, int>?> _dailySteps(List<DateTime> days) async {
    final today = days.last;
    final missing = [
      for (final d in days)
        if (d == today || !_pastSteps.containsKey(d)) d,
    ];
    final read = await _health.readDailySteps(missing);
    if (read == null) return null;
    for (final e in read.entries) {
      if (e.key != today) _pastSteps[e.key] = e.value;
    }
    return {for (final d in days) d: read[d] ?? _pastSteps[d] ?? 0};
  }
}
