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

class SleepNeedsManualEntry extends SleepState {}

class SleepNeedsHealthConnectInstall extends SleepState {}

class SleepError extends SleepState {
  final String message;
  final bool isPermissionDenied;

  const SleepError(this.message, {this.isPermissionDenied = false});

  @override
  List<Object?> get props => [message, isPermissionDenied];
}
