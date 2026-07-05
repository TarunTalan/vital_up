import 'package:drift/drift.dart' show Value;
import 'package:vital_up/core/database/drift_database.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/track_point.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/activity_repository.dart';

class ActivityRepositoryImpl implements ActivityRepository {
  final AppDatabase database;

  ActivityRepositoryImpl(this.database);

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
    );
    await database.saveSessionCompanion(dbSession);

    final dbPoints = session.points.map((p) => DriftTrackPointsCompanion.insert(
      sessionId: session.id,
      latitude: p.latitude,
      longitude: p.longitude,
      timestamp: p.timestamp,
      accuracy: p.accuracy,
      speed: p.speed,
    )).toList();

    await database.replaceTrackPointsForSession(session.id, dbPoints);
  }

  @override
  Future<List<ActivitySession>> getSessions() async {
    final dbSessions = await database.getAllSessions();
    final List<ActivitySession> sessions = [];

    for (final s in dbSessions) {
      final dbPoints = await database.getTrackPointsForSession(s.id);
      final points = dbPoints.map((p) => TrackPoint(
        latitude: p.latitude,
        longitude: p.longitude,
        timestamp: p.timestamp,
        accuracy: p.accuracy,
        speed: p.speed,
        altitude: 0.0,
      )).toList();

      sessions.add(ActivitySession(
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
      ));
    }

    return sessions;
  }

  @override
  Future<ActivitySession?> getSessionById(String id) async {
    final s = await database.getSession(id);
    if (s == null) return null;

    final dbPoints = await database.getTrackPointsForSession(s.id);
    final points = dbPoints.map((p) => TrackPoint(
      latitude: p.latitude,
      longitude: p.longitude,
      timestamp: p.timestamp,
      accuracy: p.accuracy,
      speed: p.speed,
      altitude: 0.0,
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
    );
  }

  @override
  Future<void> deleteSession(String id) async {
    await database.deleteSession(id);
  }
}
