import 'package:equatable/equatable.dart';
import 'package:vital_up/core/database/collections/water_log_cache.dart';

abstract class WaterIntakeState extends Equatable {
  const WaterIntakeState();

  @override
  List<Object?> get props => [];
}

class WaterIntakeInitial extends WaterIntakeState {}

class WaterIntakeLoading extends WaterIntakeState {}

class WaterIntakeLoaded extends WaterIntakeState {
  final int currentIntakeMl;
  final int dailyGoalMl;
  final List<WaterLogCache> todayLogs;

  /// Set only on the state right after a drink was saved (for the Undo
  /// snackbar); reloads and other updates leave it null.
  final int? addedMl;

  /// One-off message for the user (an add or undo that failed).
  final String? notice;

  const WaterIntakeLoaded({
    required this.currentIntakeMl,
    required this.dailyGoalMl,
    required this.todayLogs,
    this.addedMl,
    this.notice,
  });

  @override
  List<Object?> get props => [
    currentIntakeMl,
    dailyGoalMl,
    todayLogs,
    addedMl,
    notice,
  ];
}

class WaterIntakeError extends WaterIntakeState {
  final String message;

  const WaterIntakeError(this.message);

  @override
  List<Object?> get props => [message];
}
