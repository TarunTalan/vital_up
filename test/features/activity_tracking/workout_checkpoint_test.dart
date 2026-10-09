import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/services/workout_checkpoint.dart';

final _start = DateTime(2026, 10, 9, 7);

ActivitySession _session({int seconds = 600, String? targetType}) => ActivitySession(
      id: 's1',
      activityType: ActivityType.run,
      startTime: _start,
      endTime: null,
      totalDistanceMeters: 1800,
      totalDurationSeconds: seconds,
      avgPaceSecondsPerKm: 333,
      calories: 120,
      steps: 1500,
      stepCountReliable: true,
      points: const [],
      targetType: targetType,
    );

WorkoutCheckpoint _cp({DateTime? savedAt, bool paused = false}) => WorkoutCheckpoint(
      sessionId: 's1',
      savedAt: savedAt ?? _start.add(const Duration(minutes: 12)),
      paused: paused,
      elevationGainMeters: 14.5,
      weightKg: 64,
    );

void main() {
  group('encode / decode', () {
    test('round trips every field', () {
      final original = _cp(paused: true);
      final decoded = WorkoutCheckpoint.decode(original.encode())!;
      expect(decoded.sessionId, 's1');
      expect(decoded.savedAt, original.savedAt);
      expect(decoded.paused, isTrue);
      expect(decoded.elevationGainMeters, 14.5);
      expect(decoded.weightKg, 64);
    });

    test('rejects missing, corrupt and other-version payloads', () {
      expect(WorkoutCheckpoint.decode(null), isNull);
      expect(WorkoutCheckpoint.decode(''), isNull);
      expect(WorkoutCheckpoint.decode('{not json'), isNull);
      expect(WorkoutCheckpoint.decode('[1,2]'), isNull);
      expect(WorkoutCheckpoint.decode('{"v":2,"id":"a","savedAt":"2026-10-09T07:00:00Z"}'), isNull);
      expect(WorkoutCheckpoint.decode('{"v":1,"id":"","savedAt":"2026-10-09T07:00:00Z"}'), isNull);
      expect(WorkoutCheckpoint.decode('{"v":1,"id":"a","savedAt":"yesterday"}'), isNull);
    });

    test('falls back on bad numbers instead of failing', () {
      final cp = WorkoutCheckpoint.decode(
        '{"v":1,"id":"a","savedAt":"2026-10-09T07:00:00Z","elevation":-3,"weightKg":"x"}',
      )!;
      expect(cp.elevationGainMeters, 0);
      expect(cp.weightKg, 70);
      expect(cp.paused, isFalse);
    });
  });

  group('decide', () {
    final saved = _start.add(const Duration(minutes: 12));

    test('offers resume while recent', () {
      final cp = _cp(savedAt: saved);
      expect(cp.decide(saved.add(const Duration(minutes: 5))), InterruptedWorkoutAction.offerResume);
      expect(cp.decide(saved.add(WorkoutCheckpoint.maxResumeAge)), InterruptedWorkoutAction.offerResume);
    });

    test('saves only once older than the resume window', () {
      final cp = _cp(savedAt: saved);
      expect(
        cp.decide(saved.add(WorkoutCheckpoint.maxResumeAge + const Duration(minutes: 1))),
        InterruptedWorkoutAction.saveOnly,
      );
    });

    test('tolerates small clock skew but not a checkpoint from the future', () {
      final cp = _cp(savedAt: saved);
      expect(cp.decide(saved.subtract(const Duration(minutes: 2))), InterruptedWorkoutAction.offerResume);
      expect(cp.decide(saved.subtract(const Duration(hours: 3))), InterruptedWorkoutAction.saveOnly);
    });
  });

  group('restore math', () {
    test('restored elapsed is the recorded active time, never the dead time', () {
      expect(WorkoutCheckpoint.restoredElapsed(_session(seconds: 600)), const Duration(minutes: 10));
      expect(WorkoutCheckpoint.restoredElapsed(_session(seconds: -5)), Duration.zero);
    });

    test('end time is the last checkpoint', () {
      final cp = _cp(savedAt: _start.add(const Duration(minutes: 15)));
      expect(cp.finishedEndTime(_session(seconds: 600)), _start.add(const Duration(minutes: 15)));
    });

    test('end time is never before start plus active time', () {
      final cp = _cp(savedAt: _start.add(const Duration(minutes: 5)));
      expect(cp.finishedEndTime(_session(seconds: 600)), _start.add(const Duration(minutes: 10)));
    });

    test('finished session keeps the recording and takes the target', () {
      final done = _cp().finishedSession(
        _session(),
        targetType: 'distance',
        targetValue: 1.5,
        targetAchieved: true,
      );
      expect(done.endTime, isNotNull);
      expect(done.totalDistanceMeters, 1800);
      expect(done.steps, 1500);
      expect(done.targetType, 'distance');
      expect(done.targetValue, 1.5);
      expect(done.targetAchieved, isTrue);
    });

    test('without a target the session keeps its own', () {
      final done = _cp().finishedSession(_session(targetType: 'calories'));
      expect(done.targetType, 'calories');
      expect(done.targetAchieved, isFalse);
    });
  });
}
