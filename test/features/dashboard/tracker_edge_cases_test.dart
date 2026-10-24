// Boundary values for the figures Home shows: rounding that could read as
// a met goal, goals of 0, singular units, weekly pace, weight progress,
// negative durations.
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/widgets/tracker/tracker_status.dart';
import 'package:vital_up/features/activity_goals/domain/entities/activity_goal.dart';
import 'package:vital_up/features/activity_goals/presentation/widgets/goal_widgets.dart';
import 'package:vital_up/features/dashboard/presentation/pages/water_trends_page.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/dashboard_card_header.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/nutrition_summary_card.dart';
import 'package:vital_up/features/diet_plan/domain/entities/meal_plan.dart';
import 'package:vital_up/features/weight/data/weight_service.dart';

void main() {
  group('progress never reads as the goal before it is met', () {
    test('water shows litres exactly, never rounded up', () {
      expect(WaterTrendsPage.formatMl(2960), '2.96 L');
      expect(WaterTrendsPage.formatMl(2999), '2.99 L');
      expect(WaterTrendsPage.formatMl(3000), '3.0 L');
      expect(WaterTrendsPage.formatMl(2500), '2.5 L');
      expect(WaterTrendsPage.formatMl(1250), '1.25 L');
      expect(WaterTrendsPage.formatMl(1050), '1.05 L');
      expect(WaterTrendsPage.formatMl(999), '999 ml');
      expect(WaterTrendsPage.formatMl(0), '0 ml');
    });

    test('distance rounds down and keeps half-step targets', () {
      expect(GoalMetric.distance.format(2.96), '2.9');
      expect(GoalMetric.distance.format(3), '3.0');
      expect(GoalMetric.distance.format(12.5), '12.5');
      expect(GoalMetric.distance.format(17.5), '17.5');
      expect(GoalMetric.distance.format(18), '18');
    });

    test('counts round down', () {
      expect(GoalMetric.activeMinutes.format(29.6), '29');
      expect(GoalMetric.steps.format(9999.9), '9,999');
    });

    test('odd values show as 0, not NaN', () {
      expect(GoalMetric.steps.format(double.nan), '0');
      expect(WaterTrendsPage.formatMl(double.infinity), '0 ml');
    });
  });

  test('one workout is singular', () {
    expect(GoalMetric.workouts.formatWithUnit(1), '1 workout');
    expect(GoalMetric.workouts.formatWithUnit(3), '3 workouts');
    expect(GoalMetric.workouts.formatWithUnit(0), '0 workouts');
    expect(GoalMetric.workouts.formatShortWithUnit(1), '1 workout');
  });

  group('weekly goals keep the week\'s pace', () {
    test('Monday evening is about a seventh of the week', () {
      final mondayEvening = DateTime(2026, 10, 19, 18);
      expect(TrackerStatus.weekPace(mondayEvening), closeTo(0.24 / 1, 0.15));
      expect(
        TrackerStatus.of(
          value: 8000,
          goal: 50000,
          paceFraction: TrackerStatus.weekPace(mondayEvening),
        ),
        isNot(TrackerStatus.behind),
      );
    });

    test('Sunday night is the whole week', () {
      expect(TrackerStatus.weekPace(DateTime(2026, 10, 25, 23, 30)), 1.0);
    });
  });

  group('calorie goal', () {
    const meal = Meal(
      name: 'Lunch',
      items: [],
      calories: 0,
      protein: 0,
      carbs: 0,
      fat: 0,
    );
    const emptyPlan = MealPlan(
      meals: [meal],
      totalCalories: 0,
      totalProtein: 0,
      totalCarbs: 0,
      totalFat: 0,
    );

    test('a plan or goal of 0 is no goal', () {
      expect(calorieGoalFor(emptyPlan, 0), isNull);
      expect(calorieGoalFor(null, 0), isNull);
      expect(calorieGoalFor(emptyPlan, 1800), 1800);
      expect(calorieGoalFor(null, null), isNull);
    });

    test('macro targets of 0 fall back to sensible ones', () {
      final targets = macroTargets(emptyPlan, 2000);
      expect(targets.protein, greaterThan(0));
      expect(targets.carbs, greaterThan(0));
      expect(targets.fat, greaterThan(0));
    });
  });

  group('weight progress toward the goal', () {
    double? progress(double first, double latest, double goal) =>
        weightGoalProgress(firstKg: first, latestKg: latest, goalKg: goal);

    test('half way', () => expect(progress(80, 75, 70), 0.5));
    test('at the goal is full', () => expect(progress(80, 70.3, 70), 1));
    test('starting at the goal and moving away is not full', () {
      expect(progress(70.2, 75, 70), 0);
    });
    test('moving the wrong way is 0, never negative', () {
      expect(progress(80, 85, 70), 0);
    });
    test('no goal or no weigh-in: nothing to show', () {
      expect(
        weightGoalProgress(firstKg: 80, latestKg: 75, goalKg: null),
        isNull,
      );
      expect(
        weightGoalProgress(firstKg: null, latestKg: null, goalKg: 70),
        isNull,
      );
    });
  });

  test('a negative duration reads as 0m, not "-5m"', () {
    expect(formatDashboardDuration(const Duration(minutes: -65)), '0m');
    expect(formatDashboardDuration(const Duration(minutes: 65)), '1h 5m');
  });
}
