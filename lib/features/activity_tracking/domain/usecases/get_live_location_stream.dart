import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/track_point.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/location_tracking_repository.dart';

class GetLiveLocationStream {
  final LocationTrackingRepository repository;

  const GetLiveLocationStream(this.repository);

  Future<bool> ensurePermission() {
    return repository.ensurePermission();
  }

  Stream<TrackPoint> call(ActivityType activityType) {
    return repository.watchTrackPoints(activityType);
  }
}
