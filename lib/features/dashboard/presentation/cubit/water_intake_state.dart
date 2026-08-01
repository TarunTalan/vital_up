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

  const WaterIntakeLoaded({
    required this.currentIntakeMl,
    required this.dailyGoalMl,
    required this.todayLogs,
  });

  @override
  List<Object?> get props => [currentIntakeMl, dailyGoalMl, todayLogs];
}

class WaterIntakeError extends WaterIntakeState {
  final String message;

  const WaterIntakeError(this.message);

  @override
  List<Object?> get props => [message];
}
