import 'package:vital_up/features/activity_tracking/domain/repositories/location_tracking_repository.dart';

class StartTrackingSession {
  final LocationTrackingRepository repository;

  StartTrackingSession(this.repository);

  Future<bool> call() {
    return repository.ensurePermission();
  }
}
