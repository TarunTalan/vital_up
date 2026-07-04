import 'package:pedometer/pedometer.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/step_counter_repository.dart';

class StepCounterRepositoryImpl implements StepCounterRepository {
  @override
  Stream<int> watchSteps() {
    int? baseline;

    return Pedometer.stepCountStream.map((event) {
      baseline ??= event.steps;
      return event.steps - baseline!;
    }).handleError((_) {});
  }
}
