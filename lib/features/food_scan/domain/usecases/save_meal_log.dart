import 'package:dartz/dartz.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/features/food_scan/domain/entities/meal_log_entry.dart';
import 'package:vital_up/features/food_scan/domain/repositories/meal_log_repository.dart';

class SaveMealLog {
  final MealLogRepository mealLogRepository;

  SaveMealLog({required this.mealLogRepository});

  Future<Either<Failure, MealLogEntry>> call(MealLogEntry entry) async {
    return await mealLogRepository.saveMealLog(entry);
  }
}
