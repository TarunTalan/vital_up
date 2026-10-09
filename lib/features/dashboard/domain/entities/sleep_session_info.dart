import 'package:equatable/equatable.dart';

/// Where a night came from: a health store (watch, Samsung Health...), the
/// user, or the phone's screen-off time (an estimate the user confirmed).
enum SleepDataSource { healthStore, manual, phone }

class SleepSessionInfo extends Equatable {
  final DateTime bedTime;
  final DateTime wakeTime;
  final Duration duration;
  final SleepDataSource source;
  final int? deepSleepMinutes;
  final int? remSleepMinutes;
  final int? lightSleepMinutes;
  final int? awakeMinutes;
  final int? customScore;

  const SleepSessionInfo({
    required this.bedTime,
    required this.wakeTime,
    required this.duration,
    required this.source,
    this.deepSleepMinutes,
    this.remSleepMinutes,
    this.lightSleepMinutes,
    this.awakeMinutes,
    this.customScore,
  });

  /// Computed sleep quality score from 0 to 100
  int get sleepScore {
    if (customScore != null) return customScore!;

    final hours = duration.inMinutes / 60.0;
    double score = 70.0;

    // 1. Duration score (Target: 7-9 hours)
    if (hours >= 7.0 && hours <= 9.0) {
      score += 25.0 - (hours - 8.0).abs() * 5.0;
    } else if (hours >= 6.0 && hours < 7.0) {
      score += 15.0 + (hours - 6.0) * 10.0;
    } else if (hours > 9.0 && hours <= 10.5) {
      score += 18.0 - (hours - 9.0) * 10.0;
    } else if (hours >= 4.5 && hours < 6.0) {
      score -= 10.0 - (hours - 4.5) * 10.0;
    } else {
      score -= 30.0;
    }

    // 2. Stage bonus if stages data is present
    if (hasStages) {
      final totalStages = (deepSleepMinutes ?? 0) +
          (remSleepMinutes ?? 0) +
          (lightSleepMinutes ?? 0);
      if (totalStages > 0) {
        final deepPct = (deepSleepMinutes ?? 0) / totalStages;
        final remPct = (remSleepMinutes ?? 0) / totalStages;

        // Healthy deep sleep is ~15-25%, REM is ~20-25%
        if (deepPct >= 0.15) score += 3.0;
        if (remPct >= 0.18) score += 2.0;
      }
    }

    // 3. Deduction for awake disruptions
    if ((awakeMinutes ?? 0) > 30) {
      score -= ((awakeMinutes! - 30) / 10).clamp(0, 15);
    }

    return score.round().clamp(20, 100);
  }

  String get scoreCategory {
    final s = sleepScore;
    if (s >= 85) return 'Optimal';
    if (s >= 70) return 'Good';
    if (s >= 50) return 'Fair';
    return 'Low';
  }

  bool get hasStages =>
      (deepSleepMinutes != null && deepSleepMinutes! > 0) ||
      (remSleepMinutes != null && remSleepMinutes! > 0) ||
      (lightSleepMinutes != null && lightSleepMinutes! > 0);

  @override
  List<Object?> get props => [
        bedTime,
        wakeTime,
        duration,
        source,
        deepSleepMinutes,
        remSleepMinutes,
        lightSleepMinutes,
        awakeMinutes,
        customScore,
      ];
}
