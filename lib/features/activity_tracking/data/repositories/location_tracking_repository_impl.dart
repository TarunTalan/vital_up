import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:geolocator/geolocator.dart' hide ActivityType;
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/track_point.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/location_tracking_repository.dart';

class LocationTrackingRepositoryImpl implements LocationTrackingRepository {
  /// Maximum horizontal accuracy we accept for a GPS fix.
  /// 25 m allows most urban rooftop-occlusion scenarios while still being reliable.
  static const double _maxAccuracyMeters = 25.0;

  /// EMA smoothing coefficient for walking only (0 = fully raw, 1 = fully previous).
  /// Applied to lat/lon to reduce GPS jitter at low speeds.
  static const double _walkSmoothWeight = 0.55;

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

    final LocationSettings settings;
    if (Platform.isIOS) {
      settings = AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
        allowBackgroundLocationUpdates: true,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    } else if (Platform.isAndroid) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'VitalUp Active Workout',
          notificationText: 'Tracking your workout in the background',
          enableWakeLock: true,
        ),
      );
    } else {
      settings = const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
      );
    }

    return Geolocator.getPositionStream(locationSettings: settings)
        // Step 1 — Map raw position to TrackPoint
        .map((position) => TrackPoint(
              latitude: position.latitude,
              longitude: position.longitude,
              timestamp: position.timestamp ?? DateTime.now(),
              accuracy: position.accuracy,
              speed: position.speed.isFinite && position.speed >= 0
                  ? position.speed
                  : 0.0,
              altitude: position.altitude.isFinite ? position.altitude : 0.0,
            ))
        // Step 2 — Reject fixes with poor accuracy
        .where((point) => point.accuracy <= _maxAccuracyMeters)
        // Step 3 — Adaptive positional smoothing (EMA only for walking)
        .map((point) {
          // For run/cycle we trust the Doppler speed from the GPS chip and
          // do NOT smear the position — high-speed EMA causes significant lag.
          if (!activityType.isSlowMovement) {
            lastSmoothed = point;
            return point;
          }

          final previous = lastSmoothed;
          if (previous == null) {
            lastSmoothed = point;
            return point;
          }

          final smoothed = TrackPoint(
            latitude: previous.latitude * _walkSmoothWeight +
                point.latitude * (1 - _walkSmoothWeight),
            longitude: previous.longitude * _walkSmoothWeight +
                point.longitude * (1 - _walkSmoothWeight),
            altitude: previous.altitude * _walkSmoothWeight +
                point.altitude * (1 - _walkSmoothWeight),
            timestamp: point.timestamp,
            accuracy: point.accuracy,
            speed: point.speed, // always keep raw Doppler speed
          );
          lastSmoothed = smoothed;
          return smoothed;
        })
        // Step 4 — Speed-gate: use GPS-chip Doppler speed as primary filter,
        // and position-derived speed only as a sanity upper-bound check.
        .where((point) {
          final previous = lastAccepted;
          if (previous == null) {
            lastAccepted = point;
            return true;
          }

          final elapsedSeconds =
              point.timestamp.difference(previous.timestamp).inMilliseconds / 1000.0;
          if (elapsedSeconds <= 0) return false;

          // Primary filter: GPS chip Doppler speed. This is far more accurate
          // than position-derived speed at all speeds.
          if (point.speed > activityType.maxReasonableSpeedMetersPerSecond) {
            return false;
          }

          // Secondary sanity check: implied position-derived speed should not
          // be more than 2× the activity max (very permissive — accounts for
          // accumulated positional error over short time windows).
          final distance3d = haversineMeters3d(previous, point);
          final impliedSpeed = distance3d / elapsedSeconds;
          if (impliedSpeed > activityType.maxReasonableSpeedMetersPerSecond * 2) {
            return false;
          }

          // Minimum movement gate per activity type:
          // Walk/Trek/Climb: ignore if < 0.8 m and standing still
          // Run/Cycle: ignore if < 0.5 m (GPS noise floor)
          final minDist = activityType.isSlowMovement ? 0.8 : 0.5;
          final minSpeed = activityType.isSlowMovement ? 0.3 : 0.1;
          if (distance3d < minDist && point.speed < minSpeed) {
            return false;
          }

          lastAccepted = point;
          return true;
        });
  }
}

/// 3D Haversine distance in meters, incorporating altitude change.
/// More accurate than 2D on hilly routes.
double haversineMeters3d(TrackPoint a, TrackPoint b) {
  const earthRadiusMeters = 6371000.0;
  final dLat = _degreesToRadians(b.latitude - a.latitude);
  final dLng = _degreesToRadians(b.longitude - a.longitude);
  final lat1 = _degreesToRadians(a.latitude);
  final lat2 = _degreesToRadians(b.latitude);

  final h = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
  final horizontalDistance = earthRadiusMeters * 2 * atan2(sqrt(h), sqrt(1 - h));

  // Incorporate altitude delta (Pythagorean 3D distance).
  final dAlt = b.altitude - a.altitude;
  return sqrt(horizontalDistance * horizontalDistance + dAlt * dAlt);
}

/// 2D Haversine — kept for backwards-compatibility (used by bloc for pace calculation).
double haversineMeters(TrackPoint a, TrackPoint b) => haversineMeters3d(a, b);

double _degreesToRadians(double degrees) => degrees * pi / 180.0;

