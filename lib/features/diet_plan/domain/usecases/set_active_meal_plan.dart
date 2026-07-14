import 'package:vital_up/features/diet_plan/domain/entities/meal_plan.dart';
import 'package:vital_up/features/diet_plan/domain/repositories/diet_plan_repository.dart';

class SetActiveMealPlan {
  final DietPlanRepository repository;

  SetActiveMealPlan(this.repository);

  Future<void> call(MealPlan plan) async {
    return repository.setActiveMealPlan(plan);
  }
}
