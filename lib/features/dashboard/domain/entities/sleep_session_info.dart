import 'package:equatable/equatable.dart';

enum SleepDataSource { healthStore, manual }

class SleepSessionInfo extends Equatable {
  final DateTime bedTime;
  final DateTime wakeTime;
  final Duration duration;
  final SleepDataSource source;

  const SleepSessionInfo({
    required this.bedTime,
    required this.wakeTime,
    required this.duration,
    required this.source,
  });

  @override
  List<Object?> get props => [bedTime, wakeTime, duration, source];
}
