import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/utils/date_range_utils.dart';
import '../../domain/entities/app_usage_info.dart';
import '../../domain/entities/trend_series.dart';
import '../../domain/tracker_input_rules.dart';

class ScreenTimeService {
  final SharedPreferences? _prefs;

  ScreenTimeService([this._prefs]);

  static const _limitKey = 'daily_screen_time_limit_min';
  static const defaultLimitMinutes = 240;

  /// Daily screen time limit (the "goal" — less is better).
  int getDailyLimitMinutes() => sanitizeScreenLimit(
    _prefs?.getInt(_limitKey),
    fallback: defaultLimitMinutes,
  );

  Future<void> setDailyLimitMinutes(int minutes) async => _prefs?.setInt(
    _limitKey,
    minutes.clamp(screenLimitMinMinutes, screenLimitMaxMinutes),
  );

  static const MethodChannel _channel = MethodChannel(
    'com.example.vital_up/usage_stats',
  );

  // App Usage Filtering
  static const List<String> _ignoredPackages = [
    'launcher',
    'systemui',
    'incallui',
    'com.android.settings',
    'com.android.providers',
    'com.google.android.gms',
    'com.android.vending',
    'com.sec.android.app',
    'com.miui',
    'com.samsung.android',
    'com.google.android.permissioncontroller',
    'com.android.permissioncontroller',
    'com.google.android.setupwizard',
    'com.google.android.apps.wellbeing',
    'com.android.server.telecom',
    'com.google.android.as',
    'android.uid.system',
    'com.android.server',
  ];

  static const Map<String, String> _appNameMappings = {
    'com.whatsapp': 'WhatsApp',
    'com.instagram.android': 'Instagram',
    'com.google.android.youtube': 'YouTube',
    'com.twitter.android': 'X (Twitter)',
    'com.facebook.katana': 'Facebook',
    'com.snapchat.android': 'Snapchat',
    'com.zhiliaoapp.musically': 'TikTok',
    'com.google.android.apps.messaging': 'Messages',
    'com.google.android.dialer': 'Phone',
    'com.google.android.contacts': 'Contacts',
    'com.google.android.gm': 'Gmail',
    'com.android.chrome': 'Chrome',
    'com.spotify.music': 'Spotify',
    'com.netflix.mediaclient': 'Netflix',
    'org.telegram.messenger': 'Telegram',
    'com.linkedin.android': 'LinkedIn',
    'com.reddit.frontpage': 'Reddit',
    'com.discord': 'Discord',
  };

  Future<bool> hasPermission() async {
    try {
      final bool hasPermission = await _channel.invokeMethod(
        'checkUsageStatsPermission',
      );
      return hasPermission;
    } catch (e) {
      return false;
    }
  }

  Future<void> openSettings() async {
    const intent = AndroidIntent(
      action: 'android.settings.USAGE_ACCESS_SETTINGS',
      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    await intent.launch();
  }

  Future<List<AppUsageInfo>> getUsageStats() async {
    try {
      final endDate = DateTime.now();
      final startDate = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
      ); // Today at midnight

      final List<AppUsageInfo> infoList = [];
      final List<AppUsageInfo> usage = await _fetchAppUsage(startDate, endDate);

      for (var info in usage) {
        if (info.usageDuration.inMinutes > 0) {
          infoList.add(info);
        }
      }

      // Sort descending
      infoList.sort((a, b) => b.usageDuration.compareTo(a.usageDuration));
      return infoList;
    } catch (e) {
      debugPrint('Usage stats unavailable: $e');
      rethrow;
    }
  }

  /// Fetches weekly history and aggregates statistics (average, lowest, highest, change vs yesterday)
  Future<ScreenTimeWeeklySummary> getWeeklySummary() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final List<DailyScreenTime> history = [];

    // Query past 7 days from oldest (6 days ago) to today
    for (int i = 6; i >= 0; i--) {
      // Calendar days, not 24h steps, so DST changes don't shift them.
      final day = DateTime(todayStart.year, todayStart.month, todayStart.day - i);
      final dayEnd = i == 0 ? now : nextDay(day);

      try {
        final usage = await _fetchAppUsage(day, dayEnd);
        var totalMs = 0;
        final validApps = <AppUsageInfo>[];

        for (final app in usage) {
          if (app.usageDuration.inMinutes > 0) {
            totalMs += app.usageDuration.inMilliseconds;
            validApps.add(app);
          }
        }
        validApps.sort((a, b) => b.usageDuration.compareTo(a.usageDuration));

        history.add(
          DailyScreenTime(
            date: day,
            duration: Duration(milliseconds: totalMs),
            topApps: validApps,
          ),
        );
      } catch (_) {
        // Fallback for empty day
        history.add(DailyScreenTime(date: day, duration: Duration.zero));
      }
    }

    final todayDaily = history.last;
    final yesterdayDaily = history.length > 1
        ? history[history.length - 2]
        : null;

    // Filter active days with > 0 screen time for accurate min/max calculations
    final activeDays = history.where((d) => d.duration.inMinutes > 0).toList();

    var totalMinutes = 0;
    DailyScreenTime? lowest;
    DailyScreenTime? highest;

    for (final day in history) {
      totalMinutes += day.duration.inMinutes;
      if (highest == null || day.duration > highest.duration) {
        highest = day;
      }
    }

    if (activeDays.isNotEmpty) {
      lowest = activeDays.reduce((a, b) => a.duration < b.duration ? a : b);
    } else {
      lowest = history.first;
    }

    final avgMinutes = history.isNotEmpty
        ? (totalMinutes / history.length).round()
        : 0;

    // Change vs yesterday %
    double changePct = 0.0;
    if (yesterdayDaily != null && yesterdayDaily.duration.inMinutes > 0) {
      changePct =
          ((todayDaily.duration.inMinutes - yesterdayDaily.duration.inMinutes) /
              yesterdayDaily.duration.inMinutes) *
          100.0;
    }

    return ScreenTimeWeeklySummary(
      dailyHistory: history,
      averageDuration: Duration(minutes: avgMinutes),
      lowestDay: lowest,
      highestDay: highest,
      todayDuration: todayDaily.duration,
      changeVsYesterdayPct: changePct,
      dailyGoalMinutes: getDailyLimitMinutes(),
    );
  }

  /// Minutes of screen time per day over [range] vs the daily limit, with
  /// each day's breakdown (newest first) as the logs.
  Future<TrendData<DailyScreenTime>> trend(TrendRange range) async {
    final now = DateTime.now();
    final days = lastNDays(range.days, now: now);
    final history = <DailyScreenTime>[];
    for (final day in days) {
      final end = isSameDay(day, now) ? now : nextDay(day);
      try {
        final usage = await _fetchAppUsage(day, end);
        final apps = [
          for (final app in usage)
            if (app.usageDuration.inMinutes > 0) app,
        ]..sort((a, b) => b.usageDuration.compareTo(a.usageDuration));
        history.add(
          DailyScreenTime(
            date: day,
            duration: apps.fold(
              Duration.zero,
              (sum, a) => sum + a.usageDuration,
            ),
            topApps: apps,
          ),
        );
      } catch (_) {
        history.add(DailyScreenTime(date: day, duration: Duration.zero));
      }
    }
    final series = TrendSeries(
      [
        for (final d in history)
          DailyPoint(
            d.date,
            d.duration == Duration.zero
                ? null
                : d.duration.inMinutes.toDouble(),
          ),
      ],
      goal: getDailyLimitMinutes().toDouble(),
      direction: GoalDirection.down,
    );
    return TrendData(series, history.reversed.toList());
  }

  Future<List<AppUsageInfo>> _fetchAppUsage(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final Map<dynamic, dynamic>? rawStats = await _channel
          .invokeMethod('getExactUsageStats', {
            'start': startDate.millisecondsSinceEpoch,
            'end': endDate.millisecondsSinceEpoch,
          });

      if (rawStats == null) return [];

      List<AppUsageInfo> result = [];

      rawStats.forEach((key, value) {
        final pkg = key.toString().toLowerCase();
        final durationMillis = value is num && value.isFinite
            ? value.toInt()
            : 0;
        // Nothing to show for zero or bogus (negative) usage.
        if (durationMillis <= 0) return;

        // Skip system packages
        if (_ignoredPackages.any((ignore) => pkg.contains(ignore))) {
          return; // continue in forEach
        }

        // Apply robust naming map
        String resolvedName =
            _appNameMappings[key.toString()] ?? key.toString();

        // Fallback cleaner
        if (resolvedName == key.toString()) {
          final parts = resolvedName.split('.');
          resolvedName = parts.last;
          if (resolvedName.isNotEmpty) {
            resolvedName =
                resolvedName[0].toUpperCase() + resolvedName.substring(1);
          }
        }

        result.add(
          AppUsageInfo(
            appName: resolvedName,
            packageName: key.toString(),
            usageDuration: Duration(milliseconds: durationMillis),
          ),
        );
      });

      return result;
    } catch (e) {
      debugPrint('Exact app usage unavailable: $e');
      rethrow;
    }
  }
}
