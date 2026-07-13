import 'package:vital_up/core/network/api_result.dart';
import 'package:vital_up/features/diet_plan/domain/entities/meal_plan.dart';
import 'package:vital_up/features/diet_plan/domain/entities/nutrition_target.dart';

abstract class DietPlanRepository {
  Future<ApiResult<MealPlan>> generateMealPlan({
    required NutritionTarget target,
    required Map<String, dynamic> preferences,
  });

  Future<MealPlan?> getCachedMealPlan(String dateKey);
}
