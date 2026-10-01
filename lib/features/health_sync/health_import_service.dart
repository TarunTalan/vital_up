import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/activity_repository.dart';
import 'package:vital_up/features/settings/domain/repositories/settings_repository.dart';
import 'package:vital_up/features/weight/data/weight_service.dart';

/// Brings weight entries and workouts from Health Connect / Apple Health
/// into VitalUp, so people with a smart scale or watch don't log twice.
///
/// Runs only while Settings > Health Sync is on: when it's turned on, when
/// the home screen opens and when the app returns to the foreground (at
/// most hourly). Imports are idempotent: workouts keep the health store's
/// id, weights are matched by time.
class HealthImportService {
  final SettingsRepository _settings;
  final WeightService _weight;
  final ActivityRepository _activity;
  final SharedPreferences _prefs;
  final Health _health;

  HealthImportService(
    this._settings,
    this._weight,
    this._activity,
    this._prefs, {
    Health? health,
  }) : _health = health ?? Health();

  static const _keyLastImport = 'health_import_last';
  static const _firstImport = Duration(days: 30);
  static const _minInterval = Duration(hours: 1);

  static const types = [HealthDataType.WEIGHT, HealthDataType.WORKOUT];

  /// Workout id prefix, so imported sessions are recognisable.
  static const idPrefix = 'health_';

  AppLifecycleListener? _lifecycle;
  Future<int>? _running;

  bool get _supported => Platform.isAndroid || Platform.isIOS;

  /// Imports now and on every return to the foreground. Call once the
  /// user is signed in (home screen).
  void start() {
    _lifecycle ??= AppLifecycleListener(onResume: importIfEnabled);
    importIfEnabled();
  }

  /// Health Sync switched on: asks for access, then imports. Returns false
  /// if access wasn't granted.
  Future<bool> connect() async {
    if (!_supported) return false;
    try {
      if (Platform.isAndroid &&
          await _health.getHealthConnectSdkStatus() !=
              HealthConnectSdkStatus.sdkAvailable) {
        return false;
      }
      final granted = await _health.requestAuthorization(
        types,
        permissions: List.filled(types.length, HealthDataAccess.READ),
      );
      if (granted) await import(force: true);
      return granted;
    } catch (e) {
      debugPrint('Health Sync connect failed: $e');
      return false;
    }
  }

  Future<void> importIfEnabled() async {
    final result = await _settings.getSettings();
    final enabled = result.fold((_) => false, (s) => s.healthSyncEnabled);
    if (enabled) await import();
  }

  /// Imports what's new since the last run. Returns the number of entries
  /// added. Never throws.
  Future<int> import({bool force = false}) =>
      _running ??= _import(force).whenComplete(() => _running = null);

  Future<int> _import(bool force) async {
    if (!_supported) return 0;
    final now = DateTime.now();
    final last = DateTime.tryParse(_prefs.getString(_keyLastImport) ?? '');
    if (!force && last != null && now.difference(last) < _minInterval) {
      return 0;
    }
    // Overlap a day so late-syncing devices (watches) aren't missed.
    final from = last == null
        ? now.subtract(_firstImport)
        : last.subtract(const Duration(days: 1));
    var added = 0;
    try {
      final points = _health.removeDuplicates(
        await _health.getHealthDataFromTypes(
          types: types,
          startTime: from,
          endTime: now,
        ),
      );
      for (final p in points) {
        if (await _importPoint(p)) added++;
      }
      await _prefs.setString(_keyLastImport, now.toIso8601String());
    } catch (e) {
      debugPrint('Health import failed: $e');
    }
    return added;
  }

  Future<bool> _importPoint(HealthDataPoint p) async {
    final value = p.value;
    if (p.type == HealthDataType.WEIGHT && value is NumericHealthValue) {
      final kg = value.numericValue.toDouble();
      if (await _weight.existsAt(p.dateFrom)) return false;
      return await _weight.add(kg, at: p.dateFrom, source: 'health') == null;
    }
    if (p.type == HealthDataType.WORKOUT && value is WorkoutHealthValue) {
      final session = workoutToSession(p.uuid, p.dateFrom, p.dateTo, value);
      if (session == null) return false;
      if (await _activity.getSessionById(session.id) != null) return false;
      await _activity.saveSession(session);
      return true;
    }
    return false;
  }

  /// A health-store workout as a VitalUp session, or null for workout types
  /// VitalUp doesn't track.
  static ActivitySession? workoutToSession(
    String uuid,
    DateTime start,
    DateTime end,
    WorkoutHealthValue w,
  ) {
    final type = switch (w.workoutActivityType) {
      HealthWorkoutActivityType.WALKING ||
      HealthWorkoutActivityType.WALKING_TREADMILL => ActivityType.walk,
      HealthWorkoutActivityType.RUNNING ||
      HealthWorkoutActivityType.RUNNING_TREADMILL => ActivityType.run,
      HealthWorkoutActivityType.BIKING ||
      HealthWorkoutActivityType.BIKING_STATIONARY => ActivityType.cycle,
      HealthWorkoutActivityType.HIKING => ActivityType.trekking,
      HealthWorkoutActivityType.CLIMBING ||
      HealthWorkoutActivityType.ROCK_CLIMBING => ActivityType.climbing,
      _ => null,
    };
    if (type == null) return null;
    final seconds = end.difference(start).inSeconds;
    if (seconds <= 0) return null;
    final meters = w.totalDistanceUnit == HealthDataUnit.MILE
        ? (w.totalDistance ?? 0) * 1609.344
        : (w.totalDistance ?? 0).toDouble();
    final kcal = w.totalEnergyBurnedUnit == HealthDataUnit.SMALL_CALORIE
        ? (w.totalEnergyBurned ?? 0) ~/ 1000
        : w.totalEnergyBurned ?? 0;
    return ActivitySession(
      id: '$idPrefix$uuid',
      activityType: type,
      startTime: start,
      endTime: end,
      totalDistanceMeters: meters,
      totalDurationSeconds: seconds,
      avgPaceSecondsPerKm: meters >= 10
          ? (seconds / (meters / 1000)).round()
          : 0,
      calories: kcal,
      steps: w.totalSteps ?? 0,
      stepCountReliable: w.totalSteps != null,
      points: const [],
    );
  }
}
