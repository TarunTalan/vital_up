import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/diet_plan/data/models/meal_plan_model.dart';

void main() {
  test('skips malformed meals and clamps values', () {
    final plan = MealPlanModel.fromJson({
      'meals': [
        'not a meal',
        {
          'name': '  Breakfast\n',
          'items': ['Poha', null, '  ', 'Tea'],
          'calories': -100,
          'protein': '20',
          'carbs': 1e9,
          'fat': 10,
        },
        {'name': '', 'items': []},
      ],
    }, 'k');
    expect(plan.meals, hasLength(1));
    final meal = plan.meals!.single;
    expect(meal.name, 'Breakfast');
    expect(meal.items, ['Poha', 'Tea']);
    expect(meal.calories, 0);
    expect(meal.protein, 20);
    expect(meal.carbs, MealModel.maxGrams);
  });

  test('sums missing totals from the meals', () {
    final plan = MealPlanModel.fromJson({
      'meals': [
        {'name': 'Lunch', 'items': ['Rice'], 'calories': 500, 'protein': 20, 'carbs': 80, 'fat': 10},
        {'name': 'Dinner', 'items': ['Roti'], 'calories': 400, 'protein': 15, 'carbs': 60, 'fat': 8},
      ],
    }, 'k');
    expect(plan.totalCalories, 900);
    expect(plan.totalProtein, 35);
  });

  test('a response without meals gives no meals', () {
    final plan = MealPlanModel.fromJson({'meals': 'oops'}, 'k');
    expect(plan.meals, isNull);
  });
}
