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

class SleepService {
  final IsarService _isarService;
  final SharedPreferences _prefs;
  final SyncHooks? _sync;
  late final Health _health;

  static const _goalKey = 'daily_sleep_goal_min';
  static const defaultGoalMinutes = 480;

  /// Manual logs written before entries were tied to the signed-in user.
  static const _legacyUserId = 'current_user';

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
      final types = [HealthDataType.SLEEP_ASLEEP, HealthDataType.SLEEP_IN_BED];
      final permissions = [HealthDataAccess.READ, HealthDataAccess.READ];
      if (await _health
              .hasPermissions(types, permissions: permissions)
              .orFallback(null) ==
          true) {
        final points = _health.removeDuplicates(
          await _health
              .getHealthDataFromTypes(
                startTime: from.subtract(const Duration(hours: 12)),
                endTime: to,
                types: types,
              )
              .orFallback(const []),
        );
        final nights = bucketByDay(points, (p) => p.dateTo);
        for (final entry in nights.entries) {
          if (entry.key.isBefore(startOfDay(from)) || !entry.key.isBefore(to)) {
            continue;
          }
          // Prefer "asleep" samples; fall back to "in bed" when that's all
          // the source records.
          final asleep =
              entry.value.where((p) => p.type == HealthDataType.SLEEP_ASLEEP);
          final chosen = asleep.isNotEmpty ? asleep : entry.value;
          var total = Duration.zero;
          var bed = chosen.first.dateFrom;
          var wake = chosen.first.dateTo;
          for (final p in chosen) {
            total += p.dateTo.difference(p.dateFrom);
            if (p.dateFrom.isBefore(bed)) bed = p.dateFrom;
            if (p.dateTo.isAfter(wake)) wake = p.dateTo;
          }
          byDay[entry.key] = SleepSessionInfo(
            bedTime: bed,
            wakeTime: wake,
            duration: total,
            source: SleepDataSource.healthStore,
          );
        }
      }
    } catch (e) {
      debugPrint('Sleep history from Health Connect unavailable: $e');
    }

    return byDay.values.toList()
      ..sort((a, b) => b.wakeTime.compareTo(a.wakeTime));
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
    final types = [HealthDataType.SLEEP_ASLEEP, HealthDataType.SLEEP_IN_BED];
    final permissions = [HealthDataAccess.READ, HealthDataAccess.READ];
    bool? hasPermissions = await _health
        .hasPermissions(types, permissions: permissions)
        .orFallback(null);
    if (hasPermissions == null || !hasPermissions) {
      try {
        hasPermissions = await _health.requestAuthorization(types, permissions: permissions);
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
        
        final types = [HealthDataType.SLEEP_ASLEEP, HealthDataType.SLEEP_IN_BED];
        
        List<HealthDataPoint> healthData = await _health
            .getHealthDataFromTypes(
              startTime: yesterday,
              endTime: now,
              types: types,
            )
            .orFallback(const []);

        if (healthData.isNotEmpty) {
          // Filter to just sleep types and merge
          healthData = Health().removeDuplicates(healthData);
          
          if (healthData.isEmpty) return null;
          
          DateTime earliestBedTime = now;
          DateTime latestWakeTime = yesterday;
          Duration totalDuration = Duration.zero;

          for (var point in healthData) {
            if (point.dateFrom.isBefore(earliestBedTime)) {
              earliestBedTime = point.dateFrom;
            }
            if (point.dateTo.isAfter(latestWakeTime)) {
              latestWakeTime = point.dateTo;
            }
            
            // value is the duration in minutes for sleep, but we can also just use dateTo.difference(dateFrom)
            totalDuration += point.dateTo.difference(point.dateFrom);
          }

          return SleepSessionInfo(
            bedTime: earliestBedTime,
            wakeTime: latestWakeTime,
            duration: totalDuration,
            source: SleepDataSource.healthStore,
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
    // Handle midnight rollover if manual entry was entered without explicit dates (e.g., just time)
    // Assuming UI already gives us correct DateTimes. But just in case wakeTime < bedTime:
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
