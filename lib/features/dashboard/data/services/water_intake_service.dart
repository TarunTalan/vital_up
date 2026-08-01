import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/database/collections/water_log_cache.dart';
import 'package:vital_up/core/database/isar_service.dart';

class WaterIntakeService {
  final IsarService _isarService;
  final SharedPreferences _prefs;

  static const _dailyGoalKey = 'daily_water_goal';
  static const _defaultGoalMl = 2500;

  WaterIntakeService(this._isarService, this._prefs);

  Isar get _isar => _isarService.isar;

  /// Get the current daily goal
  int getDailyGoal() {
    return _prefs.getInt(_dailyGoalKey) ?? _defaultGoalMl;
  }

  /// Update the daily goal
  Future<void> setDailyGoal(int goal) async {
    await _prefs.setInt(_dailyGoalKey, goal);
  }

  /// Add a new water intake entry
  Future<WaterLogCache> addWaterLog(String userId, int amountMl) async {
    final log = WaterLogCache()
      ..userId = userId
      ..amountMl = amountMl
      ..timestamp = DateTime.now()
      ..isSynced = false;

    await _isar.writeTxn(() async {
      await _isar.waterLogCaches.put(log);
    });
    return log;
  }

  /// Delete a water intake entry by id (used for undo/delete)
  Future<void> deleteWaterLog(int id) async {
    await _isar.writeTxn(() async {
      await _isar.waterLogCaches.delete(id);
    });
  }

  /// Get all water logs for today for a specific user
  Future<List<WaterLogCache>> getTodayLogs(String userId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    return await _isar.waterLogCaches
        .filter()
        .userIdEqualTo(userId)
        .timestampBetween(startOfDay, endOfDay)
        .sortByTimestamp()
        .findAll();
  }
}
