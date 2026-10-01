abstract class StepCounterRepository {
  /// Asks for the motion / activity-recognition permission the step sensor
  /// needs. Returns false if steps can't be counted on this device.
  Future<bool> ensurePermission();

  /// Steps taken since this stream was subscribed to. Each call starts a
  /// fresh count from zero.
  Stream<int> watchSteps();
}
