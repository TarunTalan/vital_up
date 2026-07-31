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

  const TrackingInProgress({
    required super.activityType,
    required this.elapsed,
    required this.distanceMeters,
    required this.avgPaceSecondsPerKm,
    required this.calories,
    required this.steps,
    required this.stepCountReliable,
    required this.routePoints,
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

  const TrackingPaused({
    required super.activityType,
    required this.elapsed,
    required this.distanceMeters,
    required this.avgPaceSecondsPerKm,
    required this.calories,
    required this.steps,
    required this.stepCountReliable,
    required this.routePoints,
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
      ];
}

class TrackingCompleted extends ActivityTrackingState {
  final ActivitySession session;

  const TrackingCompleted({
    required super.activityType,
    required this.session,
  });

  @override
  List<Object?> get props => [activityType, session];
}

class TrackingPermissionDenied extends ActivityTrackingState {
  final String message;

  const TrackingPermissionDenied(this.message, {super.activityType = ActivityType.walk});

  @override
  List<Object?> get props => [activityType, message];
}
