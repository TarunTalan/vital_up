import 'package:vital_up/features/food_scan/domain/entities/meal_log_entry.dart';

abstract class MealLogLocalDataSource {
  Future<void> saveMealLog(MealLogEntry entry);
  Future<List<MealLogEntry>> getMealLogsForDate(DateTime date);
  Future<List<MealLogEntry>> getAllMealLogs();
  Future<void> deleteMealLog(String id);
}
