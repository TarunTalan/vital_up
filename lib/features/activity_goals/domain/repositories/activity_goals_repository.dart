import 'package:vital_up/features/activity_goals/domain/entities/activity_goal.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/dashboard/domain/entities/trend_series.dart';

/// Result of [ActivityGoalsRepository.getProgress].
class ActivityGoalsSnapshot {
  final List<GoalProgress> goals;

  /// Tracked sessions in the chart window, newest first.
  final List<ActivitySession> sessions;

  /// Steps come from Health Connect / HealthKit (false: tracked workouts only).
  final bool stepsFromHealth;

  const ActivityGoalsSnapshot({
    required this.goals,
    required this.sessions,
    required this.stepsFromHealth,
  });
}

abstract class ActivityGoalsRepository {
  List<ActivityGoal> getGoals();

  /// Adds or replaces the goal with the same metric + period.
  Future<void> saveGoal(ActivityGoal goal);

  Future<void> deleteGoal(ActivityGoal goal);

  /// Progress for every goal; charts cover [range].
  Future<ActivityGoalsSnapshot> getProgress(TrendRange range);
}
