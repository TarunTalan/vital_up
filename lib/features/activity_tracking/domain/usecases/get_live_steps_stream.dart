import 'package:vital_up/features/activity_tracking/domain/repositories/step_counter_repository.dart';

class GetLiveStepsStream {
  final StepCounterRepository repository;

  const GetLiveStepsStream(this.repository);

  Future<bool> ensurePermission() {
    return repository.ensurePermission();
  }

  Stream<int> call() {
    return repository.watchSteps();
  }
}
