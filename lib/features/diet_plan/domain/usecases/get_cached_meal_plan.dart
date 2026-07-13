import 'package:vital_up/features/diet_plan/domain/entities/meal_plan.dart';
import 'package:vital_up/features/diet_plan/domain/repositories/diet_plan_repository.dart';

class GetCachedMealPlan {
  final DietPlanRepository repository;

  GetCachedMealPlan(this.repository);

  Future<MealPlan?> call(String dateKey) async {
    return repository.getCachedMealPlan(dateKey);
  }
}
