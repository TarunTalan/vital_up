import 'package:equatable/equatable.dart';
import '../../domain/entities/sleep_session_info.dart';

abstract class SleepState extends Equatable {
  const SleepState();

  @override
  List<Object?> get props => [];
}

class SleepInitial extends SleepState {}

class SleepLoading extends SleepState {}

class SleepLoadedAuto extends SleepState {
  final SleepSessionInfo session;

  const SleepLoadedAuto(this.session);

  @override
  List<Object?> get props => [session];
}

class SleepLoadedManual extends SleepState {
  final SleepSessionInfo session;

  const SleepLoadedManual(this.session);

  @override
  List<Object?> get props => [session];
}

/// Nothing for last night yet. [canDetect] is false when usage access (for
/// estimating sleep from screen time) could be turned on.
class SleepNeedsManualEntry extends SleepState {
  final bool canDetect;

  const SleepNeedsManualEntry({this.canDetect = true});

  @override
  List<Object?> get props => [canDetect];
}

/// Last night estimated from screen-off time, waiting for the user to
/// confirm or adjust it.
class SleepNeedsConfirmation extends SleepState {
  final SleepSessionInfo estimate;

  const SleepNeedsConfirmation(this.estimate);

  @override
  List<Object?> get props => [estimate];
}

/// The user tapped "Going to bed" at [since] and hasn't said "I'm up" yet.
class SleepInBed extends SleepState {
  final DateTime since;

  const SleepInBed(this.since);

  @override
  List<Object?> get props => [since];
}

class SleepNeedsHealthConnectInstall extends SleepState {}

class SleepError extends SleepState {
  final String message;
  final bool isPermissionDenied;

  const SleepError(this.message, {this.isPermissionDenied = false});

  @override
  List<Object?> get props => [message, isPermissionDenied];
}
