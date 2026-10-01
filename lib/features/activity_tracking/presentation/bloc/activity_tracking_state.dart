import 'package:equatable/equatable.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/track_point.dart';

abstract class ActivityTrackingState extends Equatable {
  final ActivityType activityType;

  const ActivityTrackingState({required this.activityType});

  @override
  List<Object?> get props => [activityType];
}

class TrackingIdle extends ActivityTrackingState {
  const TrackingIdle({super.activityType = ActivityType.walk});
}

class TrackingInProgress extends ActivityTrackingState {
  final Duration elapsed;
  final double distanceMeters;
  final int avgPaceSecondsPerKm; // Rolling pace or average pace
  final int calories;
  final int steps;
  final bool stepCountReliable;
  final List<TrackPoint> routePoints;

  /// Cumulative climb in meters, with GPS altitude noise filtered out.
  final double elevationGainMeters;

  /// Current Doppler speed in m/s; drops to 0 when fixes stop arriving.
  final double currentSpeedMps;

  const TrackingInProgress({
    required super.activityType,
    required this.elapsed,
    required this.distanceMeters,
    required this.avgPaceSecondsPerKm,
    required this.calories,
    required this.steps,
    required this.stepCountReliable,
    required this.routePoints,
    this.elevationGainMeters = 0.0,
    this.currentSpeedMps = 0.0,
  });

  @override
  List<Object?> get props => [
        activityType,
        elapsed,
        distanceMeters,
        avgPaceSecondsPerKm,
        calories,
        steps,
        stepCountReliable,
        routePoints,
        elevationGainMeters,
        currentSpeedMps,
      ];
}

class TrackingPaused extends ActivityTrackingState {
  final Duration elapsed;
  final double distanceMeters;
  final int avgPaceSecondsPerKm;
  final int calories;
  final int steps;
  final bool stepCountReliable;
  final List<TrackPoint> routePoints;

  /// Cumulative climb in meters, with GPS altitude noise filtered out.
  final double elevationGainMeters;

  /// Current Doppler speed in m/s; drops to 0 when fixes stop arriving.
  final double currentSpeedMps;

  const TrackingPaused({
    required super.activityType,
    required this.elapsed,
    required this.distanceMeters,
    required this.avgPaceSecondsPerKm,
    required this.calories,
    required this.steps,
    required this.stepCountReliable,
    required this.routePoints,
    this.elevationGainMeters = 0.0,
    this.currentSpeedMps = 0.0,
  });

  @override
  List<Object?> get props => [
        activityType,
        elapsed,
        distanceMeters,
        avgPaceSecondsPerKm,
        calories,
        steps,
        stepCountReliable,
        routePoints,
        elevationGainMeters,
        currentSpeedMps,
      ];
}

class TrackingCompleted extends ActivityTrackingState {
  final ActivitySession session;
  final double elevationGainMeters;

  /// False when writing the session to the local database failed.
  final bool saved;

  const TrackingCompleted({
    required super.activityType,
    required this.session,
    this.elevationGainMeters = 0.0,
    this.saved = true,
  });

  @override
  List<Object?> get props => [activityType, session, elevationGainMeters, saved];
}

class TrackingPermissionDenied extends ActivityTrackingState {
  final String message;

  const TrackingPermissionDenied(this.message, {super.activityType = ActivityType.walk});

  @override
  List<Object?> get props => [activityType, message];
}
