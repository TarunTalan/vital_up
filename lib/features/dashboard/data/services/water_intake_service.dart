import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/database/collections/water_log_cache.dart';
import 'package:vital_up/core/database/isar_service.dart';
import 'package:vital_up/core/sync/sync_adapters.dart';
import 'package:vital_up/core/sync/sync_hooks.dart';
import 'package:vital_up/core/events/habit_events.dart';
import 'package:vital_up/core/utils/date_range_utils.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/features/dashboard/domain/tracker_input_rules.dart';

class WaterIntakeService {
  final IsarService _isarService;
  final SharedPreferences _prefs;
  final SyncHooks? _sync;
  final HabitEvents? _events;

  static const _dailyGoalKey = 'daily_water_goal';
  static const _defaultGoalMl = 2500;

  WaterIntakeService(
    this._isarService,
    this._prefs, [
    this._sync,
    this._events,
  ]);

  Isar get _isar => _isarService.isar;

  /// The daily goal in ml; the default when unset or out of range.
  int getDailyGoal() => sanitizeWaterGoal(
    _prefs.getInt(_dailyGoalKey),
    fallback: _defaultGoalMl,
  );

  /// Saves the daily goal, kept within the allowed range.
  Future<void> setDailyGoal(int goal) async {
    await _prefs.setInt(
      _dailyGoalKey,
      goal.clamp(InputLimits.waterGoalMlMin, InputLimits.waterGoalMlMax),
    );
  }

  /// Add a new water intake entry. Throws [ArgumentError] for an amount
  /// outside [InputLimits.waterMlMin]..[InputLimits.waterMlMax].
  Future<WaterLogCache> addWaterLog(String userId, int amountMl) async {
    if (amountMl < InputLimits.waterMlMin ||
        amountMl > InputLimits.waterMlMax) {
      throw ArgumentError.value(amountMl, 'amountMl', 'out of range');
    }
    final log = WaterLogCache()
      ..userId = userId
      ..amountMl = amountMl
      ..timestamp = DateTime.now()
      ..isSynced = false;

    await _isar.writeTxn(() async {
      await _isar.waterLogCaches.put(log);
    });
    _sync?.schedule();
    if (_events != null) {
      final today = await getTodayLogs(userId);
      final total = today.fold<int>(0, (sum, l) => sum + l.amountMl);
      _events.logged(
        HabitLogged(Habit.water, goalReached: total >= getDailyGoal()),
      );
    }
    return log;
  }

  /// Delete a water intake entry by id (used for undo/delete)
  Future<void> deleteWaterLog(int id) async {
    final log = await _isar.waterLogCaches.get(id);
    await _isar.writeTxn(() async {
      await _isar.waterLogCaches.delete(id);
    });
    if (log != null && log.isSynced) {
      await _sync?.recordDelete(
        'water_logs',
        syncId('water', log.userId, log.timestamp),
      );
    }
  }

  /// Water logs in [from, to) for a user, oldest first.
  Future<List<WaterLogCache>> getLogsBetween(
    String userId,
    DateTime from,
    DateTime to,
  ) {
    return _isar.waterLogCaches
        .filter()
        .userIdEqualTo(userId)
        .timestampBetween(from, to, includeUpper: false)
        .sortByTimestamp()
        .findAll();
  }

  /// Get all water logs for today for a specific user
  Future<List<WaterLogCache>> getTodayLogs(String userId) async {
    final today = startOfDay(DateTime.now());
    return getLogsBetween(userId, today, nextDay(today));
  }
}
