import 'package:vital_up/features/activity_tracking/domain/repositories/step_counter_repository.dart';

class GetLiveStepsStream {
  final StepCounterRepository repository;

  const GetLiveStepsStream(this.repository);

  Stream<int> call() {
    return repository.watchSteps();
  }
}
