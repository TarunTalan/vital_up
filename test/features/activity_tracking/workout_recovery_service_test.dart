import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/database/drift_database.dart';
import 'package:vital_up/features/activity_tracking/data/repositories/activity_repository_impl.dart';
import 'package:vital_up/features/activity_tracking/data/services/workout_recovery_service.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/track_point.dart';
import 'package:vital_up/features/activity_tracking/domain/services/workout_checkpoint.dart';

final _start = DateTime(2026, 10, 9, 7);

ActivitySession _open(String id, {int seconds = 900, double meters = 2000, int steps = 2000}) =>
    ActivitySession(
      id: id,
      activityType: ActivityType.walk,
      startTime: _start,
      endTime: null,
      totalDistanceMeters: meters,
      totalDurationSeconds: seconds,
      avgPaceSecondsPerKm: 450,
      calories: 90,
      steps: steps,
      stepCountReliable: true,
      points: [
        TrackPoint(
          latitude: 12.97,
          longitude: 77.59,
          timestamp: _start,
          accuracy: 5,
          speed: 1.3,
          altitude: 900,
        ),
      ],
    );

void main() {
  late AppDatabase db;
  late ActivityRepositoryImpl repo;
  late WorkoutCheckpointStore store;
  late DateTime now;
  late WorkoutRecoveryService recovery;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = ActivityRepositoryImpl(db);
    store = WorkoutCheckpointStore(await SharedPreferences.getInstance());
    now = _start.add(const Duration(minutes: 20));
    recovery = WorkoutRecoveryService(repository: repo, store: store, now: () => now);
  });

  tearDown(() => db.close());

  Future<void> mark(String id, {Duration after = const Duration(minutes: 16)}) =>
      store.write(WorkoutCheckpoint(sessionId: id, savedAt: _start.add(after), paused: false));

  test('startup keeps a recent workout open and closes the others', () async {
    await repo.saveSession(_open('recent'));
    await repo.saveSession(_open('older'));
    await mark('recent');

    await recovery.settleAtStartup();

    final byId = {for (final s in await repo.getSessions()) s.id: s};
    expect(byId['recent']!.endTime, isNull);
    expect(byId['older']!.endTime, isNotNull);
    final pending = await recovery.pending();
    expect(pending!.action, InterruptedWorkoutAction.offerResume);
    expect(pending.session.points, hasLength(1));
  });

  test('startup saves a stale workout at its last checkpoint', () async {
    await repo.saveSession(_open('stale'));
    await mark('stale');
    now = _start.add(const Duration(days: 1));

    await recovery.settleAtStartup();

    final saved = (await repo.getSessions()).single;
    expect(saved.endTime, _start.add(const Duration(minutes: 16)));
    expect(store.read(), isNull);
  });

  test('startup drops a stale workout too short to keep', () async {
    await repo.saveSession(_open('blip', seconds: 4, meters: 0, steps: 0));
    await mark('blip', after: const Duration(seconds: 4));
    now = _start.add(const Duration(days: 1));

    await recovery.settleAtStartup();

    expect(await repo.getSessions(), isEmpty);
    expect(store.read(), isNull);
  });

  test('save and finish closes the workout with the target result', () async {
    await repo.saveSession(_open('a'));
    await mark('a');

    final outcome = await recovery.finish(
      (await recovery.pending())!,
      targetType: 'distance',
      targetValue: 1.5,
      targetAchieved: true,
    );

    expect(outcome, InterruptedWorkoutOutcome.saved);
    final saved = (await repo.getSessions()).single;
    expect(saved.endTime, isNotNull);
    expect(saved.targetAchieved, isTrue);
    expect(store.read(), isNull);
  });

  test('discard deletes the workout and its route', () async {
    await repo.saveSession(_open('a'));
    await mark('a');

    expect(await recovery.discard((await recovery.pending())!), isTrue);

    expect(await repo.getSessions(), isEmpty);
    expect(await db.getTrackPointsForSession('a'), isEmpty);
    expect(store.read(), isNull);
  });

  test('a checkpoint whose session is gone or finished is cleared', () async {
    await mark('missing');
    expect(await recovery.pending(), isNull);
    expect(store.read(), isNull);

    await repo.saveSession(_open('done'));
    await repo.saveSession(ActivitySession(
      id: 'done',
      activityType: ActivityType.walk,
      startTime: _start,
      endTime: _start.add(const Duration(minutes: 15)),
      totalDistanceMeters: 2000,
      totalDurationSeconds: 900,
      avgPaceSecondsPerKm: 450,
      calories: 90,
      steps: 2000,
      stepCountReliable: true,
      points: const [],
    ));
    await mark('done');
    expect(await recovery.pending(), isNull);
    expect(store.read(), isNull);
  });

  test('a corrupt checkpoint is ignored and removed', () async {
    await store.prefs.setString(WorkoutCheckpointStore.key, '{broken');
    await repo.saveSession(_open('a'));

    await recovery.settleAtStartup();

    expect(store.prefs.containsKey(WorkoutCheckpointStore.key), isFalse);
    expect((await repo.getSessions()).single.endTime, isNotNull);
  });
}
