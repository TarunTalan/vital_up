import 'package:dartz/dartz.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/features/food_scan/domain/entities/meal_log_entry.dart';
import 'package:vital_up/features/food_scan/domain/repositories/meal_log_repository.dart';

class GetMealLogHistory {
  final MealLogRepository mealLogRepository;

  GetMealLogHistory({required this.mealLogRepository});

  Future<Either<Failure, List<MealLogEntry>>> call(DateTime date) async {
    return await mealLogRepository.getMealLogsForDate(date);
  }

  Future<Either<Failure, List<MealLogEntry>>> callAll() async {
    return await mealLogRepository.getAllMealLogs();
  }
}
