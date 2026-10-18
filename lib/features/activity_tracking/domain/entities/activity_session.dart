import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/workout_intensity.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/track_point.dart';

class ActivitySession {
  final String id;
  final ActivityType activityType;
  final DateTime startTime;
  final DateTime? endTime;
  final double totalDistanceMeters;
  final int totalDurationSeconds;
  final int avgPaceSecondsPerKm;
  final int calories;
  final int steps;
  final bool stepCountReliable;
  final List<TrackPoint> points;

  /// Target set for this session: 'distance', 'calories', or null (no target).
  final String? targetType;

  /// Target value in km (distance) or kcal (calories), or null if no target.
  final double? targetValue;

  /// Whether the target was achieved during this session.
  final bool targetAchieved;

  /// How hard a workout without a route was; null for GPS sessions.
  final WorkoutIntensity? intensity;

  /// Whether distance and pace mean anything: GPS activities, and workouts
  /// that came with a distance (a watch's swim).
  bool get hasDistance =>
      activityType.isGpsBased || totalDistanceMeters > 0;

  const ActivitySession({
    required this.id,
    required this.activityType,
    required this.startTime,
    required this.endTime,
    required this.totalDistanceMeters,
    required this.totalDurationSeconds,
    required this.avgPaceSecondsPerKm,
    required this.calories,
    required this.steps,
    required this.stepCountReliable,
    required this.points,
    this.targetType,
    this.targetValue,
    this.targetAchieved = false,
    this.intensity,
  });
}
