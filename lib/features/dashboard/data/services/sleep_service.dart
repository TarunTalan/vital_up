import 'dart:io';
import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/utils/date_range_utils.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import '../../../../core/database/isar_service.dart';
import '../../../../core/database/collections/sleep_log_cache.dart';
import '../../../../core/sync/sync_hooks.dart';
import '../../domain/entities/sleep_session_info.dart';

class SleepStats {
  final int averageScore;
  final Duration averageDuration;
  final Duration totalSleepDebt;
  final int consistencyScore; // 0 - 100%
  final int nightsLogged;

  const SleepStats({
    required this.averageScore,
    required this.averageDuration,
    required this.totalSleepDebt,
    required this.consistencyScore,
    required this.nightsLogged,
  });
}

class SleepService {
  final IsarService _isarService;
  final SharedPreferences _prefs;
  final SyncHooks? _sync;
  late final Health _health;

  static const _goalKey = 'daily_sleep_goal_min';
  static const defaultGoalMinutes = 480;

  /// Manual logs written before entries were tied to the signed-in user.
  static const _legacyUserId = 'current_user';

  static const _allSleepTypes = [
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_IN_BED,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_AWAKE,
  ];

  SleepService(this._isarService, this._prefs, [this._sync]) {
    _health = Health();
  }

  String get _userId =>
      Supabase.instance.client.auth.currentUser?.id ?? _legacyUserId;

  int getGoalMinutes() => _prefs.getInt(_goalKey) ?? defaultGoalMinutes;

  Future<void> setGoalMinutes(int minutes) => _prefs.setInt(_goalKey, minutes);

  /// Sleep sessions that ended in [from, to), newest first. Health Connect
  /// nights win over manual entries for the same wake-up day.
  Future<List<SleepSessionInfo>> getSleepBetween(
    DateTime from,
    DateTime to,
  ) async {
    final byDay = <DateTime, SleepSessionInfo>{};

    final manual = await _isarService.isar.sleepLogCaches
        .filter()
        .group((q) => q.userIdEqualTo(_userId).or().userIdEqualTo(_legacyUserId))
        .endTimeBetween(from, to, includeUpper: false)
        .sortByEndTime()
        .findAll();
    for (final log in manual) {
      // Later entries for the same night replace earlier ones (edits).
      byDay[startOfDay(log.endTime)] = SleepSessionInfo(
        bedTime: log.startTime,
        wakeTime: log.endTime,
        duration: Duration(minutes: log.durationMinutes),
        source: SleepDataSource.manual,
      );
    }

    try {
      final permissions = List.filled(_allSleepTypes.length, HealthDataAccess.READ);
      if (await _health
              .hasPermissions(_allSleepTypes, permissions: permissions)
              .orFallback(null) ==
          true) {
        final points = _health.removeDuplicates(
          await _health
              .getHealthDataFromTypes(
                startTime: from.subtract(const Duration(hours: 12)),
                endTime: to,
                types: _allSleepTypes,
              )
              .orFallback(const []),
        );
        final nights = bucketByDay(points, (p) => p.dateTo);
        for (final entry in nights.entries) {
          if (entry.key.isBefore(startOfDay(from)) || !entry.key.isBefore(to)) {
            continue;
          }

          var totalMinutes = 0;
          var deepMin = 0;
          var remMin = 0;
          var lightMin = 0;
          var awakeMin = 0;

          var bed = entry.value.first.dateFrom;
          var wake = entry.value.first.dateTo;

          for (final p in entry.value) {
            final diff = p.dateTo.difference(p.dateFrom).inMinutes;
            if (p.dateFrom.isBefore(bed)) bed = p.dateFrom;
            if (p.dateTo.isAfter(wake)) wake = p.dateTo;

            switch (p.type) {
              case HealthDataType.SLEEP_DEEP:
                deepMin += diff;
                totalMinutes += diff;
                break;
              case HealthDataType.SLEEP_REM:
                remMin += diff;
                totalMinutes += diff;
                break;
              case HealthDataType.SLEEP_LIGHT:
                lightMin += diff;
                totalMinutes += diff;
                break;
              case HealthDataType.SLEEP_AWAKE:
                awakeMin += diff;
                break;
              case HealthDataType.SLEEP_ASLEEP:
                if (deepMin == 0 && remMin == 0 && lightMin == 0) {
                  totalMinutes += diff;
                }
                break;
              case HealthDataType.SLEEP_IN_BED:
                if (totalMinutes == 0) {
                  totalMinutes += diff;
                }
                break;
              default:
                break;
            }
          }

          if (totalMinutes == 0) {
            totalMinutes = wake.difference(bed).inMinutes;
          }

          byDay[entry.key] = SleepSessionInfo(
            bedTime: bed,
            wakeTime: wake,
            duration: Duration(minutes: totalMinutes),
            source: SleepDataSource.healthStore,
            deepSleepMinutes: deepMin > 0 ? deepMin : null,
            remSleepMinutes: remMin > 0 ? remMin : null,
            lightSleepMinutes: lightMin > 0 ? lightMin : null,
            awakeMinutes: awakeMin > 0 ? awakeMin : null,
          );
        }
      }
    } catch (e) {
      debugPrint('Sleep history from Health Connect unavailable: $e');
    }

    return byDay.values.toList()
      ..sort((a, b) => b.wakeTime.compareTo(a.wakeTime));
  }

  /// Calculates weekly sleep statistics including sleep debt and consistency
  Future<SleepStats> getWeeklyStats() async {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final sessions = await getSleepBetween(sevenDaysAgo, now);

    if (sessions.isEmpty) {
      return const SleepStats(
        averageScore: 0,
        averageDuration: Duration.zero,
        totalSleepDebt: Duration.zero,
        consistencyScore: 100,
        nightsLogged: 0,
      );
    }

    final goalMinutes = getGoalMinutes();
    var totalMinutes = 0;
    var totalScore = 0;
    var debtMinutes = 0;
    final bedMinutesList = <int>[];

    for (final s in sessions) {
      totalMinutes += s.duration.inMinutes;
      totalScore += s.sleepScore;
      final diff = goalMinutes - s.duration.inMinutes;
      if (diff > 0) debtMinutes += diff;

      // Bedtime in minutes from midnight (treating 20:00 - 24:00 as negative / offset)
      var bedM = s.bedTime.hour * 60 + s.bedTime.minute;
      if (bedM > 12 * 60) bedM -= 24 * 60; // 23:00 -> -60
      bedMinutesList.add(bedM);
    }

    final avgMin = totalMinutes ~/ sessions.length;
    final avgScore = (totalScore / sessions.length).round();

    // Bedtime consistency: standard deviation of bedtimes
    int consistency = 90;
    if (bedMinutesList.length > 1) {
      final mean = bedMinutesList.reduce((a, b) => a + b) / bedMinutesList.length;
      final variance = bedMinutesList
              .map((x) => (x - mean) * (x - mean))
              .reduce((a, b) => a + b) /
          bedMinutesList.length;
      final stdDev = variance > 0 ? (variance) : 0;
      // stdDev in minutes: < 30min -> 95%, 60min -> 80%, > 120min -> 50%
      consistency = (100 - (stdDev / 3)).round().clamp(40, 100);
    }

    return SleepStats(
      averageScore: avgScore,
      averageDuration: Duration(minutes: avgMin),
      totalSleepDebt: Duration(minutes: debtMinutes),
      consistencyScore: consistency,
      nightsLogged: sessions.length,
    );
  }

  Future<HealthConnectSdkStatus?> getHealthConnectStatus() async {
    if (Platform.isAndroid) {
      return await _health.getHealthConnectSdkStatus().orFallback(null);
    }
    return null;
  }
  
  Future<void> installHealthConnect() async {
     if (Platform.isAndroid) {
       await _health.installHealthConnect();
     }
  }

  Future<bool> hasPermission() async {
    final permissions = List.filled(_allSleepTypes.length, HealthDataAccess.READ);
    bool? hasPermissions = await _health
        .hasPermissions(_allSleepTypes, permissions: permissions)
        .orFallback(null);
    if (hasPermissions == null || !hasPermissions) {
      try {
        hasPermissions = await _health.requestAuthorization(_allSleepTypes, permissions: permissions);
      } catch (e) {
        return false;
      }
    }
    return hasPermissions;
  }

  Future<SleepSessionInfo?> getSleepDataForLastNight() async {
    try {
      if (await hasPermission()) {
        final now = DateTime.now();
        // Query last 24 hours
        final yesterday = now.subtract(const Duration(hours: 24));
        
        List<HealthDataPoint> healthData = await _health
            .getHealthDataFromTypes(
              startTime: yesterday,
              endTime: now,
              types: _allSleepTypes,
            )
            .orFallback(const []);

        if (healthData.isNotEmpty) {
          healthData = Health().removeDuplicates(healthData);
          
          if (healthData.isEmpty) return null;
          
          DateTime earliestBedTime = now;
          DateTime latestWakeTime = yesterday;
          int deepMin = 0;
          int remMin = 0;
          int lightMin = 0;
          int awakeMin = 0;
          int totalMin = 0;

          for (var point in healthData) {
            if (point.dateFrom.isBefore(earliestBedTime)) {
              earliestBedTime = point.dateFrom;
            }
            if (point.dateTo.isAfter(latestWakeTime)) {
              latestWakeTime = point.dateTo;
            }
            
            final diff = point.dateTo.difference(point.dateFrom).inMinutes;
            switch (point.type) {
              case HealthDataType.SLEEP_DEEP:
                deepMin += diff;
                totalMin += diff;
                break;
              case HealthDataType.SLEEP_REM:
                remMin += diff;
                totalMin += diff;
                break;
              case HealthDataType.SLEEP_LIGHT:
                lightMin += diff;
                totalMin += diff;
                break;
              case HealthDataType.SLEEP_AWAKE:
                awakeMin += diff;
                break;
              case HealthDataType.SLEEP_ASLEEP:
                if (deepMin == 0 && remMin == 0 && lightMin == 0) {
                  totalMin += diff;
                }
                break;
              default:
                break;
            }
          }

          if (totalMin == 0) {
            totalMin = latestWakeTime.difference(earliestBedTime).inMinutes;
          }

          return SleepSessionInfo(
            bedTime: earliestBedTime,
            wakeTime: latestWakeTime,
            duration: Duration(minutes: totalMin),
            source: SleepDataSource.healthStore,
            deepSleepMinutes: deepMin > 0 ? deepMin : null,
            remSleepMinutes: remMin > 0 ? remMin : null,
            lightSleepMinutes: lightMin > 0 ? lightMin : null,
            awakeMinutes: awakeMin > 0 ? awakeMin : null,
          );
        }
      }
    } catch (e) {
      debugPrint("Error fetching health sleep data: $e");
    }
    
    // Fallback to manual entry from Isar
    return _getManualSleepData();
  }

  Future<SleepSessionInfo?> _getManualSleepData() async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(hours: 24));
    
    final logs = await _isarService.isar.sleepLogCaches
        .filter()
        .group((q) => q.userIdEqualTo(_userId).or().userIdEqualTo(_legacyUserId))
        .startTimeGreaterThan(yesterday)
        .sortByStartTimeDesc()
        .findAll();
        
    if (logs.isNotEmpty) {
      final log = logs.first;
      return SleepSessionInfo(
        bedTime: log.startTime,
        wakeTime: log.endTime,
        duration: Duration(minutes: log.durationMinutes),
        source: SleepDataSource.manual,
      );
    }
    
    return null;
  }

  Future<SleepSessionInfo> saveManualEntry(DateTime bedTime, DateTime wakeTime) async {
    if (wakeTime.isBefore(bedTime)) {
      wakeTime = wakeTime.add(const Duration(days: 1));
    }
    
    final duration = wakeTime.difference(bedTime);
    
    final log = SleepLogCache()
      ..userId = _userId
      ..startTime = bedTime
      ..endTime = wakeTime
      ..durationMinutes = duration.inMinutes
      ..source = 'manual'
      ..isSynced = false;
      
    await _isarService.isar.writeTxn(() async {
      await _isarService.isar.sleepLogCaches.put(log);
    });
    _sync?.schedule();
    
    return SleepSessionInfo(
      bedTime: bedTime,
      wakeTime: wakeTime,
      duration: duration,
      source: SleepDataSource.manual,
    );
  }
}
