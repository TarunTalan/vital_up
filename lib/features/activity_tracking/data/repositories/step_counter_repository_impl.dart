import 'dart:io';

import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/step_counter_repository.dart';

class StepCounterRepositoryImpl implements StepCounterRepository {
  /// Faster than any human cadence (~300 spm); bursts above this are sensor
  /// glitches rather than steps.
  static const double _maxStepsPerSecond = 5.0;

  /// Rate is only judged over at least this window, so the sensor's normal
  /// batching (several steps delivered at once) isn't mistaken for a glitch.
  static const Duration _minRateWindow = Duration(seconds: 2);

  @override
  Future<bool> ensurePermission() async {
    // Android 10+ gates the step sensor behind ACTIVITY_RECOGNITION. iOS
    // prompts for Motion & Fitness itself when the pedometer starts.
    if (!Platform.isAndroid) return true;
    try {
      final status = await Permission.activityRecognition.request();
      return status.isGranted || status.isLimited;
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<int> watchSteps() {
    // State lives per subscription: the repository is a singleton, and a
    // baseline shared across sessions would carry the previous workout's
    // steps into the next one.
    //
    // Both platforms report steps cumulative since boot, so the first
    // reading becomes the baseline.
    int? baseline;
    var lastValidSteps = 0;
    var anchorSteps = 0;
    DateTime? anchorAt;

    return Pedometer.stepCountStream.map((event) {
      // The counter resets on reboot, so a reading below the baseline
      // re-anchors instead of going negative.
      if (baseline == null || event.steps < baseline!) {
        baseline = event.steps - lastValidSteps;
      }
      final steps = event.steps - baseline!;
      if (steps < lastValidSteps) return lastValidSteps;

      final now = DateTime.now();
      final since = anchorAt;
      if (since == null) {
        anchorAt = now;
        anchorSteps = steps;
      } else {
        final seconds = now.difference(since).inMilliseconds / 1000.0;
        final added = steps - anchorSteps;
        if (seconds >= _minRateWindow.inSeconds) {
          if (added / seconds > _maxStepsPerSecond) return lastValidSteps;
          anchorAt = now;
          anchorSteps = steps;
        } else if (added > _maxStepsPerSecond * _minRateWindow.inSeconds) {
          return lastValidSteps;
        }
      }

      lastValidSteps = steps;
      return steps;
    });
  }
}
