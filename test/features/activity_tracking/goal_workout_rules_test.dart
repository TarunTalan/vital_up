import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/preferences/distance_unit_notifier.dart';
import 'package:vital_up/core/preferences/workout_prefs_notifier.dart';
import 'package:vital_up/features/activity_goals/domain/entities/activity_goal.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_target_rules.dart';
import 'package:vital_up/features/dashboard/domain/entities/trend_series.dart';

ActivityGoal _goal(GoalMetric metric, double target, {bool weekly = false}) =>
    ActivityGoal(
      metric: metric,
      period: weekly ? GoalPeriod.weekly : GoalPeriod.daily,
      target: target,
    );

GoalProgress _progress(ActivityGoal goal, double current) => GoalProgress(
  goal: goal,
  current: current,
  series: const TrendSeries([]),
);

void main() {
  group('activity the tracking screen opens with', () {
    test('a steps goal walks, a distance or calories goal runs', () {
      expect(
        activityForGoals([_goal(GoalMetric.steps, 8000)]),
        ActivityType.walk,
      );
      expect(
        activityForGoals([_goal(GoalMetric.distance, 5)]),
        ActivityType.run,
      );
      expect(
        activityForGoals([_goal(GoalMetric.calories, 300)]),
        ActivityType.run,
      );
    });

    test('daily goals come before weekly ones', () {
      expect(
        activityForGoals([
          _goal(GoalMetric.distance, 20, weekly: true),
          _goal(GoalMetric.steps, 8000),
        ]),
        ActivityType.walk,
      );
    });

    test('without such a goal: the last GPS activity, then a walk', () {
      final minutes = [_goal(GoalMetric.activeMinutes, 30)];
      expect(
        activityForGoals(minutes, lastOutdoor: ActivityType.cycle),
        ActivityType.cycle,
      );
      expect(activityForGoals(const []), ActivityType.walk);
    });
  });

  group('workout target from the daily goal', () {
    test("is what's left of today's distance goal", () {
      final target = targetFromGoals([
        _progress(_goal(GoalMetric.distance, 5), 2.04),
      ]);
      expect(target?.type, WorkoutTargetType.distance);
      expect(target?.value, 3.0); // 2.96 km, rounded up to 0.1
    });

    test('falls back to the calories goal, and stops once met', () {
      final target = targetFromGoals([
        _progress(_goal(GoalMetric.distance, 5), 6),
        _progress(_goal(GoalMetric.calories, 300), 120),
      ]);
      expect(target?.type, WorkoutTargetType.calories);
      expect(target?.value, 180);

      expect(
        targetFromGoals([_progress(_goal(GoalMetric.calories, 300), 300)]),
        isNull,
      );
    });

    test('weekly goals and other metrics set no target', () {
      expect(
        targetFromGoals([
          _progress(_goal(GoalMetric.distance, 20, weekly: true), 1),
          _progress(_goal(GoalMetric.steps, 8000), 100),
        ]),
        isNull,
      );
    });
  });

  group('timed workout targets', () {
    test("start with what's left of today's active-minutes goal", () {
      final target = timerTargetFromGoals([
        _progress(_goal(GoalMetric.activeMinutes, 30), 12.5),
      ]);
      expect(target?.type, WorkoutTargetType.duration);
      expect(target?.value, 18); // 17.5 min, rounded up
      expect(
        timerTargetFromGoals([
          _progress(_goal(GoalMetric.activeMinutes, 30), 30),
          _progress(_goal(GoalMetric.calories, 300), 100),
        ])?.type,
        WorkoutTargetType.calories,
      );
    });

    test('a time target is typed in minutes, 1 to 360', () {
      final ok = parseActivityTarget(
        WorkoutTargetType.duration,
        '45',
        DistanceUnit.km,
      );
      expect(ok.value, 45);
      expect(
        parseActivityTarget(WorkoutTargetType.duration, '400', DistanceUnit.km)
            .error,
        'Enter 1 to 360 minutes',
      );
    });

    test('a time target is met once the time is up', () {
      bool met(int minutes) => isActivityTargetMet(
        WorkoutTargetType.duration,
        30,
        distanceMeters: 0,
        calories: 0,
        elapsed: Duration(minutes: minutes),
      );
      expect(met(29), isFalse);
      expect(met(30), isTrue);
    });
  });
}
