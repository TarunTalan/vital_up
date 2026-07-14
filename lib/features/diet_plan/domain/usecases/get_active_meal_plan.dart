import 'package:vital_up/features/diet_plan/domain/entities/meal_plan.dart';
import 'package:vital_up/features/diet_plan/domain/repositories/diet_plan_repository.dart';

class GetActiveMealPlan {
  final DietPlanRepository repository;

  GetActiveMealPlan(this.repository);

  Future<MealPlan?> call() async {
    return repository.getActiveMealPlan();
  }
}
