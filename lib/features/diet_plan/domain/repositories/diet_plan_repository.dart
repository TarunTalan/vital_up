import 'package:vital_up/core/network/api_result.dart';
import 'package:vital_up/features/diet_plan/domain/entities/meal_plan.dart';
import 'package:vital_up/features/diet_plan/domain/entities/nutrition_target.dart';

abstract class DietPlanRepository {
  Future<ApiResult<MealPlan>> generateMealPlan({
    required NutritionTarget target,
    required Map<String, dynamic> preferences,
    String? instructions,
    MealPlan? basePlan,
  });

  Future<MealPlan?> getActiveMealPlan();

  /// [preferences] are kept so the active plan can be tweaked later
  /// (e.g. from Vita) with the same dietary constraints.
  Future<void> setActiveMealPlan(
    MealPlan plan, {
    Map<String, dynamic> preferences = const {},
  });

  /// Preferences the active plan was generated with ({} if unknown).
  Future<Map<String, dynamic>> getActivePlanPreferences();
}
