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
}

@DriftDatabase(tables: [DriftActivitySessions, DriftTrackPoints])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3;

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
        },
      );

  // Insert or update an activity session
  Future<int> saveSession(DriftActivitySession session) => 
      into(driftActivitySessions).insertOnConflictUpdate(session);

  Future<int> saveSessionCompanion(DriftActivitySessionsCompanion session) =>
      into(driftActivitySessions).insertOnConflictUpdate(session);

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
  Future<int> deleteSession(String id) =>
      (delete(driftActivitySessions)..where((t) => t.id.equals(id))).go();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'vital_up_activity.db'));
    return NativeDatabase.createInBackground(file);
  });
}
