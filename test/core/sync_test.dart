import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/database/drift_database.dart';
import 'package:vital_up/core/sync/sync_adapters.dart';
import 'package:vital_up/core/sync/sync_hooks.dart';
import 'package:vital_up/features/activity_tracking/data/repositories/activity_repository_impl.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/track_point.dart';

final _start = DateTime(2026, 10, 1, 7);

ActivitySession _session(String id, {DateTime? endTime}) => ActivitySession(
  id: id,
  activityType: ActivityType.run,
  startTime: _start,
  endTime: endTime,
  totalDistanceMeters: 2500,
  totalDurationSeconds: 900,
  avgPaceSecondsPerKm: 360,
  calories: 180,
  steps: 2800,
  stepCountReliable: true,
  points: [
    for (var i = 0; i < 3; i++)
      TrackPoint(
        latitude: 12.97 + i * 0.0001,
        longitude: 77.59,
        timestamp: _start.add(Duration(seconds: i)),
        accuracy: 4,
        speed: 2.8,
        altitude: 910.0 + i,
      ),
  ],
);

class _Hooks implements SyncHooks {
  int scheduled = 0;
  final deletes = <(String, String)>[];

  @override
  void schedule() => scheduled++;

  @override
  Future<void> recordDelete(String table, String id) async =>
      deletes.add((table, id));
}

void main() {
  group('syncId', () {
    test('is stable and differs by kind, user and time', () {
      final at = DateTime(2026, 10, 2, 9, 30, 0, 0, 123);
      final id = syncId('water', 'u1', at);
      expect(syncId('water', 'u1', at), id);
      expect(syncId('water', 'u1', at.toUtc()), id);
      expect(syncId('sleep', 'u1', at), isNot(id));
      expect(syncId('water', 'u2', at), isNot(id));
      expect(
        syncId('water', 'u1', at.add(const Duration(microseconds: 1))),
        isNot(id),
      );
      expect(
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-').hasMatch(id),
        isTrue,
      );
    });
  });

  group('workout sync', () {
    late AppDatabase db;
    late _Hooks hooks;
    late ActivityRepositoryImpl repo;
    late ActivitySyncAdapter adapter;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      hooks = _Hooks();
      repo = ActivityRepositoryImpl(db, hooks);
      adapter = ActivitySyncAdapter(db);
    });

    tearDown(() => db.close());

    test('only finished workouts are uploaded', () async {
      await repo.saveSession(_session('recording'));
      expect(await adapter.pending('u'), isEmpty);
      expect(hooks.scheduled, 0);

      await repo.saveSession(
        _session('recording', endTime: _start.add(const Duration(minutes: 15))),
      );
      final pending = await adapter.pending('u');
      expect(pending.single.row['id'], 'recording');
      expect(pending.single.row['track'], hasLength(3));
      expect(hooks.scheduled, 1);
    });

    test('marked synced until saved again', () async {
      final done = _session('a', endTime: _start.add(const Duration(minutes: 15)));
      await repo.saveSession(done);
      await adapter.markSynced('u', ['a']);
      expect(await adapter.pending('u'), isEmpty);

      await repo.saveSession(done);
      expect(await adapter.pending('u'), hasLength(1));
    });

    test('a workout uploaded from one phone restores on another', () async {
      await repo.saveSession(
        _session('trip', endTime: _start.add(const Duration(minutes: 15))),
      );
      final row = (await adapter.pending('u')).single.row;

      final otherPhone = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(otherPhone.close);
      await ActivitySyncAdapter(otherPhone).apply('u', [
        {...row, 'deleted_at': null},
      ]);

      final restored = (await ActivityRepositoryImpl(otherPhone).getSessions())
          .single;
      expect(restored.id, 'trip');
      expect(restored.totalDistanceMeters, 2500);
      expect(restored.points.map((p) => p.altitude), [910, 911, 912]);
      // Already in the cloud, so not uploaded again.
      expect(await ActivitySyncAdapter(otherPhone).pending('u'), isEmpty);
    });

    test('deleting a synced workout tells the other devices', () async {
      await repo.saveSession(
        _session('a', endTime: _start.add(const Duration(minutes: 15))),
      );
      await repo.deleteSession('a'); // never uploaded: nothing to tell
      expect(hooks.deletes, isEmpty);

      await repo.saveSession(
        _session('b', endTime: _start.add(const Duration(minutes: 15))),
      );
      await adapter.markSynced('u', ['b']);
      await repo.deleteSession('b');
      expect(hooks.deletes, [('activity_sessions', 'b')]);
    });

    test('a deletion from another device removes the workout', () async {
      await repo.saveSession(
        _session('a', endTime: _start.add(const Duration(minutes: 15))),
      );
      final row = (await adapter.pending('u')).single.row;
      await adapter.apply('u', [
        {...row, 'deleted_at': '2026-10-02T10:00:00Z'},
      ]);
      expect(await repo.getSessions(), isEmpty);
    });
  });
}
