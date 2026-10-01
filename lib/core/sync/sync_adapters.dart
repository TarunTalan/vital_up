import 'package:drift/drift.dart' show Value;
import 'package:isar_community/isar.dart';
import 'package:uuid/uuid.dart';
import 'package:vital_up/core/database/collections/meal_log_cache.dart';
import 'package:vital_up/core/database/collections/sleep_log_cache.dart';
import 'package:vital_up/core/database/collections/water_log_cache.dart';
import 'package:vital_up/core/database/collections/weight_log_cache.dart';
import 'package:vital_up/core/database/drift_database.dart';
import 'package:vital_up/core/database/isar_service.dart';

/// A local row waiting to be uploaded, already in the table's shape.
class PendingRow {
  final Object localKey;
  final Map<String, dynamic> row;

  const PendingRow(this.localKey, this.row);
}

/// Bridges one local store and one Supabase table.
abstract class SyncAdapter {
  /// Supabase table name.
  String get table;

  /// Local changes not uploaded yet.
  Future<List<PendingRow>> pending(String userId);

  Future<void> markSynced(String userId, List<Object> localKeys);

  /// Merges rows pulled from the server (including soft-deleted ones).
  Future<void> apply(String userId, List<Map<String, dynamic>> rows);
}

/// Stable cloud id for a local entry that has no id of its own, so the same
/// entry uploaded twice (or pulled back) never duplicates.
String syncId(String kind, String userId, DateTime at) => const Uuid().v5(
  Namespace.url.value,
  'vitalup:$kind:$userId:${at.toUtc().microsecondsSinceEpoch}',
);

String _iso(DateTime t) => t.toUtc().toIso8601String();
DateTime _time(Object? v) => DateTime.parse(v as String).toLocal();
bool _deleted(Map<String, dynamic> row) => row['deleted_at'] != null;

// ---------------------------------------------------------------------------

class WaterSyncAdapter implements SyncAdapter {
  final IsarService _db;
  WaterSyncAdapter(this._db);

  Isar get _isar => _db.isar;

  @override
  String get table => 'water_logs';

  @override
  Future<List<PendingRow>> pending(String userId) async {
    final logs = await _isar.waterLogCaches
        .filter()
        .userIdEqualTo(userId)
        .isSyncedEqualTo(false)
        .findAll();
    return [
      for (final l in logs)
        PendingRow(l.id, {
          'id': syncId('water', userId, l.timestamp),
          'user_id': userId,
          'amount_ml': l.amountMl,
          'logged_at': _iso(l.timestamp),
        }),
    ];
  }

  @override
  Future<void> markSynced(String userId, List<Object> localKeys) =>
      _isar.writeTxn(() async {
        final logs = await _isar.waterLogCaches.getAll(localKeys.cast<int>());
        await _isar.waterLogCaches.putAll([
          for (final l in logs.nonNulls) l..isSynced = true,
        ]);
      });

  @override
  Future<void> apply(String userId, List<Map<String, dynamic>> rows) =>
      _isar.writeTxn(() async {
        for (final row in rows) {
          final at = _time(row['logged_at']);
          final existing = await _isar.waterLogCaches
              .filter()
              .userIdEqualTo(userId)
              .timestampEqualTo(at)
              .findAll();
          if (_deleted(row)) {
            await _isar.waterLogCaches.deleteAll([
              for (final e in existing) e.id,
            ]);
          } else if (existing.isEmpty) {
            await _isar.waterLogCaches.put(
              WaterLogCache()
                ..userId = userId
                ..amountMl = (row['amount_ml'] as num).toInt()
                ..timestamp = at
                ..isSynced = true,
            );
          }
        }
      });
}

// ---------------------------------------------------------------------------

class SleepSyncAdapter implements SyncAdapter {
  /// Manual logs saved before entries were tied to the signed-in user.
  static const legacyUserId = 'current_user';

  final IsarService _db;
  SleepSyncAdapter(this._db);

  Isar get _isar => _db.isar;

  @override
  String get table => 'sleep_logs';

  @override
  Future<List<PendingRow>> pending(String userId) async {
    final logs = await _isar.sleepLogCaches
        .filter()
        .group((q) => q.userIdEqualTo(userId).or().userIdEqualTo(legacyUserId))
        .isSyncedEqualTo(false)
        .findAll();
    return [
      for (final l in logs)
        PendingRow(l.id, {
          'id': syncId('sleep', userId, l.startTime),
          'user_id': userId,
          'start_time': _iso(l.startTime),
          'end_time': _iso(l.endTime),
          'duration_minutes': l.durationMinutes,
          'source': l.source,
        }),
    ];
  }

  @override
  Future<void> markSynced(String userId, List<Object> localKeys) =>
      _isar.writeTxn(() async {
        final logs = await _isar.sleepLogCaches.getAll(localKeys.cast<int>());
        await _isar.sleepLogCaches.putAll([
          for (final l in logs.nonNulls)
            l
              ..userId = userId
              ..isSynced = true,
        ]);
      });

  @override
  Future<void> apply(String userId, List<Map<String, dynamic>> rows) =>
      _isar.writeTxn(() async {
        for (final row in rows) {
          final start = _time(row['start_time']);
          final existing = await _isar.sleepLogCaches
              .filter()
              .userIdEqualTo(userId)
              .startTimeEqualTo(start)
              .findAll();
          if (_deleted(row)) {
            await _isar.sleepLogCaches.deleteAll([
              for (final e in existing) e.id,
            ]);
          } else if (existing.isEmpty) {
            await _isar.sleepLogCaches.put(
              SleepLogCache()
                ..userId = userId
                ..startTime = start
                ..endTime = _time(row['end_time'])
                ..durationMinutes = (row['duration_minutes'] as num).toInt()
                ..source = row['source'] as String? ?? 'manual'
                ..isSynced = true,
            );
          }
        }
      });
}

// ---------------------------------------------------------------------------

class MealSyncAdapter implements SyncAdapter {
  final IsarService _db;
  MealSyncAdapter(this._db);

  Isar get _isar => _db.isar;

  @override
  String get table => 'meal_logs';

  @override
  Future<List<PendingRow>> pending(String userId) async {
    final meals = await _isar.mealLogCaches
        .filter()
        .isSyncedEqualTo(false)
        .findAll();
    return [
      for (final m in meals)
        PendingRow(m.id, {
          'id': m.mealLogId,
          'user_id': userId,
          'captured_at': _iso(m.capturedAt),
          'meal_type': m.mealType,
          'total_calories': m.totalCalories,
          'data': {
            'item_ids': m.itemIds,
            'item_names': m.itemNames,
            'item_confidences': m.itemConfidences,
            'item_serving_descriptions': m.itemServingDescriptions,
            'item_quantities': m.itemQuantities,
            'item_units': m.itemUnits,
            'calories': m.nutritionCalories,
            'protein_g': m.nutritionProteinG,
            'carbs_g': m.nutritionCarbsG,
            'fat_g': m.nutritionFatG,
            'fiber_g': m.nutritionFiberG,
            'sugar_g': m.nutritionSugarG,
            'sodium_mg': m.nutritionSodiumMg,
            'user_confirmed': m.userConfirmed,
            'created_at': m.createdAt == null ? null : _iso(m.createdAt!),
          },
        }),
    ];
  }

  @override
  Future<void> markSynced(String userId, List<Object> localKeys) =>
      _isar.writeTxn(() async {
        final meals = await _isar.mealLogCaches.getAll(localKeys.cast<int>());
        await _isar.mealLogCaches.putAll([
          for (final m in meals.nonNulls) m..isSynced = true,
        ]);
      });

  @override
  Future<void> apply(
    String userId,
    List<Map<String, dynamic>> rows,
  ) => _isar.writeTxn(() async {
    for (final row in rows) {
      final id = row['id'] as String;
      final existing = await _isar.mealLogCaches
          .where()
          .mealLogIdEqualTo(id)
          .findAll();
      if (_deleted(row)) {
        await _isar.mealLogCaches.deleteAll([for (final e in existing) e.id]);
        continue;
      }
      // A local edit not uploaded yet wins.
      if (existing.any((e) => !e.isSynced)) continue;
      final d = Map<String, dynamic>.from(row['data'] as Map);
      List<String> strings(String k) => [
        for (final v in (d[k] as List? ?? const [])) '$v',
      ];
      List<double> numbers(String k) => [
        for (final v in (d[k] as List? ?? const [])) (v as num).toDouble(),
      ];
      final meal = (existing.isEmpty ? MealLogCache() : existing.first)
        ..mealLogId = id
        ..capturedAt = _time(row['captured_at'])
        // Photos stay on the phone that took them.
        ..imagePath = existing.isEmpty ? '' : existing.first.imagePath
        ..itemIds = strings('item_ids')
        ..itemNames = strings('item_names')
        ..itemConfidences = numbers('item_confidences')
        ..itemServingDescriptions = strings('item_serving_descriptions')
        ..itemQuantities = numbers('item_quantities')
        ..itemUnits = strings('item_units')
        ..nutritionCalories = numbers('calories')
        ..nutritionProteinG = numbers('protein_g')
        ..nutritionCarbsG = numbers('carbs_g')
        ..nutritionFatG = numbers('fat_g')
        ..nutritionFiberG = numbers('fiber_g')
        ..nutritionSugarG = numbers('sugar_g')
        ..nutritionSodiumMg = numbers('sodium_mg')
        ..totalCalories = (row['total_calories'] as num).toDouble()
        ..mealType = (row['meal_type'] as num).toInt()
        ..userConfirmed = d['user_confirmed'] as bool? ?? true
        ..createdAt = d['created_at'] == null ? null : _time(d['created_at'])
        ..isSynced = true;
      await _isar.mealLogCaches.put(meal);
    }
  });
}

// ---------------------------------------------------------------------------

class WeightSyncAdapter implements SyncAdapter {
  final IsarService _db;
  WeightSyncAdapter(this._db);

  Isar get _isar => _db.isar;

  @override
  String get table => 'weight_logs';

  @override
  Future<List<PendingRow>> pending(String userId) async {
    final logs = await _isar.weightLogCaches
        .filter()
        .userIdEqualTo(userId)
        .isSyncedEqualTo(false)
        .findAll();
    return [
      for (final l in logs)
        PendingRow(l.id, {
          'id': syncId('weight', userId, l.timestamp),
          'user_id': userId,
          'weight_kg': double.parse(l.weightKg.toStringAsFixed(2)),
          'logged_at': _iso(l.timestamp),
          'source': l.source,
        }),
    ];
  }

  @override
  Future<void> markSynced(String userId, List<Object> localKeys) =>
      _isar.writeTxn(() async {
        final logs = await _isar.weightLogCaches.getAll(localKeys.cast<int>());
        await _isar.weightLogCaches.putAll([
          for (final l in logs.nonNulls) l..isSynced = true,
        ]);
      });

  @override
  Future<void> apply(String userId, List<Map<String, dynamic>> rows) =>
      _isar.writeTxn(() async {
        for (final row in rows) {
          final at = _time(row['logged_at']);
          final existing = await _isar.weightLogCaches
              .filter()
              .userIdEqualTo(userId)
              .timestampEqualTo(at)
              .findAll();
          if (_deleted(row)) {
            await _isar.weightLogCaches.deleteAll([
              for (final e in existing) e.id,
            ]);
          } else if (existing.isEmpty) {
            await _isar.weightLogCaches.put(
              WeightLogCache()
                ..userId = userId
                ..weightKg = (row['weight_kg'] as num).toDouble()
                ..timestamp = at
                ..source = row['source'] as String? ?? 'manual'
                ..isSynced = true,
            );
          }
        }
      });
}

// ---------------------------------------------------------------------------

class ActivitySyncAdapter implements SyncAdapter {
  final AppDatabase _db;
  ActivitySyncAdapter(this._db);

  @override
  String get table => 'activity_sessions';

  @override
  Future<List<PendingRow>> pending(String userId) async {
    final sessions = await _db.unsyncedFinishedSessions();
    return [
      for (final s in sessions)
        PendingRow(s.id, {
          'id': s.id,
          'user_id': userId,
          'activity_type': s.activityType,
          'start_time': _iso(s.startTime),
          'end_time': s.endTime == null ? null : _iso(s.endTime!),
          'data': s.toJson()..remove('synced'),
          'track': [
            for (final p in await _db.getTrackPointsForSession(s.id))
              [
                p.latitude,
                p.longitude,
                p.timestamp.millisecondsSinceEpoch,
                p.accuracy,
                p.speed,
                p.altitude,
              ],
          ],
        }),
    ];
  }

  @override
  Future<void> markSynced(String userId, List<Object> localKeys) =>
      _db.markSessionsSynced(localKeys.cast<String>());

  @override
  Future<void> apply(String userId, List<Map<String, dynamic>> rows) async {
    for (final row in rows) {
      final id = row['id'] as String;
      if (_deleted(row)) {
        await _db.deleteSession(id);
        continue;
      }
      final local = await _db.getSession(id);
      // A local change not uploaded yet wins.
      if (local != null && !local.synced) continue;

      final data = Map<String, dynamic>.from(row['data'] as Map);
      final session = DriftActivitySession.fromJson({...data, 'synced': true});
      final points = [
        for (final p in (row['track'] as List? ?? const []))
          DriftTrackPointsCompanion.insert(
            sessionId: id,
            latitude: ((p as List)[0] as num).toDouble(),
            longitude: (p[1] as num).toDouble(),
            timestamp: DateTime.fromMillisecondsSinceEpoch(
              (p[2] as num).toInt(),
            ),
            accuracy: (p[3] as num).toDouble(),
            speed: (p[4] as num).toDouble(),
            altitude: Value((p[5] as num).toDouble()),
          ),
      ];
      await _db.saveSyncedSession(session.toCompanion(true), points);
    }
  }
}
