import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/food_scanner/data/repositories/meal_recommendation_repository_impl.dart';
import 'package:vital_up/features/food_scanner/domain/entities/food_item.dart';
import 'package:vital_up/features/food_scanner/domain/entities/meal_log_entry.dart';
import 'package:vital_up/features/food_scanner/domain/entities/nutrition_info.dart';

const _item = FoodItem(
  id: '1',
  name: 'Test',
  confidenceScore: 1,
  servingDescription: '100 g',
  quantity: 100,
  unit: 'g',
);

MealLogEntry _meal({
  required double calories,
  double protein = 0,
  double carbs = 0,
  double fat = 0,
  double fiber = 5,
  double sugar = 0,
  double sodium = 300,
  double satFat = 0,
  MealType mealType = MealType.lunch,
}) {
  final nutrition = NutritionInfo(
    calories: calories,
    proteinG: protein,
    carbsG: carbs,
    fatG: fat,
    fiberG: fiber,
    sugarG: sugar,
    sodiumMg: sodium,
    saturatedFatG: satFat,
    per: _item,
  );
  return MealLogEntry(
    id: 'm',
    capturedAt: DateTime(2026, 9, 30, 13),
    imagePath: '',
    items: const [_item],
    nutrition: [nutrition],
    totalCalories: calories,
    mealType: mealType,
    userConfirmed: true,
  );
}

void main() {
  final repo = MealRecommendationRepositoryImpl();
  final noon = DateTime(2026, 9, 30, 13);

  test('flags fatty meals by energy share, not grams-per-kcal', () {
    // 30 g fat = 270 kcal of a 500 kcal meal (54%). The old grams/kcal ratio
    // (30/500 = 0.06) could never cross its 0.35 threshold.
    final result = repo.recommend(_meal(calories: 500, protein: 12, carbs: 45, fat: 30), now: noon);
    expect(result.reasonTags, contains('high_fat'));
    expect(result.message, isNot(contains('healthy fats')));
  });

  test('balanced meal gets the meal-type message and no tags', () {
    final result = repo.recommend(_meal(calories: 500, protein: 25, carbs: 65, fat: 15), now: noon);
    expect(result.reasonTags, isEmpty);
    expect(result.message, contains('lunch'));
  });

  test('salt outranks other findings in the headline', () {
    final result = repo.recommend(
      _meal(calories: 600, protein: 10, carbs: 60, fat: 34, sodium: 1400),
      now: noon,
    );
    expect(result.reasonTags.first, 'high_sodium');
    expect(result.message, contains('1400 mg'));
  });

  test('low protein and low fibre are called out for a real meal', () {
    final result = repo.recommend(
      _meal(calories: 450, protein: 6, carbs: 85, fat: 8, fiber: 1),
      now: noon,
    );
    expect(result.reasonTags, containsAll(['low_protein', 'low_fiber']));
  });

  test('sweets are flagged for sugar', () {
    final result = repo.recommend(
      _meal(calories: 320, protein: 4, carbs: 52, fat: 11, sugar: 44),
      now: noon,
    );
    expect(result.reasonTags, contains('high_sugar'));
  });

  test('zero-calorie entries produce no advice instead of dividing by zero', () {
    final result = repo.recommend(_meal(calories: 0), now: noon);
    expect(result.message, isEmpty);
    expect(result.reasonTags, isEmpty);
  });

  test('post-workout protein meal is recognised', () {
    final result = repo.recommend(
      _meal(calories: 450, protein: 35, carbs: 45, fat: 12),
      now: noon,
      recentActivity: [
        {'end_time': noon.subtract(const Duration(minutes: 45))},
      ],
    );
    expect(result.reasonTags.first, 'post_workout_window');
  });
}
