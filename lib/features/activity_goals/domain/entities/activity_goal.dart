import 'package:equatable/equatable.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/dashboard/domain/entities/trend_series.dart';

/// What an activity goal measures.
enum GoalMetric {
  steps('Steps', 'steps', daily: 8000, weekly: 50000, step: 500, maxDaily: 100000),
  distance('Distance', 'km', daily: 3, weekly: 15, step: 0.5, maxDaily: 100),
  calories('Calories burned', 'kcal', daily: 300, weekly: 2000, step: 50, maxDaily: 5000),
  activeMinutes('Active minutes', 'min', daily: 30, weekly: 150, step: 5, maxDaily: 720),
  workouts('Workouts', 'workouts', daily: 1, weekly: 4, step: 1, maxDaily: 5);

  final String label;
  final String unit;

  /// Suggested starting targets and the editor's +/- increment.
  final double daily;
  final double weekly;
  final double step;

  /// Highest daily target accepted; weekly allows seven times this.
  final double maxDaily;

  const GoalMetric(
    this.label,
    this.unit, {
    required this.daily,
    required this.weekly,
    required this.step,
    required this.maxDaily,
  });

  double suggested(GoalPeriod period) =>
      period == GoalPeriod.daily ? daily : weekly;

  /// Smallest and largest target the editor allows for [period].
  double minTarget(GoalPeriod period) => step;
  double maxTarget(GoalPeriod period) =>
      period == GoalPeriod.daily ? maxDaily : maxDaily * 7;

  /// [value] kept within the allowed range (NaN / infinity become the
  /// suggested target).
  double clampTarget(GoalPeriod period, double value) {
    if (!value.isFinite) return suggested(period);
    return value.clamp(minTarget(period), maxTarget(period)).toDouble();
  }

  /// Today's contribution of one tracked session to this metric.
  double fromSession(ActivitySession s) => switch (this) {
        GoalMetric.steps => s.stepCountReliable ? s.steps.toDouble() : 0,
        GoalMetric.distance => s.totalDistanceMeters / 1000,
        GoalMetric.calories => s.calories.toDouble(),
        GoalMetric.activeMinutes => s.totalDurationSeconds / 60,
        GoalMetric.workouts => 1,
      };
}

/// Daily goals reset at midnight; weekly goals run Monday → Sunday.
enum GoalPeriod {
  daily('Daily', 'Today'),
  weekly('Weekly', 'This week');

  final String label;
  final String windowLabel;
  const GoalPeriod(this.label, this.windowLabel);
}

class ActivityGoal extends Equatable {
  final GoalMetric metric;
  final GoalPeriod period;
  final double target;

  const ActivityGoal({
    required this.metric,
    required this.period,
    required this.target,
  });

  /// At most one goal per metric + period.
  String get id => '${metric.name}_${period.name}';

  ActivityGoal copyWith({double? target}) =>
      ActivityGoal(metric: metric, period: period, target: target ?? this.target);

  Map<String, dynamic> toJson() => {
        'm': metric.name,
        'p': period.name,
        't': target,
      };

  static ActivityGoal? fromJson(Map<String, dynamic> json) {
    final metric = GoalMetric.values.where((m) => m.name == json['m']).firstOrNull;
    final period = GoalPeriod.values.where((p) => p.name == json['p']).firstOrNull;
    final target = (json['t'] as num?)?.toDouble();
    if (metric == null ||
        period == null ||
        target == null ||
        !target.isFinite ||
        target <= 0) {
      return null;
    }
    return ActivityGoal(
      metric: metric,
      period: period,
      target: metric.clampTarget(period, target),
    );
  }

  @override
  List<Object?> get props => [metric, period, target];
}

/// A goal with its progress in the current window and the metric's daily
/// series for the chart.
class GoalProgress extends Equatable {
  final ActivityGoal goal;
  final double current;
  final TrendSeries series;

  const GoalProgress({
    required this.goal,
    required this.current,
    required this.series,
  });

  double get fraction =>
      goal.target > 0 ? (current / goal.target).clamp(0.0, 1.0) : 0;

  bool get achieved => current >= goal.target;

  @override
  List<Object?> get props => [goal, current, series];
}
