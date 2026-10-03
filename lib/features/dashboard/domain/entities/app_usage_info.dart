import 'package:equatable/equatable.dart';

class AppUsageInfo extends Equatable {
  final String appName;
  final String packageName;
  final Duration usageDuration;

  const AppUsageInfo({
    required this.appName,
    required this.packageName,
    required this.usageDuration,
  });

  @override
  List<Object?> get props => [appName, packageName, usageDuration];
}

class DailyScreenTime extends Equatable {
  final DateTime date;
  final Duration duration;
  final List<AppUsageInfo> topApps;

  const DailyScreenTime({
    required this.date,
    required this.duration,
    this.topApps = const [],
  });

  @override
  List<Object?> get props => [date, duration, topApps];
}

class ScreenTimeWeeklySummary extends Equatable {
  final List<DailyScreenTime> dailyHistory; // 7 days (oldest to newest)
  final Duration averageDuration;
  final DailyScreenTime? lowestDay;
  final DailyScreenTime? highestDay;
  final Duration todayDuration;
  final double changeVsYesterdayPct; // e.g. -12.5 means 12.5% reduction
  final int dailyGoalMinutes;

  const ScreenTimeWeeklySummary({
    required this.dailyHistory,
    required this.averageDuration,
    this.lowestDay,
    this.highestDay,
    required this.todayDuration,
    required this.changeVsYesterdayPct,
    this.dailyGoalMinutes = 240, // 4 hours default
  });

  String get wellnessRating {
    final hours = todayDuration.inMinutes / 60.0;
    if (hours <= 2.5) return 'Mindful';
    if (hours <= 4.5) return 'Balanced';
    return 'Heavy usage';
  }

  @override
  List<Object?> get props => [
    dailyHistory,
    averageDuration,
    lowestDay,
    highestDay,
    todayDuration,
    changeVsYesterdayPct,
    dailyGoalMinutes,
  ];
}
