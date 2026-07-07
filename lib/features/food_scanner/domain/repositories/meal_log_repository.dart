import 'package:dartz/dartz.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/features/food_scanner/domain/entities/meal_log_entry.dart';

abstract class MealLogRepository {
  Future<Either<Failure, MealLogEntry>> saveMealLog(MealLogEntry entry);
  
  Future<Either<Failure, List<MealLogEntry>>> getMealLogsForDate(DateTime date);
  
  Future<Either<Failure, List<MealLogEntry>>> getAllMealLogs();
  
  Future<Either<Failure, Unit>> deleteMealLog(String id);
}
