import 'package:vital_up/features/activity_tracking/domain/repositories/step_counter_repository.dart';

class GetLiveStepsStream {
  final StepCounterRepository repository;

  const GetLiveStepsStream(this.repository);

  Future<bool> hasPermission() {
    return repository.hasPermission();
  }

  Stream<int> call() {
    return repository.watchSteps();
  }
}
