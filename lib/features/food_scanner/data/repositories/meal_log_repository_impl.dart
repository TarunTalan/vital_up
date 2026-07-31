import 'package:dartz/dartz.dart';
import 'package:logger/logger.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/features/food_scanner/data/datasources/meal_log_local_data_source.dart';
import 'package:vital_up/features/food_scanner/domain/entities/meal_log_entry.dart';
import 'package:vital_up/features/food_scanner/domain/repositories/meal_log_repository.dart';

class MealLogRepositoryImpl implements MealLogRepository {
  final MealLogLocalDataSource localDataSource;
  final Logger logger;

  MealLogRepositoryImpl({
    required this.localDataSource,
    required this.logger,
  });

  @override
  Future<Either<Failure, MealLogEntry>> saveMealLog(MealLogEntry entry) async {
    try {
      await localDataSource.saveMealLog(entry);
      return Right(entry);
    } catch (e) {
      logger.e('Error saving meal log: $e');
      return Left(DatabaseFailure('Failed to save meal log: $e'));
    }
  }

  @override
  Future<Either<Failure, List<MealLogEntry>>> getMealLogsForDate(DateTime date) async {
    try {
      final logs = await localDataSource.getMealLogsForDate(date);
      return Right(logs);
    } catch (e) {
      logger.e('Error getting meal logs for date: $e');
      return Left(DatabaseFailure('Failed to retrieve meal logs: $e'));
    }
  }

  @override
  Future<Either<Failure, List<MealLogEntry>>> getAllMealLogs() async {
    try {
      final logs = await localDataSource.getAllMealLogs();
      return Right(logs);
    } catch (e) {
      logger.e('Error getting all meal logs: $e');
      return Left(DatabaseFailure('Failed to retrieve meal logs: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteMealLog(String id) async {
    try {
      await localDataSource.deleteMealLog(id);
      return const Right(unit);
    } catch (e) {
      logger.e('Error deleting meal log: $e');
      return Left(DatabaseFailure('Failed to delete meal log: $e'));
    }
  }
}
