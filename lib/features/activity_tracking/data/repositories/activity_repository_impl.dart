import 'package:drift/drift.dart' show Value;
import 'package:vital_up/core/database/drift_database.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/track_point.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/activity_repository.dart';
import 'package:vital_up/core/sync/sync_hooks.dart';
import 'package:vital_up/core/events/habit_events.dart';

class ActivityRepositoryImpl implements ActivityRepository {
  final AppDatabase database;
  final SyncHooks? sync;
  final HabitEvents? events;

  ActivityRepositoryImpl(this.database, [this.sync, this.events]);

  @override
  Future<void> saveSession(ActivitySession session) async {
    final dbSession = DriftActivitySessionsCompanion.insert(
      id: session.id,
      activityType: session.activityType.name,
      startTime: session.startTime,
      endTime: Value(session.endTime),
      totalDistanceMeters: session.totalDistanceMeters,
      totalDurationSeconds: session.totalDurationSeconds,
      avgPaceSecondsPerKm: session.avgPaceSecondsPerKm,
      calories: session.calories,
      steps: session.steps,
      stepCountReliable: Value(session.stepCountReliable),
      targetType: Value(session.targetType),
      targetValue: Value(session.targetValue),
      targetAchieved: Value(session.targetAchieved),
    );

    final dbPoints = session.points.map((p) => DriftTrackPointsCompanion.insert(
      sessionId: session.id,
      latitude: p.latitude,
      longitude: p.longitude,
      timestamp: p.timestamp,
      accuracy: p.accuracy,
      speed: p.speed,
      altitude: Value(p.altitude),
    )).toList();

    await database.saveSessionWithPoints(dbSession, dbPoints);
    // Checkpoints of a workout still recording aren't uploaded.
    if (session.endTime != null) {
      sync?.schedule();
      events?.logged(const HabitLogged(Habit.activity));
    }
  }

  @override
  Future<List<ActivitySession>> getSessions() async {
    final dbSessions = await database.getAllSessions();
    final pointsBySession = await database.getAllTrackPointsBySession();

    return dbSessions
        .map((s) => _toEntity(s, pointsBySession[s.id] ?? const []))
        .toList();
  }

  @override
  Future<ActivitySession?> getSessionById(String id) async {
    final s = await database.getSession(id);
    if (s == null) return null;

    final dbPoints = await database.getTrackPointsForSession(s.id);
    return _toEntity(s, dbPoints);
  }

  @override
  Future<void> deleteSession(String id) async {
    final wasSynced = (await database.getSession(id))?.synced ?? false;
    await database.deleteSession(id);
    if (wasSynced) await sync?.recordDelete('activity_sessions', id);
  }

  @override
  Future<void> finalizeInterruptedSessions() {
    return database.finalizeInterruptedSessions();
  }

  ActivitySession _toEntity(
    DriftActivitySession s,
    List<DriftTrackPoint> dbPoints,
  ) {
    final points = dbPoints.map((p) => TrackPoint(
      latitude: p.latitude,
      longitude: p.longitude,
      timestamp: p.timestamp,
      accuracy: p.accuracy,
      speed: p.speed,
      altitude: p.altitude,
    )).toList();

    return ActivitySession(
      id: s.id,
      activityType: ActivityType.values.firstWhere((e) => e.name == s.activityType, orElse: () => ActivityType.walk),
      startTime: s.startTime,
      endTime: s.endTime,
      totalDistanceMeters: s.totalDistanceMeters,
      totalDurationSeconds: s.totalDurationSeconds,
      avgPaceSecondsPerKm: s.avgPaceSecondsPerKm,
      calories: s.calories,
      steps: s.steps,
      stepCountReliable: s.stepCountReliable,
      points: points,
      targetType: s.targetType,
      targetValue: s.targetValue,
      targetAchieved: s.targetAchieved ?? false,
    );
  }
}
