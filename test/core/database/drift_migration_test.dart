import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/database/drift_database.dart';

/// Workout data must survive every app update: each test builds the
/// database exactly as an older release created it (the SQL drift
/// generated for that schema version), opens it with today's
/// [AppDatabase] and checks the upgrade kept every row and ends with the
/// same schema as a fresh install.
/// When bumping the schema, add the new version here and dump it with
/// `dart run drift_dev schema dump lib/core/database/drift_database.dart drift_schemas/`.

/// Columns of drift_activity_sessions as each release created them.
String _sessionsSql(int version) {
  final columns = [
    '"id" TEXT NOT NULL',
    '"activity_type" TEXT NOT NULL',
    '"start_time" INTEGER NOT NULL',
    '"end_time" INTEGER NULL',
    '"total_distance_meters" REAL NOT NULL',
    '"total_duration_seconds" INTEGER NOT NULL',
    '"avg_pace_seconds_per_km" INTEGER NOT NULL',
    '"calories" INTEGER NOT NULL',
    '"steps" INTEGER NOT NULL',
    if (version >= 2)
      '"step_count_reliable" INTEGER NOT NULL DEFAULT 1 '
          'CHECK ("step_count_reliable" IN (0, 1))',
    if (version >= 3) ...[
      '"target_type" TEXT NULL',
      '"target_value" REAL NULL',
      '"target_achieved" INTEGER NULL DEFAULT 0 '
          'CHECK ("target_achieved" IN (0, 1))',
    ],
    if (version >= 5)
      '"synced" INTEGER NOT NULL DEFAULT 0 CHECK ("synced" IN (0, 1))',
  ];
  return 'CREATE TABLE IF NOT EXISTS "drift_activity_sessions" '
      '(${columns.join(', ')}, PRIMARY KEY ("id"));';
}

String _trackPointsSql(int version) {
  final columns = [
    '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT',
    '"session_id" TEXT NOT NULL REFERENCES drift_activity_sessions (id) '
        'ON DELETE CASCADE',
    '"latitude" REAL NOT NULL',
    '"longitude" REAL NOT NULL',
    '"timestamp" INTEGER NOT NULL',
    '"accuracy" REAL NOT NULL',
    '"speed" REAL NOT NULL',
    if (version >= 4) '"altitude" REAL NOT NULL DEFAULT 0.0',
  ];
  return 'CREATE TABLE IF NOT EXISTS "drift_track_points" '
      '(${columns.join(', ')});';
}

// Drift stores DateTime as unix seconds by default.
const _start = 1760000000; // 2025-10-09 08:53:20 UTC
const _end = _start + 1800;

/// Statements that create a version [version] database holding a finished
/// run with a 3 point route (inserted out of time order) and a walk that
/// was still recording (no end time, no optional values).
List<String> _legacyDatabase(int version) {
  final runColumns = [
    'id, activity_type, start_time, end_time, total_distance_meters, '
        'total_duration_seconds, avg_pace_seconds_per_km, calories, steps',
    if (version >= 2) 'step_count_reliable',
    if (version >= 3) 'target_type, target_value, target_achieved',
    if (version >= 5) 'synced',
  ].join(', ');
  final runValues = [
    "'run', 'running', $_start, $_end, 5012.5, 1800, 359, 410, 5200",
    if (version >= 2) '0',
    if (version >= 3) "'distance', 5000.0, 1",
    if (version >= 5) '1',
  ].join(', ');

  String point(int second, double lat, {double altitude = 12.5}) {
    final altCol = version >= 4 ? ', altitude' : '';
    final altVal = version >= 4 ? ', $altitude' : '';
    return 'INSERT INTO drift_track_points '
        '(session_id, latitude, longitude, timestamp, accuracy, speed$altCol) '
        "VALUES ('run', $lat, 77.59, ${_start + second}, 4.0, 2.8$altVal);";
  }

  return [
    _sessionsSql(version),
    _trackPointsSql(version),
    'INSERT INTO drift_activity_sessions ($runColumns) VALUES ($runValues);',
    'INSERT INTO drift_activity_sessions (id, activity_type, start_time, '
        'end_time, total_distance_meters, total_duration_seconds, '
        'avg_pace_seconds_per_km, calories, steps) '
        "VALUES ('walk', 'walking', ${_start + 7200}, NULL, 0.0, 60, 0, 3, 90);",
    point(600, 12.972),
    point(0, 12.971),
    point(1200, 12.973),
    if (version >= 6)
      'CREATE INDEX IF NOT EXISTS idx_track_points_session '
          'ON drift_track_points (session_id);',
    'PRAGMA user_version = $version;',
  ];
}

/// Opens [file] with today's [AppDatabase]. On first open (user_version 0)
/// it first creates the database with [legacy] statements, as an older
/// release would have.
AppDatabase _open(File file, {List<String> legacy = const []}) =>
    AppDatabase.forTesting(
      NativeDatabase(
        file,
        setup: (raw) {
          if (raw.userVersion != 0) return;
          for (final statement in legacy) {
            raw.execute(statement);
          }
        },
      ),
    );

Future<List<Map<String, Object?>>> _rows(AppDatabase db, String sql) async =>
    (await db.customSelect(sql).get()).map((r) => r.data).toList();

/// Columns, foreign keys and indexes, in a form two databases can be
/// compared by.
Future<Map<String, Object?>> _schema(AppDatabase db) async {
  final schema = <String, Object?>{};
  for (final table in ['drift_activity_sessions', 'drift_track_points']) {
    schema['$table.columns'] = await _rows(db, 'PRAGMA table_info($table)');
    schema['$table.foreign_keys'] = await _rows(
      db,
      'PRAGMA foreign_key_list($table)',
    );
  }
  schema['indexes'] = await _rows(
    db,
    "SELECT name, tbl_name, sql FROM sqlite_master WHERE type = 'index' "
    "AND name NOT LIKE 'sqlite_autoindex%' ORDER BY name",
  );
  return schema;
}

void main() {
  late Directory tmp;

  // Each test compares against its own fresh in-memory database; they never
  // share an executor.
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('drift_migration_');
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  for (var version = 1; version <= 6; version++) {
    group('upgrade from v$version', () {
      late AppDatabase db;

      setUp(() async {
        db = _open(
          File('${tmp.path}/vital_up_v$version.sqlite'),
          legacy: _legacyDatabase(version),
        );
      });

      tearDown(() => db.close());

      test('keeps every workout and its values', () async {
        final sessions = await db.getAllSessions();
        expect(sessions.map((s) => s.id), ['walk', 'run']);

        final run = sessions.last;
        expect(run.activityType, 'running');
        expect(
          run.startTime.toUtc(),
          DateTime.fromMillisecondsSinceEpoch(_start * 1000, isUtc: true),
        );
        expect(
          run.endTime!.toUtc(),
          DateTime.fromMillisecondsSinceEpoch(_end * 1000, isUtc: true),
        );
        expect(run.totalDistanceMeters, 5012.5);
        expect(run.totalDurationSeconds, 1800);
        expect(run.avgPaceSecondsPerKm, 359);
        expect(run.calories, 410);
        expect(run.steps, 5200);
        // Saved values stay; columns this release didn't have get defaults.
        expect(run.stepCountReliable, version >= 2 ? isFalse : isTrue);
        expect(run.targetType, version >= 3 ? 'distance' : null);
        expect(run.targetValue, version >= 3 ? 5000.0 : null);
        expect(run.targetAchieved, version >= 3 ? isTrue : isFalse);
        expect(run.synced, version >= 5 ? isTrue : isFalse);
        expect(run.intensity, isNull);

        final walk = sessions.first;
        expect(walk.endTime, isNull);
        expect(walk.stepCountReliable, isTrue);
        expect(walk.targetType, isNull);
        expect(walk.targetAchieved, isFalse);
        expect(walk.synced, isFalse);
      });

      test('keeps the route in time order', () async {
        final points = await db.getTrackPointsForSession('run');
        expect(points.map((p) => p.latitude), [12.971, 12.972, 12.973]);
        expect(
          points.map((p) => p.altitude),
          everyElement(version >= 4 ? 12.5 : 0.0),
        );

        final grouped = await db.getTrackPointsBySession(['run', 'walk']);
        expect(grouped.keys, ['run']);
        expect(grouped['run']!.map((p) => p.latitude), [
          12.971,
          12.972,
          12.973,
        ]);
      });

      test('workouts saved before cloud backup get uploaded', () async {
        final unsynced = await db.unsyncedFinishedSessions();
        // The walk has no end time yet, so it's never uploaded as is.
        expect(unsynced.map((s) => s.id), version >= 5 ? isEmpty : ['run']);
      });

      test('ends with the same schema as a fresh install', () async {
        final fresh = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(fresh.close);
        expect(await _schema(db), await _schema(fresh));
        expect(await _rows(db, 'PRAGMA user_version'), [
          {'user_version': db.schemaVersion},
        ]);
      });

      test(
        'route index exists and deleting a workout drops its route',
        () async {
          final index = await _rows(
            db,
            "SELECT name FROM sqlite_master WHERE type = 'index' "
            "AND name = 'idx_track_points_session'",
          );
          expect(index, hasLength(1));

          expect(await _rows(db, 'PRAGMA foreign_keys'), [
            {'foreign_keys': 1},
          ]);
          expect(await _rows(db, 'PRAGMA foreign_key_check'), isEmpty);

          // A raw delete relies on the cascade, not deleteSession's own cleanup.
          await db.customStatement(
            "DELETE FROM drift_activity_sessions WHERE id = 'run'",
          );
          expect(await _rows(db, 'SELECT id FROM drift_track_points'), isEmpty);
          expect((await db.getAllSessions()).map((s) => s.id), ['walk']);
        },
      );

      test('the upgraded database accepts new workouts', () async {
        await db.saveSessionWithPoints(
          DriftActivitySessionsCompanion.insert(
            id: 'new',
            activityType: 'cycling',
            startTime: DateTime.utc(2026, 10, 18, 7),
            endTime: Value(DateTime.utc(2026, 10, 18, 8)),
            totalDistanceMeters: 20000,
            totalDurationSeconds: 3600,
            avgPaceSecondsPerKm: 180,
            calories: 600,
            steps: 0,
          ),
          [
            DriftTrackPointsCompanion.insert(
              sessionId: 'new',
              latitude: 1,
              longitude: 2,
              timestamp: DateTime.utc(2026, 10, 18, 7),
              accuracy: 5,
              speed: 6,
            ),
          ],
        );
        final saved = await db.getSession('new');
        expect(saved!.synced, isFalse);
        expect(await db.getTrackPointsForSession('new'), hasLength(1));
      });
    });
  }

  test('reopening a current database changes nothing', () async {
    final file = File('${tmp.path}/vital_up_v6.sqlite');
    var db = _open(file);
    await db.saveSessionWithPoints(
      DriftActivitySessionsCompanion.insert(
        id: 'run',
        activityType: 'running',
        startTime: DateTime.utc(2026, 10, 18, 6),
        endTime: Value(DateTime.utc(2026, 10, 18, 7)),
        totalDistanceMeters: 10000,
        totalDurationSeconds: 3600,
        avgPaceSecondsPerKm: 360,
        calories: 700,
        steps: 9000,
      ),
      [
        DriftTrackPointsCompanion.insert(
          sessionId: 'run',
          latitude: 1,
          longitude: 2,
          timestamp: DateTime.utc(2026, 10, 18, 6),
          accuracy: 5,
          speed: 3,
          altitude: const Value(40),
        ),
      ],
    );
    final before = await _schema(db);
    await db.close();

    db = _open(file);
    addTearDown(db.close);
    expect(await _schema(db), before);
    final sessions = await db.getAllSessions();
    expect(sessions.single.id, 'run');
    expect(sessions.single.synced, isFalse);
    expect((await db.getTrackPointsForSession('run')).single.altitude, 40);
  });

  test('a database from a newer release keeps its data', () async {
    // E.g. after rolling back a Shorebird patch or installing an older
    // build: drift calls onUpgrade(7, 6), which must not touch anything.
    final file = File('${tmp.path}/vital_up_v7.sqlite');
    final db = _open(
      file,
      legacy: [
        ..._legacyDatabase(5).where((s) => !s.startsWith('PRAGMA')),
        'CREATE INDEX IF NOT EXISTS idx_track_points_session '
            'ON drift_track_points (session_id)',
        'PRAGMA user_version = 7;',
      ],
    );
    addTearDown(db.close);

    expect((await db.getAllSessions()).map((s) => s.id), ['walk', 'run']);
    expect(await db.getTrackPointsForSession('run'), hasLength(3));
  });
}
