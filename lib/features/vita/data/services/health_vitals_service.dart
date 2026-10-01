import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/features/vita/domain/entities/health_snapshot.dart';

/// Reads wearable data (heart rate, resting HR, HRV, SpO2, blood pressure,
/// steps, sleep) from Health Connect / Apple Health for Vita.
///
/// Reads never prompt: they only use permissions the user already granted.
/// Permission is requested solely through [connect], from an explicit
/// "Connect watch data" tap.
class HealthVitalsService {
  final SharedPreferences _prefs;
  final Health _health = Health();

  static const _connectedKey = 'vita_wearable_connected';

  HealthVitalsService(this._prefs);

  static List<HealthDataType> get _vitalTypes => [
        HealthDataType.HEART_RATE,
        HealthDataType.RESTING_HEART_RATE,
        Platform.isIOS
            ? HealthDataType.HEART_RATE_VARIABILITY_SDNN
            : HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
        HealthDataType.BLOOD_OXYGEN,
        HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
        HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
        HealthDataType.STEPS,
      ];

  static const _sleepTypes = [
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_IN_BED,
  ];

  bool get _supported => Platform.isAndroid || Platform.isIOS;

  /// Whether the platform health store can be used at all.
  Future<bool> isAvailable() async {
    if (!_supported) return false;
    if (!Platform.isAndroid) return true;
    try {
      final status = await _health.getHealthConnectSdkStatus();
      return status == HealthConnectSdkStatus.sdkAvailable;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isConnected() async =>
      _prefs.getBool(_connectedKey) == true && await isAvailable();

  /// Asks for read access to the heart / step types. Returns true if granted.
  Future<bool> connect() async {
    if (!await isAvailable()) return false;
    try {
      final types = _vitalTypes;
      final granted = await _health.requestAuthorization(
        types,
        permissions: List.filled(types.length, HealthDataAccess.READ),
      );
      await _prefs.setBool(_connectedKey, granted);
      return granted;
    } catch (e) {
      debugPrint('Vita wearable connect failed: $e');
      return false;
    }
  }

  /// True when reading [type] won't prompt. iOS never reveals read access
  /// (returns null), so there we rely on the user having tapped connect.
  Future<bool> _canRead(HealthDataType type, {bool connected = false}) async {
    try {
      final granted = await _health.hasPermissions(
        [type],
        permissions: const [HealthDataAccess.READ],
      );
      return granted ?? connected;
    } catch (_) {
      return false;
    }
  }

  Future<List<HealthDataPoint>> _read(
    HealthDataType type,
    DateTime from,
    DateTime to,
    bool connected,
  ) async {
    if (!await _canRead(type, connected: connected)) return const [];
    try {
      final points = await _health.getHealthDataFromTypes(
        types: [type],
        startTime: from,
        endTime: to,
      );
      return _health.removeDuplicates(points);
    } catch (e) {
      debugPrint('Vita read $type failed: $e');
      return const [];
    }
  }

  /// Wearable vitals for today with the user's own 7-day baselines.
  Future<VitalsSnapshot> readVitals() async {
    if (!await isAvailable()) return const VitalsSnapshot();
    final connected = await isConnected();
    final now = DateTime.now();
    final dayAgo = now.subtract(const Duration(hours: 24));
    final weekAgo = now.subtract(const Duration(days: 8));
    final monthAgo = now.subtract(const Duration(days: 30));
    final types = _vitalTypes;

    final results = await Future.wait([
      _read(types[0], dayAgo, now, connected), // heart rate
      _read(types[1], weekAgo, now, connected), // resting HR
      _read(types[2], weekAgo, now, connected), // HRV
      _read(types[3], weekAgo, now, connected), // SpO2
      _read(types[4], monthAgo, now, connected), // systolic
      _read(types[5], monthAgo, now, connected), // diastolic
    ]);

    final (rhrToday, rhrBaseline) = _todayVsBaseline(results[1], dayAgo);
    final (hrvToday, hrvBaseline) = _todayVsBaseline(results[2], dayAgo);
    final spo2 = _latest(results[3]);
    final systolic = _latest(results[4]);
    final diastolic = _latest(results[5]);

    return VitalsSnapshot(
      connected: connected || results.any((r) => r.isNotEmpty),
      avgHeartRate: _average(results[0])?.round(),
      restingHeartRate: rhrToday?.round(),
      restingHeartRateBaseline: rhrBaseline?.round(),
      hrvMs: hrvToday,
      hrvBaselineMs: hrvBaseline,
      // Some sources report SpO2 as a 0–1 fraction.
      spo2Percent: spo2 == null ? null : (spo2 <= 1 ? spo2 * 100 : spo2).round(),
      systolic: systolic?.round(),
      diastolic: diastolic?.round(),
    );
  }

  /// Step totals for each local day in [days] (keyed by day start), or null
  /// when Health Connect / HealthKit isn't available or steps aren't allowed.
  Future<Map<DateTime, int>?> readDailySteps(List<DateTime> days) async {
    if (days.isEmpty || !await isAvailable()) return null;
    final connected = await isConnected();
    if (!await _canRead(HealthDataType.STEPS, connected: connected)) return null;
    final now = DateTime.now();
    try {
      final totals = await Future.wait([
        for (final day in days)
          _health.getTotalStepsInInterval(
            day,
            DateTime(day.year, day.month, day.day + 1).isAfter(now)
                ? now
                : DateTime(day.year, day.month, day.day + 1),
          ),
      ]);
      return {
        for (var i = 0; i < days.length; i++) days[i]: totals[i] ?? 0,
      };
    } catch (e) {
      debugPrint('Daily steps unavailable: $e');
      return null;
    }
  }

  Future<int?> readStepsToday() async {
    if (!await isAvailable()) return null;
    final connected = await isConnected();
    if (!await _canRead(HealthDataType.STEPS, connected: connected)) return null;
    final now = DateTime.now();
    try {
      final steps = await _health.getTotalStepsInInterval(
        DateTime(now.year, now.month, now.day),
        now,
      );
      return (steps ?? 0) > 0 ? steps : null;
    } catch (_) {
      return null;
    }
  }

  /// Hours asleep in the last 24h, only if sleep access was already granted
  /// (the dashboard sleep card asks for it).
  Future<double?> readSleepLastNightHours() async {
    if (!await isAvailable()) return null;
    final now = DateTime.now();
    final from = now.subtract(const Duration(hours: 24));
    for (final type in _sleepTypes) {
      final points = await _read(type, from, now, false);
      if (points.isEmpty) continue;
      final minutes = points.fold<int>(
        0,
        (sum, p) => sum + p.dateTo.difference(p.dateFrom).inMinutes,
      );
      if (minutes > 0) return minutes / 60;
    }
    return null;
  }

  static double? _value(HealthDataPoint p) {
    final v = p.value;
    return v is NumericHealthValue ? v.numericValue.toDouble() : null;
  }

  static double? _average(List<HealthDataPoint> points) {
    final values = points.map(_value).whereType<double>().toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  static double? _latest(List<HealthDataPoint> points) {
    if (points.isEmpty) return null;
    final sorted = [...points]..sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
    return _value(sorted.first);
  }

  /// Average of the last 24h vs. the average of the days before it.
  static (double?, double?) _todayVsBaseline(
    List<HealthDataPoint> points,
    DateTime cutoff,
  ) {
    final today = points.where((p) => !p.dateFrom.isBefore(cutoff)).toList();
    final before = points.where((p) => p.dateFrom.isBefore(cutoff)).toList();
    return (_average(today), _average(before));
  }
}
