import 'package:pedometer/pedometer.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/step_counter_repository.dart';

class StepCounterRepositoryImpl implements StepCounterRepository {
  int? _baseline;
  int _lastValidSteps = 0;
  DateTime? _lastStepTime;
  
  @override
  Stream<int> watchSteps() {
    return Pedometer.stepCountStream.map((event) {
      _baseline ??= event.steps;
      final rawSteps = event.steps - _baseline!;
      
      // Validate step count is reasonable
      final now = DateTime.now();
      final lastTime = _lastStepTime;
      
      if (lastTime != null) {
        final timeDiff = now.difference(lastTime).inSeconds;
        final stepDiff = rawSteps - _lastValidSteps;
        
        // Check for unrealistic step rates (> 5 steps per second)
        if (timeDiff > 0 && stepDiff / timeDiff > 5) {
          // Step rate too high, likely sensor error - return last valid
          return _lastValidSteps;
        }
        
        // Check for negative step count (shouldn't happen)
        if (rawSteps < _lastValidSteps) {
          return _lastValidSteps;
        }
      }
      
      _lastStepTime = now;
      _lastValidSteps = rawSteps;
      return rawSteps;
    }).handleError((_) => _lastValidSteps);
  }
}
