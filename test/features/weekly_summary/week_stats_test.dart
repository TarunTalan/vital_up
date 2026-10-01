import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/weekly_summary/weekly_summary_service.dart';

ActivitySession _workout(int minutes, double meters, {bool finished = true}) {
  final start = DateTime(2026, 10, 1, 7);
  return ActivitySession(
    id: '$minutes',
    activityType: ActivityType.run,
    startTime: start,
    endTime: finished ? start.add(Duration(minutes: minutes)) : null,
    totalDistanceMeters: meters,
    totalDurationSeconds: minutes * 60,
    avgPaceSecondsPerKm: 0,
    calories: 0,
    steps: 0,
    stepCountReliable: true,
    points: const [],
  );
}

void main() {
  final from = DateTime(2026, 9, 28);

  test('totals the week', () {
    final stats = weekStats(
      from: from,
      sessions: [
        _workout(30, 5000),
        _workout(45, 7500),
        _workout(20, 1000, finished: false),
      ],
      waterByDay: {
        DateTime(2026, 9, 28): 2600,
        DateTime(2026, 9, 29): 1200,
        DateTime(2026, 9, 30): 2500,
      },
      waterGoalMl: 2500,
      sleep: const [Duration(hours: 7), Duration(hours: 8)],
      mealTimes: [
        DateTime(2026, 9, 28, 8),
        DateTime(2026, 9, 28, 13),
        DateTime(2026, 9, 30, 19),
      ],
      weights: const [80.0, 79.6, 79.2],
    );
    expect(stats.workouts, 2);
    expect(stats.activeMinutes, 75);
    expect(stats.distanceKm, 12.5);
    expect(stats.avgSleep, const Duration(hours: 7, minutes: 30));
    expect(stats.waterGoalDays, 2);
    expect(stats.waterMl, 6300);
    expect(stats.meals, 3);
    expect(stats.mealDays, 2);
    expect(stats.weightChangeKg, closeTo(-0.8, 1e-9));
    expect(stats.isEmpty, isFalse);
  });

  test('an empty week', () {
    final stats = weekStats(
      from: from,
      sessions: const [],
      waterByDay: const {},
      waterGoalMl: 2500,
      sleep: const [],
      mealTimes: const [],
      weights: const [80],
    );
    expect(stats.isEmpty, isTrue);
    expect(stats.avgSleep, isNull);
    expect(stats.weightChangeKg, isNull);
  });
}
