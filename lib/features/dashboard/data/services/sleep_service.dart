import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:health/health.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/utils/date_range_utils.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import 'package:vital_up/features/dashboard/domain/tracker_input_rules.dart';
import '../../../../core/database/isar_service.dart';
import '../../../../core/database/collections/sleep_log_cache.dart';
import '../../../../core/events/habit_events.dart';
import '../../../../core/sync/sync_hooks.dart';
import '../../../reminders/data/reminder_scheduler.dart';
import '../../domain/entities/sleep_session_info.dart';
import '../../domain/sleep_detection.dart';
import 'sleep_bedtime.dart' as bedtime;

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

  /// Shows / clears the in-bed notification.
  final FlutterLocalNotificationsPlugin? _notifications;

  /// Told when last night is logged, so morning sleep reminders go quiet.
  final HabitEvents? _events;
  late final Health _health;

  final _changes = StreamController<void>.broadcast();

  /// Fires when a night is saved or a bedtime is set or cleared.
  Stream<void> get changes => _changes.stream;

  static const _goalKey = 'daily_sleep_goal_min';
  static const defaultGoalMinutes = 480;

  /// Manual logs written before entries were tied to the signed-in user.
  static const _legacyUserId = 'current_user';

  /// Shared with `ScreenTimeService`; also serves screen on/off events.
  static const _usageChannel = MethodChannel(
    'com.example.vital_up/usage_stats',
  );

  static const _allSleepTypes = [
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_IN_BED,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_AWAKE,
  ];

  static const _stageOf = {
    HealthDataType.SLEEP_ASLEEP: SleepStage.asleep,
    HealthDataType.SLEEP_IN_BED: SleepStage.inBed,
    HealthDataType.SLEEP_DEEP: SleepStage.deep,
    HealthDataType.SLEEP_REM: SleepStage.rem,
    HealthDataType.SLEEP_LIGHT: SleepStage.light,
    HealthDataType.SLEEP_AWAKE: SleepStage.awake,
  };

  SleepService(
    this._isarService,
    this._prefs, [
    this._sync,
    this._notifications,
    this._events,
  ]) {
    _health = Health();
  }

  String get _userId =>
      Supabase.instance.client.auth.currentUser?.id ?? _legacyUserId;

  /// Nightly goal; the default when unset or out of range.
  int getGoalMinutes() =>
      sanitizeSleepGoal(_prefs.getInt(_goalKey), fallback: defaultGoalMinutes);

  Future<void> setGoalMinutes(int minutes) => _prefs.setInt(
    _goalKey,
    minutes.clamp(InputLimits.sleepGoalMinMin, InputLimits.sleepGoalMinMax),
  );

  /// Sleep sessions that ended in [from, to), newest first. Health Connect
  /// nights win over saved entries for the same wake-up day.
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
        source: _sourceOf(log.source),
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
          final night = buildHealthNight([
            for (final p in entry.value)
              if (_stageOf[p.type] case final stage?)
                SleepSample(stage, p.dateFrom, p.dateTo),
          ]);
          if (night != null) byDay[entry.key] = night;
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

    for (final s in sessions) {
      totalMinutes += s.duration.inMinutes;
      totalScore += s.sleepScore;
      final diff = goalMinutes - s.duration.inMinutes;
      if (diff > 0) debtMinutes += diff;
    }

    return SleepStats(
      averageScore: (totalScore / sessions.length).round(),
      averageDuration: Duration(minutes: totalMinutes ~/ sessions.length),
      totalSleepDebt: Duration(minutes: debtMinutes),
      consistencyScore: bedtimeConsistency([
        for (final s in sessions) s.bedTime,
      ]),
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

  /// Whether sleep can be read; asks for access unless [request] is false.
  Future<bool> hasPermission({bool request = true}) async {
    final permissions = List.filled(_allSleepTypes.length, HealthDataAccess.READ);
    bool? hasPermissions = await _health
        .hasPermissions(_allSleepTypes, permissions: permissions)
        .orFallback(null);
    if (!request) return hasPermissions ?? false;
    if (hasPermissions == null || !hasPermissions) {
      try {
        hasPermissions = await _health.requestAuthorization(_allSleepTypes, permissions: permissions);
      } catch (e) {
        return false;
      }
    }
    return hasPermissions;
  }

  /// The night that ended today (before 4 am, the one that ended
  /// yesterday): Health Connect / HealthKit first, else a saved entry.
  /// Pass [requestPermission] false where a permission screen would be
  /// unexpected (e.g. home screen widget refreshes, app resume).
  Future<SleepSessionInfo?> getSleepDataForLastNight({
    bool requestPermission = true,
  }) async {
    if (requestPermission) {
      try {
        await hasPermission();
      } catch (e) {
        debugPrint('Sleep permission request failed: $e');
      }
    }
    final now = DateTime.now();
    final today = startOfDay(now);
    // Calendar maths, not 24h steps, so DST days keep their boundaries.
    final from = now.hour < 4
        ? DateTime(today.year, today.month, today.day - 1)
        : today;
    final nights = await getSleepBetween(from, nextDay(today));
    return nights.firstOrNull;
  }

  /// Whether nights can be estimated from screen activity (Android with
  /// usage access granted).
  Future<bool> canEstimateFromPhone() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _usageChannel.invokeMethod<bool>(
            'checkUsageStatsPermission',
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Last night guessed from when the screen was off, for the user to
  /// confirm. Null off Android, without usage access, or when nothing
  /// looks like a night yet.
  Future<SleepSessionInfo?> estimateLastNight() async {
    if (!Platform.isAndroid) return null;
    final now = DateTime.now();
    final today = startOfDay(now);
    try {
      final raw = await _usageChannel.invokeListMethod<Map>('getScreenEvents', {
        'start': today.subtract(const Duration(hours: 8)).millisecondsSinceEpoch,
        'end': now.millisecondsSinceEpoch,
      });
      final events = [
        for (final e in raw ?? const <Map>[])
          ScreenEvent(
            DateTime.fromMillisecondsSinceEpoch((e['t'] as num).toInt()),
            on: e['on'] == true,
          ),
      ];
      return estimateSleepFromScreen(events, wakeDay: today);
    } catch (e) {
      debugPrint('Sleep estimate from screen activity unavailable: $e');
      return null;
    }
  }

  /// The "Going to bed" time still waiting for "I'm up", if any. Re-reads
  /// storage since a notification action may have set it in the background.
  Future<DateTime?> pendingBedtime() async {
    await _prefs.reload();
    return bedtime.readBedtime(_prefs, _userId, DateTime.now());
  }

  /// "Going to bed": remembers now and shows the in-bed notification.
  Future<void> markBedtime() async {
    final now = DateTime.now();
    await bedtime.writeBedtime(_prefs, _userId, now);
    if (_notifications case final plugin?) {
      await ReminderScheduler.showInBed(plugin, since: now, userId: _userId);
    }
    _changes.add(null);
  }

  /// Drops a bedtime tapped by mistake.
  Future<void> cancelBedtime() async {
    await _clearBedtime();
    _changes.add(null);
  }

  /// "I'm up": saves the night from the pending bedtime until now.
  Future<SleepSessionInfo?> wakeUp() async {
    final bed = await pendingBedtime();
    if (bed == null) return null;
    final now = DateTime.now();
    if (now.difference(bed) < bedtime.minTimeInBed) {
      await cancelBedtime();
      return null;
    }
    return saveManualEntry(bed, now);
  }

  Future<void> _clearBedtime() async {
    await bedtime.clearBedtime(_prefs, _userId);
    if (_notifications case final plugin?) {
      await ReminderScheduler.cancelInBed(plugin);
    }
  }

  static SleepDataSource _sourceOf(String source) =>
      source == 'phone' ? SleepDataSource.phone : SleepDataSource.manual;

  /// Saves a night the user entered, or confirmed from a phone estimate
  /// when [source] is [SleepDataSource.phone]. [asleep] defaults to the
  /// whole bed-to-wake span.
  Future<SleepSessionInfo> saveManualEntry(
    DateTime bedTime,
    DateTime wakeTime, {
    SleepDataSource source = SleepDataSource.manual,
    Duration? asleep,
  }) async {
    if (wakeTime.isBefore(bedTime)) {
      wakeTime = wakeTime.add(const Duration(days: 1));
    }
    if (!wakeTime.isAfter(bedTime)) {
      throw ArgumentError('Wake-up time must be after bedtime');
    }

    var duration = asleep ?? wakeTime.difference(bedTime);
    if (duration.isNegative) duration = Duration.zero;

    final log = SleepLogCache()
      ..userId = _userId
      ..startTime = bedTime
      ..endTime = wakeTime
      ..durationMinutes = duration.inMinutes
      ..source = source == SleepDataSource.phone ? 'phone' : 'manual'
      ..isSynced = false;

    await _isarService.isar.writeTxn(() async {
      await _isarService.isar.sleepLogCaches.put(log);
    });
    _sync?.schedule();

    // This night closes an open "Going to bed".
    final now = DateTime.now();
    final bed = bedtime.readBedtime(_prefs, _userId, now);
    if (bed != null && !bed.isAfter(wakeTime)) await _clearBedtime();
    if (isSameDay(wakeTime, now)) {
      _events?.logged(const HabitLogged(Habit.sleep));
    }
    _changes.add(null);

    return SleepSessionInfo(
      bedTime: bedTime,
      wakeTime: wakeTime,
      duration: duration,
      source: source,
    );
  }
}
