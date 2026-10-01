import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/database/drift_database.dart';
import 'package:vital_up/features/activity_tracking/data/repositories/activity_repository_impl.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/track_point.dart';

final _start = DateTime(2026, 10, 1, 7);

ActivitySession _session(String id, {DateTime? endTime, int seconds = 600}) =>
    ActivitySession(
      id: id,
      activityType: ActivityType.walk,
      startTime: _start,
      endTime: endTime,
      totalDistanceMeters: 840,
      totalDurationSeconds: seconds,
      avgPaceSecondsPerKm: 714,
      calories: 40,
      steps: 1100,
      stepCountReliable: true,
      points: [
        for (var i = 0; i < 3; i++)
          TrackPoint(
            latitude: 12.97 + i * 0.0001,
            longitude: 77.59,
            timestamp: _start.add(Duration(seconds: i)),
            accuracy: 5,
            speed: 1.4,
            altitude: 900.0 + i,
          ),
      ],
    );

void main() {
  late AppDatabase db;
  late ActivityRepositoryImpl repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = ActivityRepositoryImpl(db);
  });

  tearDown(() => db.close());

  test('round-trips a session with its route, including altitude', () async {
    await repo.saveSession(_session('a', endTime: _start.add(const Duration(minutes: 10))));
    final loaded = (await repo.getSessions()).single;
    expect(loaded.points, hasLength(3));
    expect(loaded.points.map((p) => p.altitude), [900, 901, 902]);
  });

  test('re-saving a checkpoint replaces the route instead of duplicating it', () async {
    await repo.saveSession(_session('a'));
    await repo.saveSession(_session('a', endTime: _start.add(const Duration(minutes: 10))));
    final loaded = (await repo.getSessions()).single;
    expect(loaded.points, hasLength(3));
    expect(loaded.endTime, isNotNull);
  });

  test('deleting a session also deletes its track points', () async {
    await repo.saveSession(_session('a', endTime: _start));
    await repo.deleteSession('a');
    expect(await db.getTrackPointsForSession('a'), isEmpty);
  });

  test('interrupted sessions are closed at their last checkpoint', () async {
    await repo.saveSession(_session('crashed', seconds: 900));
    await repo.saveSession(_session('done', endTime: _start.add(const Duration(hours: 1))));

    await repo.finalizeInterruptedSessions();

    final byId = {for (final s in await repo.getSessions()) s.id: s};
    expect(byId['crashed']!.endTime, _start.add(const Duration(seconds: 900)));
    expect(byId['done']!.endTime, _start.add(const Duration(hours: 1)));
  });
}
