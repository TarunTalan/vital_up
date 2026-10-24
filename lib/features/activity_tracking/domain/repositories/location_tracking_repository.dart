import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/track_point.dart';

abstract class LocationTrackingRepository {
  Future<bool> hasPermission();

  Stream<TrackPoint> watchTrackPoints(ActivityType activityType);
}
