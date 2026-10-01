import 'dart:io';

import 'package:geolocator/geolocator.dart' hide ActivityType;
import 'package:geolocator/geolocator.dart' as geo show ActivityType;
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/track_point.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/location_tracking_repository.dart';
import 'package:vital_up/features/activity_tracking/domain/services/track_point_filter.dart';

class LocationTrackingRepositoryImpl implements LocationTrackingRepository {
  @override
  Future<bool> ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Settings for a workout recording stream.
  ///
  /// geolocator keeps ONE native position stream per app and hands every
  /// later caller the cached stream, ignoring their settings. Anything else
  /// that listens to positions (e.g. the map preview) must therefore be
  /// cancelled before a workout subscribes, or the workout silently records
  /// with the other caller's settings.
  static LocationSettings workoutSettings() {
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: geo.ActivityType.fitness,
        distanceFilter: 1,
        allowBackgroundLocationUpdates: true,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    }
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
        intervalDuration: const Duration(seconds: 1),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'VitalUp Active Workout',
          notificationText: 'Tracking your workout in the background',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 1,
    );
  }

  @override
  Stream<TrackPoint> watchTrackPoints(ActivityType activityType) {
    final filter = TrackPointFilter(activityType);

    return Geolocator.getPositionStream(locationSettings: workoutSettings())
        .map((position) => TrackPoint(
              latitude: position.latitude,
              longitude: position.longitude,
              timestamp: position.timestamp,
              accuracy: position.accuracy,
              speed: position.speed.isFinite && position.speed >= 0
                  ? position.speed
                  : 0.0,
              altitude: position.altitude.isFinite ? position.altitude : 0.0,
            ))
        .map(filter.process)
        .where((point) => point != null)
        .cast<TrackPoint>();
  }
}
