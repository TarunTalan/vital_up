import 'dart:async';
import 'dart:convert';
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

  /// Android keeps raw usage events for about 10 days, so each finished
  /// day is saved on the device as it's read (pref [savedDaysKey], last
  /// [keepDays] days): history keeps growing past the system's window, and
  /// a reload only queries the days that can still change.
  static const savedDaysKey = 'screen_time_days_v1';

  /// How long saved days are kept.
  static const keepDays = 400;

  /// Apps kept per saved day.
  static const _savedApps = 10;

  /// Read from prefs at the start of each load ([_reloadSaved]), so a
  /// sign-out wipe of [savedDaysKey] is never written back.
  Map<String, DailyScreenTime>? _saved;
  bool _savedChanged = false;

  void _reloadSaved() {
    _saved = null;
    _savedChanged = false;
  }

  static String _dayKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  Map<String, DailyScreenTime> _savedDays() {
    final loaded = _saved;
    if (loaded != null) return loaded;
    final days = <String, DailyScreenTime>{};
    try {
      final raw = _prefs?.getString(savedDaysKey);
      if (raw != null) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        map.forEach((key, value) {
          final parts = key.split('-').map(int.tryParse).toList();
          if (parts.length != 3 || parts.contains(null)) return;
          final entry = value as Map<String, dynamic>;
          final ms = (entry['ms'] as num?)?.toInt() ?? 0;
          if (ms <= 0) return;
          days[key] = DailyScreenTime(
            date: DateTime(parts[0]!, parts[1]!, parts[2]!),
            duration: Duration(milliseconds: ms),
            topApps: [
              for (final app in (entry['apps'] as List? ?? const []))
                if (app is Map && (app['ms'] as num? ?? 0) > 0)
                  AppUsageInfo(
                    appName: '${app['n'] ?? ''}',
                    packageName: '${app['p'] ?? ''}',
                    usageDuration: Duration(
                      milliseconds: (app['ms'] as num).toInt(),
                    ),
                  ),
            ],
          );
        });
      }
    } catch (e) {
      // A damaged copy only costs the days the system no longer has.
      debugPrint('Saved screen time unreadable: $e');
    }
    return _saved = days;
  }

  Future<void> _writeSavedDays() async {
    if (!_savedChanged) return;
    _savedChanged = false;
    final days = _savedDays();
    final now = DateTime.now();
    final oldest = DateTime(now.year, now.month, now.day - keepDays);
    days.removeWhere((_, d) => d.date.isBefore(oldest));
    try {
      await _prefs?.setString(
        savedDaysKey,
        jsonEncode({
          for (final e in days.entries)
            e.key: {
              'ms': e.value.duration.inMilliseconds,
              'apps': [
                for (final app in e.value.topApps.take(_savedApps))
                  {
                    'n': app.appName,
                    'p': app.packageName,
                    'ms': app.usageDuration.inMilliseconds,
                  },
              ],
            },
        }),
      );
    } catch (e) {
      debugPrint('Saving screen time failed: $e');
    }
  }

  /// [day]'s screen time: the saved copy of a finished day, else the
  /// system's figures (saved once the day has ended a while ago). Call
  /// [_writeSavedDays] after a batch.
  Future<DailyScreenTime> _day(DateTime day, DateTime now) async {
    final key = _dayKey(day);
    final saved = _savedDays()[key];
    if (saved != null) return saved;
    final end = isSameDay(day, now) ? now : nextDay(day);
    try {
      final apps = [
        for (final app in await _fetchAppUsage(day, end))
          if (app.usageDuration.inMinutes > 0) app,
      ]..sort((a, b) => b.usageDuration.compareTo(a.usageDuration));
      final daily = DailyScreenTime(
        date: day,
        duration: apps.fold(Duration.zero, (sum, a) => sum + a.usageDuration),
        topApps: apps,
      );
      // The system can report the last events late: only keep a day that
      // ended a while ago, and only one with usage (an empty one may just
      // be past the system's window).
      if (now.difference(end) > const Duration(hours: 1) &&
          daily.duration > Duration.zero) {
        _savedDays()[key] = daily;
        _savedChanged = true;
      }
      return daily;
    } catch (_) {
      return DailyScreenTime(date: day, duration: Duration.zero);
    }
  }

  /// Every day with screen time, newest first: the days the system still
  /// has (about 10) plus every saved one before them.
  Future<List<DailyScreenTime>> history() async {
    _reloadSaved();
    final now = DateTime.now();
    final byDay = <String, DailyScreenTime>{};
    for (final day in lastNDays(systemDays, now: now)) {
      byDay[_dayKey(day)] = await _day(day, now);
    }
    await _writeSavedDays();
    for (final e in _savedDays().entries) {
      byDay.putIfAbsent(e.key, () => e.value);
    }
    return byDay.values.where((d) => d.duration > Duration.zero).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Days of usage events Android keeps.
  static const systemDays = 10;

  /// Fetches weekly history and aggregates statistics (average, lowest, highest, change vs yesterday)
  Future<ScreenTimeWeeklySummary> getWeeklySummary() async {
    _reloadSaved();
    final now = DateTime.now();
    // Calendar days, not 24h steps, so DST changes don't shift them.
    final history = [
      for (final day in lastNDays(7, now: now)) await _day(day, now),
    ];
    await _writeSavedDays();

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
    _reloadSaved();
    final history = [
      for (final day in lastNDays(range.days, now: now)) await _day(day, now),
    ];
    await _writeSavedDays();
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
