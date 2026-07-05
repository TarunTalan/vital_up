import 'package:equatable/equatable.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/track_point.dart';

enum TrackingStatus {
  idle,
  starting,
  inProgress,
  paused,
  completed,
  permissionDenied,
  failure,
}

class ActivityTrackingState extends Equatable {
  final TrackingStatus status;
  final ActivityType activityType;
  final Duration elapsed;
  final double distanceMeters;
  final int calories;
  final int steps;
  final int avgPaceSecondsPerKm;
  final int currentPaceSecondsPerKm;
  final double currentSpeedMetersPerSecond;
  final List<TrackPoint> routePoints;
  final String? message;
  final bool controlsLocked;

  const ActivityTrackingState({
    required this.status,
    required this.activityType,
    required this.elapsed,
    required this.distanceMeters,
    required this.calories,
    required this.steps,
    required this.avgPaceSecondsPerKm,
    required this.currentPaceSecondsPerKm,
    required this.currentSpeedMetersPerSecond,
    required this.routePoints,
    this.message,
    this.controlsLocked = false,
  });

  factory ActivityTrackingState.initial() {
    return const ActivityTrackingState(
      status: TrackingStatus.idle,
      activityType: ActivityType.walk,
      elapsed: Duration.zero,
      distanceMeters: 0,
      calories: 0,
      steps: 0,
      avgPaceSecondsPerKm: 0,
      currentPaceSecondsPerKm: 0,
      currentSpeedMetersPerSecond: 0,
      routePoints: [],
      controlsLocked: false,
    );
  }

  ActivityTrackingState copyWith({
    TrackingStatus? status,
    ActivityType? activityType,
    Duration? elapsed,
    double? distanceMeters,
    int? calories,
    int? steps,
    int? avgPaceSecondsPerKm,
    int? currentPaceSecondsPerKm,
    double? currentSpeedMetersPerSecond,
    List<TrackPoint>? routePoints,
    String? message,
    bool? controlsLocked,
  }) {
    return ActivityTrackingState(
      status: status ?? this.status,
      activityType: activityType ?? this.activityType,
      elapsed: elapsed ?? this.elapsed,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      calories: calories ?? this.calories,
      steps: steps ?? this.steps,
      avgPaceSecondsPerKm: avgPaceSecondsPerKm ?? this.avgPaceSecondsPerKm,
      currentPaceSecondsPerKm: currentPaceSecondsPerKm ?? this.currentPaceSecondsPerKm,
      currentSpeedMetersPerSecond:
          currentSpeedMetersPerSecond ?? this.currentSpeedMetersPerSecond,
      routePoints: routePoints ?? this.routePoints,
      message: message,
      controlsLocked: controlsLocked ?? this.controlsLocked,
    );
  }

  bool get isActive => status == TrackingStatus.inProgress;

  bool get isPaused => status == TrackingStatus.paused;

  @override
  List<Object?> get props => [
        status,
        activityType,
        elapsed,
        distanceMeters,
        calories,
        steps,
        avgPaceSecondsPerKm,
        currentPaceSecondsPerKm,
        currentSpeedMetersPerSecond,
        routePoints,
        message,
        controlsLocked,
      ];
}
