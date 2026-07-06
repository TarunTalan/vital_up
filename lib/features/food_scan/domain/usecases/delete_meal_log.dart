import 'package:dartz/dartz.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/features/food_scan/domain/repositories/meal_log_repository.dart';

class DeleteMealLog {
  final MealLogRepository mealLogRepository;

  DeleteMealLog({required this.mealLogRepository});

  Future<Either<Failure, Unit>> call(String id) async {
    return await mealLogRepository.deleteMealLog(id);
  }
}
