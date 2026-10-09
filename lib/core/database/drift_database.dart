import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'drift_database.g.dart';

class DriftActivitySessions extends Table {
  TextColumn get id => text()();
  TextColumn get activityType => text()();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime().nullable()();
  RealColumn get totalDistanceMeters => real()();
  IntColumn get totalDurationSeconds => integer()();
  IntColumn get avgPaceSecondsPerKm => integer()();
  IntColumn get calories => integer()();
  IntColumn get steps => integer()();
  BoolColumn get stepCountReliable => boolean().withDefault(const Constant(true))();
  TextColumn get targetType => text().nullable()();
  RealColumn get targetValue => real().nullable()();
  BoolColumn get targetAchieved => boolean().nullable().withDefault(const Constant(false))();

  /// Uploaded to `activity_sessions` (SyncService). Reset on every save.
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class DriftTrackPoints extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sessionId => text().references(DriftActivitySessions, #id, onDelete: KeyAction.cascade)();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  DateTimeColumn get timestamp => dateTime()();
  RealColumn get accuracy => real()();
  RealColumn get speed => real()();
  RealColumn get altitude => real().withDefault(const Constant(0.0))();
}

@DriftDatabase(tables: [DriftActivitySessions, DriftTrackPoints])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// For tests: run against e.g. `NativeDatabase.memory()`.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(
              driftActivitySessions,
              driftActivitySessions.stepCountReliable,
            );
          }
          if (from < 3) {
            await m.addColumn(
              driftActivitySessions,
              driftActivitySessions.targetType,
            );
            await m.addColumn(
              driftActivitySessions,
              driftActivitySessions.targetValue,
            );
            await m.addColumn(
              driftActivitySessions,
              driftActivitySessions.targetAchieved,
            );
          }
          if (from < 4) {
            await m.addColumn(driftTrackPoints, driftTrackPoints.altitude);
          }
          if (from < 5) {
            await m.addColumn(
              driftActivitySessions,
              driftActivitySessions.synced,
            );
          }
        },
        beforeOpen: (details) async {
          // SQLite ships with foreign keys off; without this the cascade on
          // track points never fires and deleted sessions leave them behind.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Deletes every workout and its track points.
  Future<void> clearAll() => transaction(() async {
    await delete(driftTrackPoints).go();
    await delete(driftActivitySessions).go();
  });

  // Insert or update an activity session. Any local change needs uploading.
  Future<int> saveSession(DriftActivitySession session) =>
      into(driftActivitySessions)
          .insertOnConflictUpdate(session.copyWith(synced: false));

  Future<int> saveSessionCompanion(DriftActivitySessionsCompanion session) =>
      into(driftActivitySessions)
          .insertOnConflictUpdate(session.copyWith(synced: const Value(false)));

  // Insert a track point
  Future<int> saveTrackPoint(DriftTrackPoint point) => 
      into(driftTrackPoints).insert(point);

  // Insert multiple track points in batch
  Future<void> saveTrackPoints(List<DriftTrackPoint> points) async {
    await batch((batch) {
      batch.insertAll(driftTrackPoints, points);
    });
  }

  Future<void> saveTrackPointsCompanion(List<DriftTrackPointsCompanion> points) async {
    await batch((batch) {
      batch.insertAll(driftTrackPoints, points);
    });
  }

  Future<void> replaceTrackPointsForSession(
    String sessionId,
    List<DriftTrackPointsCompanion> points,
  ) async {
    await transaction(() async {
      await (delete(driftTrackPoints)..where((t) => t.sessionId.equals(sessionId))).go();
      if (points.isNotEmpty) {
        await batch((batch) {
          batch.insertAll(driftTrackPoints, points);
        });
      }
    });
  }

  /// Upserts a session and replaces its route in one transaction, so a
  /// crash mid-save never leaves a session paired with a partial route.
  Future<void> saveSessionWithPoints(
    DriftActivitySessionsCompanion session,
    List<DriftTrackPointsCompanion> points,
  ) async {
    await transaction(() async {
      await into(driftActivitySessions)
          .insertOnConflictUpdate(session.copyWith(synced: const Value(false)));
      await replaceTrackPointsForSession(session.id.value, points);
    });
  }

  /// Finished workouts not uploaded yet.
  Future<List<DriftActivitySession>> unsyncedFinishedSessions() =>
      (select(driftActivitySessions)
            ..where((t) => t.synced.equals(false) & t.endTime.isNotNull()))
          .get();

  Future<void> markSessionsSynced(Iterable<String> ids) =>
      (update(driftActivitySessions)..where((t) => t.id.isIn(ids)))
          .write(const DriftActivitySessionsCompanion(synced: Value(true)));

  /// Stores a workout downloaded from the cloud, already in sync.
  Future<void> saveSyncedSession(
    DriftActivitySessionsCompanion session,
    List<DriftTrackPointsCompanion> points,
  ) async {
    await transaction(() async {
      await into(driftActivitySessions)
          .insertOnConflictUpdate(session.copyWith(synced: const Value(true)));
      await replaceTrackPointsForSession(session.id.value, points);
    });
  }

  /// Every track point of every session, grouped by session id and in
  /// time order. One query instead of one per session.
  Future<Map<String, List<DriftTrackPoint>>> getAllTrackPointsBySession() async {
    final rows = await (select(driftTrackPoints)
          ..orderBy([
            (t) => OrderingTerm(expression: t.sessionId),
            (t) => OrderingTerm(expression: t.timestamp),
          ]))
        .get();
    final grouped = <String, List<DriftTrackPoint>>{};
    for (final row in rows) {
      (grouped[row.sessionId] ??= []).add(row);
    }
    return grouped;
  }

  /// Closes sessions that were still recording when the app died (they
  /// are checkpointed with no end time) and drops orphaned track points.
  /// Must only run when no workout is being recorded, i.e. at startup.
  /// [keepOpenId] stays open: a recent workout the user may resume.
  Future<void> finalizeInterruptedSessions({String? keepOpenId}) async {
    await transaction(() async {
      await customStatement(
        "UPDATE drift_activity_sessions "
        "SET end_time = start_time + total_duration_seconds, synced = 0 "
        "WHERE end_time IS NULL AND id IS NOT ?",
        [keepOpenId],
      );
      await customStatement(
        'DELETE FROM drift_track_points '
        'WHERE session_id NOT IN (SELECT id FROM drift_activity_sessions)',
      );
    });
  }

  // Retrieve a session with its track points
  Future<DriftActivitySession?> getSession(String id) =>
      (select(driftActivitySessions)..where((t) => t.id.equals(id))).getSingleOrNull();

  // Retrieve track points for a session
  Future<List<DriftTrackPoint>> getTrackPointsForSession(String sessionId) =>
      (select(driftTrackPoints)
        ..where((t) => t.sessionId.equals(sessionId))
        ..orderBy([(t) => OrderingTerm(expression: t.timestamp)]))
      .get();

  // Retrieve all sessions in reverse chronological order
  Future<List<DriftActivitySession>> getAllSessions() =>
      (select(driftActivitySessions)..orderBy([(t) => OrderingTerm(expression: t.startTime, mode: OrderingMode.desc)])).get();

  // Delete a session and cascaded points
  Future<void> deleteSession(String id) => transaction(() async {
        await (delete(driftTrackPoints)..where((t) => t.sessionId.equals(id))).go();
        await (delete(driftActivitySessions)..where((t) => t.id.equals(id))).go();
      });
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'vital_up_activity.db'));
    return NativeDatabase.createInBackground(file);
  });
}
