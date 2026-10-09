import 'package:equatable/equatable.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/services/workout_checkpoint.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/track_point.dart';

abstract class ActivityTrackingEvent extends Equatable {
  const ActivityTrackingEvent();

  @override
  List<Object?> get props => [];
}

class SelectActivityType extends ActivityTrackingEvent {
  final ActivityType activityType;

  const SelectActivityType(this.activityType);

  @override
  List<Object?> get props => [activityType];
}

class StartTracking extends ActivityTrackingEvent {}

/// Carries on [session], a workout the app was killed in the middle of.
class RestoreTracking extends ActivityTrackingEvent {
  final WorkoutCheckpoint checkpoint;
  final ActivitySession session;

  const RestoreTracking({required this.checkpoint, required this.session});

  @override
  List<Object?> get props => [checkpoint.sessionId, checkpoint.savedAt];
}

class PauseTracking extends ActivityTrackingEvent {}

class ResumeTracking extends ActivityTrackingEvent {}

class StopAndSaveTracking extends ActivityTrackingEvent {
  /// The target type active for this session ('distance', 'calories', or null).
  final String? targetType;

  /// The target value in km or kcal.
  final double? targetValue;

  /// Whether the target was achieved.
  final bool targetAchieved;

  const StopAndSaveTracking({
    this.targetType,
    this.targetValue,
    this.targetAchieved = false,
  });

  @override
  List<Object?> get props => [targetType, targetValue, targetAchieved];
}

class UpdateTrackPoint extends ActivityTrackingEvent {
  final TrackPoint point;

  const UpdateTrackPoint(this.point);

  @override
  List<Object?> get props => [point];
}

class UpdateSteps extends ActivityTrackingEvent {
  final int steps;

  const UpdateSteps(this.steps);

  @override
  List<Object?> get props => [steps];
}

class TickTimer extends ActivityTrackingEvent {}

class ResetTracking extends ActivityTrackingEvent {}

/// Writes a checkpoint of the running workout now (e.g. when the app is
/// backgrounded), so an OS kill loses as little as possible.
class PersistProgress extends ActivityTrackingEvent {}
