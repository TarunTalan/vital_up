import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/workout_intensity.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/activity_summary.dart';

import '../../helpers/pump_app.dart';

ActivitySession _session(ActivityType type, {double meters = 0}) =>
    ActivitySession(
      id: type.name,
      activityType: type,
      startTime: DateTime(2026, 10, 18, 7, 30),
      endTime: DateTime(2026, 10, 18, 9, 44),
      totalDistanceMeters: meters,
      totalDurationSeconds: 8040,
      avgPaceSecondsPerKm: meters > 0 ? 381 : 0,
      calories: 1480,
      steps: meters > 0 ? 23950 : 0,
      stepCountReliable: true,
      points: const [],
      intensity: meters > 0 ? null : WorkoutIntensity.hard,
      targetType: meters > 0 ? 'distance' : 'duration',
      targetValue: meters > 0 ? 25 : 120,
      targetAchieved: true,
    );

void main() {
  Future<void> pump(WidgetTester tester, ActivitySession session) => pumpPage(
    tester,
    Scaffold(
      body: SingleChildScrollView(child: ActivitySummary(session: session)),
    ),
    textScale: kMaxTextScale,
  );

  testWidgets('a GPS activity: distance first, then time, pace and steps', (
    tester,
  ) async {
    await pump(tester, _session(ActivityType.trekking, meters: 21100));
    expect(find.text('21.10'), findsOneWidget);
    expect(find.text('Pace /km'), findsOneWidget);
    expect(find.text('Steps'), findsOneWidget);
    expect(find.text('Target achieved'), findsOneWidget);
    expect(takeAllExceptions(tester), isEmpty);
    expect(truncatedTexts(tester), isEmpty);
  });

  testWidgets('a timed workout: time first, effort, no distance or pace', (
    tester,
  ) async {
    await pump(tester, _session(ActivityType.yoga));
    expect(find.text('02:14:00'), findsOneWidget);
    expect(find.text('Effort'), findsOneWidget);
    expect(find.text('Pace /km'), findsNothing);
    expect(find.text('Target: 120 min'), findsOneWidget);
    expect(takeAllExceptions(tester), isEmpty);
    expect(truncatedTexts(tester), isEmpty);
  });
}
