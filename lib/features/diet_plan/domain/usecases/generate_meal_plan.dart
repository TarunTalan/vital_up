import 'package:vital_up/core/network/api_result.dart';
import 'package:vital_up/features/diet_plan/domain/entities/meal_plan.dart';
import 'package:vital_up/features/diet_plan/domain/entities/nutrition_target.dart';
import 'package:vital_up/features/diet_plan/domain/repositories/diet_plan_repository.dart';

class GenerateMealPlan {
  final DietPlanRepository repository;

  GenerateMealPlan(this.repository);

  Future<ApiResult<MealPlan>> call({
    required NutritionTarget target,
    required Map<String, dynamic> preferences,
  }) async {
    return repository.generateMealPlan(
      target: target,
      preferences: preferences,
    );
  }
}
