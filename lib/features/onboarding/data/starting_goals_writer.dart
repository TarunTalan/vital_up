import 'package:flutter/foundation.dart';
import 'package:vital_up/features/activity_goals/domain/entities/activity_goal.dart';
import 'package:vital_up/features/activity_goals/domain/repositories/activity_goals_repository.dart';
import 'package:vital_up/features/dashboard/data/services/screen_time_service.dart';
import 'package:vital_up/features/dashboard/data/services/sleep_service.dart';
import 'package:vital_up/features/dashboard/data/services/water_intake_service.dart';
import 'package:vital_up/features/onboarding/domain/usecases/starting_goals.dart';

/// Saves [StartingGoals] as the user's own goals when onboarding ends.
/// A goal already saved (set by hand, or restored from a backup) is never
/// replaced; users who finished onboarding before this keep theirs.
class StartingGoalsWriter {
  final WaterIntakeService _water;
  final SleepService _sleep;
  final ScreenTimeService _screenTime;
  final ActivityGoalsRepository _activity;

  StartingGoalsWriter({
    required this._water,
    required this._sleep,
    required this._screenTime,
    required this._activity,
  });

  /// Never throws: a goal that couldn't be saved keeps its default.
  Future<void> save(StartingGoals goals) async {
    Future<void> step(String what, Future<void> Function() write) async {
      try {
        await write();
      } catch (e) {
        debugPrint('Starting $what goal not saved: $e');
      }
    }

    if (!_water.hasSavedGoal) {
      await step('water', () => _water.setDailyGoal(goals.waterMl));
    }
    if (!_sleep.hasSavedGoal) {
      await step('sleep', () => _sleep.setGoalMinutes(goals.sleepMinutes));
    }
    if (!_screenTime.hasSavedLimit) {
      await step('screen time', _screenTime.clearDailyLimit);
    }
    if (!_activity.hasSavedGoals) {
      await step('activity', () async {
        await _activity.saveGoal(
          ActivityGoal(
            metric: GoalMetric.steps,
            period: GoalPeriod.daily,
            target: goals.dailySteps.toDouble(),
          ),
        );
        await _activity.saveGoal(
          ActivityGoal(
            metric: GoalMetric.workouts,
            period: GoalPeriod.weekly,
            target: goals.weeklyWorkouts.toDouble(),
          ),
        );
      });
    }
  }
}
