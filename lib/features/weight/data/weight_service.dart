import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/cache/cache_store.dart';
import 'package:vital_up/core/database/collections/weight_log_cache.dart';
import 'package:vital_up/core/database/isar_service.dart';
import 'package:vital_up/core/sync/pending_writes.dart';
import 'package:vital_up/core/sync/sync_adapters.dart';
import 'package:vital_up/core/sync/sync_hooks.dart';
import 'package:vital_up/core/utils/date_range_utils.dart';
import 'package:vital_up/features/dashboard/domain/entities/trend_series.dart';
import 'package:vital_up/features/profile/data/profile_cache.dart';
import 'package:vital_up/features/settings/domain/repositories/settings_repository.dart';
import 'package:vital_up/core/events/habit_events.dart';

/// Kilograms per pound.
const kgPerLb = 0.45359237;

/// Display unit for weights, from Settings.
enum WeightUnit {
  kg('kg'),
  lbs('lbs');

  final String label;
  const WeightUnit(this.label);

  /// Settings use 'lbs'; onboarding stores 'lb'.
  static WeightUnit fromCode(String? code) =>
      code != null && code.toLowerCase().startsWith('lb') ? lbs : kg;

  double fromKg(double kg) => this == lbs ? kg / kgPerLb : kg;
  double toKg(double value) => this == lbs ? value * kgPerLb : value;

  /// "72.4 kg"
  String format(double kg, {int decimals = 1}) =>
      '${fromKg(kg).toStringAsFixed(decimals)} $label';
}

/// Body weight log: stored locally (always kg), backed up by SyncService,
/// and mirrored to the profile so diet targets use the latest weight.
class WeightService {
  final IsarService _db;
  final SupabaseClient _client;
  final SettingsRepository _settings;
  final SharedPreferences _prefs;
  final CacheStore _cache;
  final PendingWrites _pendingWrites;
  final SyncHooks? _sync;
  final HabitEvents? _events;

  WeightService(
    this._db,
    this._client,
    this._settings,
    this._prefs,
    this._cache,
    this._pendingWrites, [
    this._sync,
    this._events,
  ]);

  /// Pre-cache builds kept the goal here (not per user); read as a fallback.
  static const _keyTargetKg = 'weight_target_kg';

  /// Goal weight (kg) in [CacheStore]; onboarding writes it too.
  static String targetCacheKey(String userId) => 'weight:target:$userId';

  /// The goal only changes in onboarding / goal setup, which update the
  /// cache directly, so the chart rarely needs to ask the server.
  static const _targetMaxAge = Duration(hours: 12);
  static const minKg = 20.0;
  static const maxKg = 400.0;

  Isar get _isar => _db.isar;

  String? get _userId => _client.auth.currentUser?.id;

  Future<WeightUnit> unit() async {
    final result = await _settings.getSettings();
    return result.fold(
      (_) => WeightUnit.kg,
      (s) => WeightUnit.fromCode(s.weightUnit),
    );
  }

  /// Saves an entry; returns null, or an error message for invalid input.
  Future<String?> add(
    double kg, {
    DateTime? at,
    String source = 'manual',
  }) async {
    final userId = _userId;
    if (userId == null) return 'Sign in to log your weight.';
    if (kg < minKg || kg > maxKg)
      return 'Enter a weight between 20 and 400 kg.';
    final log = WeightLogCache()
      ..userId = userId
      ..weightKg = kg
      ..timestamp = at ?? DateTime.now()
      ..source = source;
    await _isar.writeTxn(() => _isar.weightLogCaches.put(log));
    _sync?.schedule();
    final now = DateTime.now();
    if (log.timestamp.year == now.year &&
        log.timestamp.month == now.month &&
        log.timestamp.day == now.day) {
      _events?.logged(const HabitLogged(Habit.weight));
    }
    final latest = await this.latest();
    if (latest?.id == log.id) unawaited(_updateProfileWeight(kg));
    return null;
  }

  Future<void> delete(WeightLogCache log) async {
    await _isar.writeTxn(() => _isar.weightLogCaches.delete(log.id));
    if (log.isSynced) {
      await _sync?.recordDelete(
        'weight_logs',
        syncId('weight', log.userId, log.timestamp),
      );
    }
  }

  /// Entries in [from, to), newest first.
  Future<List<WeightLogCache>> between(DateTime from, DateTime to) async {
    final userId = _userId;
    if (userId == null) return const [];
    return _isar.weightLogCaches
        .filter()
        .userIdEqualTo(userId)
        .timestampBetween(from, to, includeUpper: false)
        .sortByTimestampDesc()
        .findAll();
  }

  Future<WeightLogCache?> latest() async {
    final userId = _userId;
    if (userId == null) return null;
    return _isar.weightLogCaches
        .filter()
        .userIdEqualTo(userId)
        .sortByTimestampDesc()
        .findFirst();
  }

  /// Whether an entry already exists at exactly [at] (imports).
  Future<bool> existsAt(DateTime at) async {
    final userId = _userId;
    if (userId == null) return false;
    return _isar.weightLogCaches
        .filter()
        .userIdEqualTo(userId)
        .timestampEqualTo(at)
        .isNotEmpty();
  }

  /// Goal weight from onboarding / goal setup. Cache-first, so drawing the
  /// chart doesn't cost a request each time; works offline.
  Future<double?> targetKg() async {
    final userId = _userId;
    if (userId != null) {
      try {
        final kg = await _cache.fetch<double?>(
          targetCacheKey(userId),
          remote: () async {
            final row = await _client
                .from('user_health_data')
                .select('target_weight, target_weight_unit')
                .eq('id', userId)
                .maybeSingle();
            final value = (row?['target_weight'] as num?)?.toDouble();
            if (value == null || value <= 0) return null;
            return WeightUnit.fromCode(
              row?['target_weight_unit'] as String?,
            ).toKg(value);
          },
          maxAge: _targetMaxAge,
          decode: (json) => (json as num?)?.toDouble(),
        );
        if (kg != null) return kg;
      } catch (e) {
        debugPrint('Target weight unavailable: $e');
      }
    }
    return _prefs.getDouble(_keyTargetKg);
  }

  /// Saves the goal weight: cached right away (so charts update offline)
  /// and written to the profile, queued when offline.
  Future<void> setTargetKg(double kg) async {
    await _prefs.setDouble(_keyTargetKg, kg);
    final userId = _userId;
    if (userId == null) return;
    await _cache.write(targetCacheKey(userId), kg);
    try {
      await _pendingWrites.sendOrQueue(
        _client,
        PendingWrite.update(
          'user_health_data',
          values: {
            'target_weight': double.parse(kg.toStringAsFixed(1)),
            'target_weight_unit': WeightUnit.kg.label,
          },
          match: {'id': userId},
          userId: userId,
          key: 'health:target_weight:$userId',
        ),
      );
    } catch (e) {
      debugPrint('Goal weight not synced: $e');
    }
  }

  /// Last weight of each day over [range] days, vs the goal weight.
  Future<TrendData<WeightLogCache>> trend(TrendRange range) async {
    final days = lastNDays(range.days);
    final logs = await between(days.first, nextDay(days.last));
    final byDay = <DateTime, double>{};
    // Newest first, so the first entry seen for a day is its last one.
    for (final log in logs) {
      byDay.putIfAbsent(startOfDay(log.timestamp), () => log.weightKg);
    }
    final series = TrendSeries(
      [for (final day in days) DailyPoint(day, byDay[day])],
      goal: await targetKg(),
      direction: GoalDirection.near,
    );
    return TrendData(series, logs);
  }

  /// Keeps the profile's weight (used for calorie targets) current, in the
  /// unit the profile already uses (from the cached profile, else Settings).
  /// One write, queued when offline, and mirrored into the cached profile.
  Future<void> _updateProfileWeight(double kg) async {
    final userId = _userId;
    if (userId == null) return;
    try {
      final key = ProfileCache.key(userId);
      final cached = (await _cache.read<Object?>(key))?.value;
      final profileUnit = cached is Map ? cached['weight_unit'] : null;
      final unit = profileUnit is String && profileUnit.isNotEmpty
          ? WeightUnit.fromCode(profileUnit)
          : await this.unit();
      final values = <String, dynamic>{
        'weight': unit.fromKg(kg).toStringAsFixed(1),
        // Unit unknown locally: say which one the number is in.
        if (profileUnit is! String || profileUnit.isEmpty)
          'weight_unit': unit.label,
      };
      await _cache.update(key, (data) => ProfileCache.patch(data, values));
      await _pendingWrites.sendOrQueue(
        _client,
        PendingWrite.update(
          'user_health_data',
          values: values,
          match: {'id': userId},
          userId: userId,
          // Not the profile's upsert key: an update would replace it.
          key: 'health:weight:$userId',
        ),
      );
    } catch (e) {
      debugPrint('Profile weight not updated: $e');
    }
  }
}
