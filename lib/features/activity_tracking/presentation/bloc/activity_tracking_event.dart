import 'package:equatable/equatable.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
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

class PauseTracking extends ActivityTrackingEvent {}

class ResumeTracking extends ActivityTrackingEvent {}

class StopAndSaveTracking extends ActivityTrackingEvent {}

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
