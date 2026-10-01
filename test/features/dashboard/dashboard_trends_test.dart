import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/utils/date_range_utils.dart';
import 'package:vital_up/features/activity_goals/domain/entities/activity_goal.dart';
import 'package:vital_up/features/dashboard/domain/entities/diet_progress.dart';
import 'package:vital_up/features/dashboard/domain/entities/trend_series.dart';
import 'package:vital_up/features/diet_plan/domain/entities/meal_plan.dart';
import 'package:vital_up/features/food_scanner/domain/entities/meal_log_entry.dart';
import 'package:vital_up/features/vita/domain/entities/vita_insights.dart';

MealLogEntry _log(MealType type) => MealLogEntry(
      id: type.name,
      capturedAt: DateTime.now(),
      imagePath: '',
      items: const [],
      nutrition: const [],
      totalCalories: 300,
      mealType: type,
      userConfirmed: true,
    );

Meal _meal(String name) => Meal(
      name: name,
      items: const [],
      calories: 400,
      protein: 20,
      carbs: 40,
      fat: 10,
    );

void main() {
  group('date range utils', () {
    test('startOfWeek is Monday 00:00', () {
      // Thursday 1 Oct 2026.
      expect(startOfWeek(DateTime(2026, 10, 1, 15)), DateTime(2026, 9, 28));
      // A Monday stays on itself.
      expect(startOfWeek(DateTime(2026, 9, 28, 8)), DateTime(2026, 9, 28));
      // Sunday belongs to the week that started six days earlier.
      expect(startOfWeek(DateTime(2026, 10, 4, 23)), DateTime(2026, 9, 28));
    });

    test('lastNDays runs oldest → today across a month boundary', () {
      final days = lastNDays(3, now: DateTime(2026, 10, 1, 9));
      expect(days, [
        DateTime(2026, 9, 29),
        DateTime(2026, 9, 30),
        DateTime(2026, 10, 1),
      ]);
    });

    test('nextDay uses calendar days, not +24h', () {
      expect(nextDay(DateTime(2026, 3, 29)), DateTime(2026, 3, 30));
      expect(nextDay(DateTime(2026, 12, 31)), DateTime(2027, 1, 1));
    });
  });

  group('TrendSeries', () {
    final days = lastNDays(4);
    TrendSeries series(List<double?> values,
            {double? goal, GoalDirection direction = GoalDirection.up}) =>
        TrendSeries(
          [for (var i = 0; i < 4; i++) DailyPoint(days[i], values[i])],
          goal: goal,
          direction: direction,
        );

    test('stats ignore days with no data', () {
      final s = series([1000, null, 3000, null], goal: 2000);
      expect(s.average, 2000);
      expect(s.best, 3000);
      expect(s.loggedDays, 2);
      expect(s.daysMetGoal, 1);
      expect(s.today, isNull);
    });

    test('lower is better for stress', () {
      final s = series([2, 4, 1, 5], goal: 3, direction: GoalDirection.down);
      expect(s.best, 1);
      expect(s.daysMetGoal, 2);
    });

    test('near goal counts days within 10%', () {
      final s = series([1900, 2300, 2050, null],
          goal: 2000, direction: GoalDirection.near);
      expect(s.daysMetGoal, 2);
      expect(s.best, 2050);
    });

    test('sum buckets items by day and leaves gaps', () {
      final now = DateTime.now();
      final s = TrendSeries.sum<(DateTime, double)>(
        days: 3,
        items: [
          (now, 250),
          (now, 500),
          (now.subtract(const Duration(days: 2)), 100),
        ],
        dateOf: (e) => e.$1,
        valueOf: (e) => e.$2,
      );
      expect([for (final p in s.points) p.value], [100, null, 750]);
    });
  });

  group('stress check-ins', () {
    test('JSON round-trips tags and reads older entries without them', () {
      final checkIn = StressCheckIn(
        date: DateTime(2026, 10, 1, 9),
        level: 4,
        tags: const [StressTag.work, StressTag.sleep],
      );
      expect(StressCheckIn.fromJson(checkIn.toJson()), checkIn);

      final legacy = StressCheckIn.fromJson(
        {'d': '2026-09-30T20:00:00.000', 'l': 2},
      );
      expect(legacy.tags, isEmpty);
      expect(legacy.label, 'Calm');

      // Unknown tag names from a newer app version are skipped.
      final future = StressCheckIn.fromJson({
        'd': '2026-09-30T20:00:00.000',
        'l': 3,
        't': ['work', 'pets'],
      });
      expect(future.tags, [StressTag.work]);
    });

    test('streak counts back from today, or yesterday if not logged yet', () {
      final now = DateTime(2026, 10, 1, 8);
      StressCheckIn on(int day) =>
          StressCheckIn(date: DateTime(2026, 9, day, 21), level: 2);

      expect(stressStreak([on(28), on(29), on(30)], now: now), 3);
      expect(
        stressStreak(
          [on(29), on(30), StressCheckIn(date: DateTime(2026, 10, 1, 7), level: 1)],
          now: now,
        ),
        3,
      );
      expect(stressStreak([on(27), on(29)], now: now), 0);
      expect(stressStreak(const [], now: now), 0);
    });
  });

  group('diet progress', () {
    test('maps plan meal names to scanner meal types', () {
      expect(mealTypeForPlanName('Breakfast'), MealType.breakfast);
      expect(mealTypeForPlanName('Light Supper'), MealType.dinner);
      expect(mealTypeForPlanName('Evening Snack'), MealType.snack);
      expect(mealTypeForPlanName('Pre-workout'), isNull);
    });

    test('ticks planned meals, matching snacks in order', () {
      final plan = MealPlan(
        meals: [
          _meal('Breakfast'),
          _meal('Morning Snack'),
          _meal('Lunch'),
          _meal('Evening Snack'),
          _meal('Dinner'),
        ],
        totalCalories: 2000,
        totalProtein: 100,
        totalCarbs: 200,
        totalFat: 50,
      );
      final statuses = plannedMealStatuses(plan, [
        _log(MealType.breakfast),
        _log(MealType.snack),
        _log(MealType.lunch),
      ]);
      expect([for (final s in statuses) s.logged],
          [true, true, true, false, false]);
    });
  });

  group('activity goals', () {
    test('JSON round-trip and invalid entries are dropped', () {
      const goal = ActivityGoal(
        metric: GoalMetric.distance,
        period: GoalPeriod.weekly,
        target: 15,
      );
      expect(ActivityGoal.fromJson(goal.toJson()), goal);
      expect(goal.id, 'distance_weekly');
      expect(ActivityGoal.fromJson({'m': 'swim', 'p': 'daily', 't': 1}), isNull);
      expect(ActivityGoal.fromJson({'m': 'steps', 'p': 'daily', 't': 0}), isNull);
    });
  });
}
