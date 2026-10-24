import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reads steps and sleep from Health Connect / Apple Health for Vita, the
/// activity goals and Arena.
///
/// Reads never prompt: they only use permissions the user already granted
/// (Settings > Health Sync asks for steps and sleep). Heart rate, HRV, SpO2
/// and blood pressure are not read: Play allows only data types a visible
/// feature shows.
class HealthVitalsService {
  final SharedPreferences _prefs;
  final Health _health = Health();

  /// Set by the old "Connect watch data" card. iOS never reveals read
  /// access, so it still counts as permission there.
  static const _connectedKey = 'vita_wearable_connected';

  HealthVitalsService(this._prefs);

  static final _sleepTypes = [
    HealthDataType.SLEEP_ASLEEP,
    if (Platform.isIOS) HealthDataType.SLEEP_IN_BED,
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

  /// True when reading [type] won't prompt. iOS never reveals read access
  /// (returns null), so there we rely on the user having connected before.
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

  /// Step totals for each local day in [days] (keyed by day start), or null
  /// when Health Connect / HealthKit isn't available or steps aren't allowed.
  Future<Map<DateTime, int>?> readDailySteps(List<DateTime> days) async {
    if (days.isEmpty || !await isAvailable()) return null;
    final connected = await isConnected();
    if (!await _canRead(HealthDataType.STEPS, connected: connected))
      return null;
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
      return {for (var i = 0; i < days.length; i++) days[i]: totals[i] ?? 0};
    } catch (e) {
      debugPrint('Daily steps unavailable: $e');
      return null;
    }
  }

  Future<int?> readStepsToday() async {
    if (!await isAvailable()) return null;
    final connected = await isConnected();
    if (!await _canRead(HealthDataType.STEPS, connected: connected))
      return null;
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
}
