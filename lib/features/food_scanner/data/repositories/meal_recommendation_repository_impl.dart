import 'package:vital_up/features/food_scanner/domain/entities/meal_log_entry.dart';
import 'package:vital_up/features/food_scanner/domain/entities/meal_recommendation.dart';
import 'package:vital_up/features/food_scanner/domain/entities/nutrition_info.dart';
import 'package:vital_up/features/food_scanner/domain/repositories/meal_recommendation_repository.dart';

/// Rule-based feedback for a single meal.
///
/// Thresholds are per meal (roughly a third of a 2000 kcal day) and follow
/// ICMR-NIN 2024 / WHO guidance: fat under ~30-35% of energy, saturated fat
/// under 10%, free sugar low, sodium under 2000 mg/day. Ratios compare
/// energy with energy (grams x 4 or 9 kcal), never grams with kcal.
class MealRecommendationRepositoryImpl implements MealRecommendationRepository {
  static const _kcalPerGramProtein = 4.0;
  static const _kcalPerGramCarb = 4.0;
  static const _kcalPerGramFat = 9.0;

  @override
  MealRecommendation recommend(
    MealLogEntry entry, {
    List<dynamic>? recentActivity,
    required DateTime now,
  }) {
    double sum(double Function(NutritionInfo n) pick) =>
        entry.nutrition.fold<double>(0, (total, n) => total + pick(n));

    final protein = sum((n) => n.proteinG);
    final fat = sum((n) => n.fatG);
    final satFat = sum((n) => n.saturatedFatG);
    final sugar = sum((n) => n.sugarG);
    final fiber = sum((n) => n.fiberG);
    final sodium = sum((n) => n.sodiumMg);
    final calories = entry.totalCalories;

    if (calories <= 0) {
      return const MealRecommendation(message: '', reasonTags: []);
    }

    final proteinShare = protein * _kcalPerGramProtein / calories;
    final fatShare = fat * _kcalPerGramFat / calories;
    final satFatShare = satFat * _kcalPerGramFat / calories;
    final sugarShare = sugar * _kcalPerGramCarb / calories;
    final isSubstantial = calories >= 300;

    // Ordered by how much the user should act on it; the first tag drives the
    // headline message, all tags become suggestion bullets.
    final tags = <String>[
      if (_isPostWorkout(recentActivity, now) && proteinShare >= 0.2) 'post_workout_window',
      if (sodium >= 900) 'high_sodium',
      if (sugar >= 25 || (sugar >= 10 && sugarShare > 0.25)) 'high_sugar',
      if (satFatShare > 0.12 && satFat >= 5) 'high_saturated_fat',
      if (fatShare > 0.40 && fat >= 12) 'high_fat',
      if (isSubstantial && proteinShare < 0.10) 'low_protein',
      if (proteinShare >= 0.25 && protein >= 15) 'high_protein',
      if (isSubstantial && fiber < 3) 'low_fiber',
      if (fiber >= 8) 'high_fiber',
      if (calories >= 900) 'large_meal',
      if (now.hour >= 21 && calories >= 500) 'late_eating',
    ];

    return MealRecommendation(
      message: tags.isEmpty ? _balancedMessage(entry.mealType) : _headline(tags.first, sodium: sodium),
      reasonTags: tags,
    );
  }

  bool _isPostWorkout(List<dynamic>? recentActivity, DateTime now) {
    if (recentActivity == null || recentActivity.isEmpty) return false;
    final latest = recentActivity.first;
    if (latest is! Map<String, dynamic>) return false;
    final endTime = latest['end_time'];
    if (endTime is! DateTime) return false;
    final since = now.difference(endTime);
    return !since.isNegative && since.inHours <= 2;
  }

  String _headline(String tag, {required double sodium}) {
    switch (tag) {
      case 'post_workout_window':
        return 'Great post-workout meal. The protein here supports muscle recovery.';
      case 'high_sodium':
        return 'This meal is high in salt (~${sodium.round()} mg sodium). Go easy on pickle, papad and added salt for the rest of the day.';
      case 'high_sugar':
        return 'This meal is high in sugar. Keep your next snack unsweetened and pair sweets with a protein-rich meal.';
      case 'high_saturated_fat':
        return 'Much of the fat here is saturated (ghee, butter, cream, fried food). Try a lighter tadka or a roasted option next time.';
      case 'high_fat':
        return 'Most of this meal\'s energy comes from fat, likely oil or ghee. Balance it with lighter meals today.';
      case 'low_protein':
        return 'This meal is low in protein. Add dal, curd, paneer, eggs, sprouts or chicken to make it more filling.';
      case 'high_protein':
        return 'This meal is high in protein, which is great for satiety and muscle maintenance.';
      case 'low_fiber':
        return 'Low in fibre. Add a salad, sabzi, fruit or swap to whole-wheat roti or brown rice.';
      case 'high_fiber':
        return 'Good fibre content, which helps digestion and keeps you full longer.';
      case 'large_meal':
        return 'This is a large meal. Keep the next one light and include some activity today.';
      case 'late_eating':
        return 'Heavy meal late in the evening. Try to finish eating 2-3 hours before bed.';
      default:
        return '';
    }
  }

  String _balancedMessage(MealType mealType) {
    switch (mealType) {
      case MealType.breakfast:
        return 'Good breakfast choice. A balanced start to your day.';
      case MealType.lunch:
        return 'Balanced lunch to keep you energized for the afternoon.';
      case MealType.dinner:
        return 'Well-rounded dinner. Try to finish eating 2-3 hours before bedtime.';
      case MealType.snack:
        return 'Healthy snack choice. Keep portions moderate.';
    }
  }
}
