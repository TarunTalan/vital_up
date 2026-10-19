import 'package:vital_up/core/preferences/distance_unit_notifier.dart';
import 'package:vital_up/core/preferences/workout_prefs_notifier.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/features/activity_goals/domain/entities/activity_goal.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';

/// Ranges accepted for a workout target. Distance is stored in km.
abstract final class ActivityTargetLimits {
  static const double distanceKmMin = 0.1;
  static const double distanceKmMax = 300;
  static const double caloriesMin = 10;
  static const double caloriesMax = 5000;

  /// Workout timer targets, in minutes (it stops at 6 hours).
  static const double minutesMin = 1;
  static const double minutesMax = 360;
  static const double kmPerMile = 1.60934;
}

/// Parsed target value, or the inline error to show for what was typed.
typedef ActivityTargetResult = ({double? value, String? error});

/// Validates a typed workout target. Distance is typed in [unit] and
/// returned in km; calories are returned as typed (kcal).
ActivityTargetResult parseActivityTarget(
  WorkoutTargetType type,
  String input,
  DistanceUnit unit,
) {
  if (input.trim().isEmpty) return (value: null, error: 'Enter a target');

  if (type == WorkoutTargetType.duration) {
    final minutes = parseNumberInRange(
      input,
      min: ActivityTargetLimits.minutesMin,
      max: ActivityTargetLimits.minutesMax,
    );
    if (minutes == null) {
      return (
        value: null,
        error:
            'Enter ${_fmt(ActivityTargetLimits.minutesMin)} to '
            '${_fmt(ActivityTargetLimits.minutesMax)} minutes',
      );
    }
    return (value: minutes.roundToDouble(), error: null);
  }

  if (type == WorkoutTargetType.distance) {
    final miles = unit == DistanceUnit.miles;
    final factor = miles ? ActivityTargetLimits.kmPerMile : 1.0;
    final min = ActivityTargetLimits.distanceKmMin / factor;
    final max = ActivityTargetLimits.distanceKmMax / factor;
    final typed = parseNumberInRange(input, min: min, max: max);
    if (typed == null) {
      return (
        value: null,
        error: 'Enter ${_fmt(min)} to ${_fmt(max)} ${unit.label}',
      );
    }
    return (value: typed * factor, error: null);
  }

  final kcal = parseNumberInRange(
    input,
    min: ActivityTargetLimits.caloriesMin,
    max: ActivityTargetLimits.caloriesMax,
  );
  if (kcal == null) {
    return (
      value: null,
      error:
          'Enter ${_fmt(ActivityTargetLimits.caloriesMin)} to '
          '${_fmt(ActivityTargetLimits.caloriesMax)} kcal',
    );
  }
  return (value: kcal.roundToDouble(), error: null);
}

String _fmt(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// Whether a workout reached its target. [targetValue] is km for distance,
/// kcal for calories and minutes for duration ([elapsed]); no target is
/// never met.
bool isActivityTargetMet(
  WorkoutTargetType type,
  double targetValue, {
  required double distanceMeters,
  required int calories,
  Duration elapsed = Duration.zero,
}) {
  if (targetValue <= 0) return false;
  return switch (type) {
    WorkoutTargetType.distance => distanceMeters >= targetValue * 1000,
    WorkoutTargetType.calories => calories >= targetValue,
    WorkoutTargetType.duration => elapsed.inSeconds >= targetValue * 60,
    WorkoutTargetType.none => false,
  };
}

/// The workout timer's target when none was set by hand: what's left of
/// today's active-minutes goal (whole minutes), else of today's calories
/// goal. Null once both are met, or with neither set.
({WorkoutTargetType type, double value})? timerTargetFromGoals(
  Iterable<GoalProgress> progress,
) {
  GoalProgress? today(GoalMetric metric) => progress
      .where(
        (p) => p.goal.period == GoalPeriod.daily && p.goal.metric == metric,
      )
      .firstOrNull;

  final minutes = today(GoalMetric.activeMinutes);
  if (minutes != null && !minutes.achieved) {
    final left = (minutes.goal.target - minutes.current).clamp(
      ActivityTargetLimits.minutesMin,
      ActivityTargetLimits.minutesMax,
    );
    return (type: WorkoutTargetType.duration, value: left.ceilToDouble());
  }
  final calories = today(GoalMetric.calories);
  if (calories != null && !calories.achieved) {
    final left = (calories.goal.target - calories.current).clamp(
      ActivityTargetLimits.caloriesMin,
      ActivityTargetLimits.caloriesMax,
    );
    return (type: WorkoutTargetType.calories, value: left.ceilToDouble());
  }
  return null;
}

/// The GPS activity the tracking screen opens with: a steps goal means
/// walking, a distance or calories goal running. Daily goals come before
/// weekly ones. Without such a goal, the last GPS activity, then a walk.
ActivityType activityForGoals(
  Iterable<ActivityGoal> goals, {
  ActivityType? lastOutdoor,
}) {
  for (final period in GoalPeriod.values) {
    for (final metric in GoalMetric.values) {
      if (!goals.any((g) => g.period == period && g.metric == metric)) {
        continue;
      }
      switch (metric) {
        case GoalMetric.steps:
          return ActivityType.walk;
        case GoalMetric.distance || GoalMetric.calories:
          return ActivityType.run;
        case GoalMetric.activeMinutes || GoalMetric.workouts:
          break;
      }
    }
  }
  return lastOutdoor ?? ActivityType.walk;
}

/// The target a workout starts with when none was set by hand: what's left
/// of today's distance goal (km, rounded up to 0.1), else of today's
/// calories goal (kcal). Null once both are met, or with neither set.
({WorkoutTargetType type, double value})? targetFromGoals(
  Iterable<GoalProgress> progress,
) {
  GoalProgress? today(GoalMetric metric) => progress
      .where(
        (p) => p.goal.period == GoalPeriod.daily && p.goal.metric == metric,
      )
      .firstOrNull;

  final distance = today(GoalMetric.distance);
  if (distance != null && !distance.achieved) {
    final left = (distance.goal.target - distance.current).clamp(
      ActivityTargetLimits.distanceKmMin,
      ActivityTargetLimits.distanceKmMax,
    );
    return (
      type: WorkoutTargetType.distance,
      value: (left * 10).ceilToDouble() / 10,
    );
  }
  final calories = today(GoalMetric.calories);
  if (calories != null && !calories.achieved) {
    final left = (calories.goal.target - calories.current).clamp(
      ActivityTargetLimits.caloriesMin,
      ActivityTargetLimits.caloriesMax,
    );
    return (type: WorkoutTargetType.calories, value: left.ceilToDouble());
  }
  return null;
}
