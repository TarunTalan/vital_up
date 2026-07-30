import 'dart:io';
import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:isar_community/isar.dart';
import '../../../../core/database/isar_service.dart';
import '../../../../core/database/collections/sleep_log_cache.dart';
import '../../domain/entities/sleep_session_info.dart';

class SleepService {
  final IsarService _isarService;
  late final Health _health;

  SleepService(this._isarService) {
    _health = Health();
  }

  Future<HealthConnectSdkStatus?> getHealthConnectStatus() async {
    if (Platform.isAndroid) {
      return await _health.getHealthConnectSdkStatus();
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
    bool? hasPermissions = await _health.hasPermissions(types, permissions: permissions);
    if (hasPermissions == null || !hasPermissions) {
      try {
        hasPermissions = await _health.requestAuthorization(types, permissions: permissions);
      } catch (e) {
        return false;
      }
    }
    return hasPermissions ?? false;
  }

  Future<SleepSessionInfo?> getSleepDataForLastNight() async {
    try {
      if (await hasPermission()) {
        final now = DateTime.now();
        // Query last 24 hours
        final yesterday = now.subtract(const Duration(hours: 24));
        
        final types = [HealthDataType.SLEEP_ASLEEP, HealthDataType.SLEEP_IN_BED];
        
        List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
          startTime: yesterday,
          endTime: now,
          types: types,
        );

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
      ..userId = 'current_user' // In a real app, get from auth state
      ..startTime = bedTime
      ..endTime = wakeTime
      ..durationMinutes = duration.inMinutes
      ..source = 'manual'
      ..isSynced = false;
      
    await _isarService.isar.writeTxn(() async {
      await _isarService.isar.sleepLogCaches.put(log);
    });
    
    return SleepSessionInfo(
      bedTime: bedTime,
      wakeTime: wakeTime,
      duration: duration,
      source: SleepDataSource.manual,
    );
  }
}
