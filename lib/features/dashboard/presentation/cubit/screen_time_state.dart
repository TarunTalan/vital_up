import 'package:equatable/equatable.dart';
import '../../domain/entities/app_usage_info.dart';

abstract class ScreenTimeState extends Equatable {
  const ScreenTimeState();

  @override
  List<Object?> get props => [];
}

class ScreenTimeInitial extends ScreenTimeState {}

class ScreenTimeLoading extends ScreenTimeState {}

class ScreenTimePermissionDenied extends ScreenTimeState {}

class ScreenTimeLoaded extends ScreenTimeState {
  final List<AppUsageInfo> usageStats;
  final Duration totalDuration;
  final ScreenTimeWeeklySummary? weeklySummary;

  const ScreenTimeLoaded({
    required this.usageStats,
    required this.totalDuration,
    this.weeklySummary,
  });

  @override
  List<Object?> get props => [usageStats, totalDuration, weeklySummary];
}

class ScreenTimeError extends ScreenTimeState {
  final String message;

  const ScreenTimeError(this.message);

  @override
  List<Object?> get props => [message];
}
