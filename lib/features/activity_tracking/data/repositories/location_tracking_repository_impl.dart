import 'dart:async';
import 'dart:math';

import 'package:geolocator/geolocator.dart' hide ActivityType;
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/track_point.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/location_tracking_repository.dart';

class LocationTrackingRepositoryImpl implements LocationTrackingRepository {
  static const double maxAccuracyMeters = 15.0;
  static const double smoothingWeight = 0.6;

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

  @override
  Stream<TrackPoint> watchTrackPoints(ActivityType activityType) {
    TrackPoint? lastAccepted;
    TrackPoint? lastSmoothed;

    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 2,
    );

    return Geolocator.getPositionStream(locationSettings: settings)
        .map((position) => TrackPoint(
              latitude: position.latitude,
              longitude: position.longitude,
              timestamp: position.timestamp ?? DateTime.now(),
              accuracy: position.accuracy,
              speed: position.speed.isFinite ? position.speed : 0,
              altitude: position.altitude.isFinite ? position.altitude : 0,
            ))
        .where((point) => point.accuracy <= maxAccuracyMeters)
        .map((point) {
      final previous = lastSmoothed;
      if (previous == null) {
        lastSmoothed = point;
        return point;
      }

      final smoothed = TrackPoint(
        latitude: previous.latitude * smoothingWeight +
            point.latitude * (1 - smoothingWeight),
        longitude: previous.longitude * smoothingWeight +
            point.longitude * (1 - smoothingWeight),
        altitude: previous.altitude * smoothingWeight +
            point.altitude * (1 - smoothingWeight),
        timestamp: point.timestamp,
        accuracy: point.accuracy,
        speed: point.speed,
      );
      lastSmoothed = smoothed;
      return smoothed;
    }).where((point) {
      final previous = lastAccepted;
      if (previous == null) {
        lastAccepted = point;
        return true;
      }

      final elapsedSeconds =
          point.timestamp.difference(previous.timestamp).inMilliseconds / 1000;
      if (elapsedSeconds <= 0) return false;

      final distance = haversineMeters(previous, point);
      final impliedSpeed = distance / elapsedSeconds;
      if (impliedSpeed > activityType.maxReasonableSpeedMetersPerSecond) {
        return false;
      }

      if (distance < 1.0 && point.speed < 0.5) {
        return false;
      }

      lastAccepted = point;
      return true;
    });
  }
}

double haversineMeters(TrackPoint a, TrackPoint b) {
  const earthRadiusMeters = 6371000.0;
  final dLat = _degreesToRadians(b.latitude - a.latitude);
  final dLng = _degreesToRadians(b.longitude - a.longitude);
  final lat1 = _degreesToRadians(a.latitude);
  final lat2 = _degreesToRadians(b.latitude);

  final h = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
  final horizontalDistance = earthRadiusMeters * 2 * atan2(sqrt(h), sqrt(1 - h));
  
  // Add vertical distance (altitude change) for 3D distance
  final verticalDistance = (b.altitude - a.altitude).abs();
  
  return sqrt(horizontalDistance * horizontalDistance + verticalDistance * verticalDistance);
}

double _degreesToRadians(double degrees) => degrees * pi / 180.0;
