import 'dart:math';

import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/track_point.dart';
import 'package:vital_up/features/activity_tracking/domain/services/geo_math.dart';

/// Cleans a raw GPS feed into points that are safe to accumulate distance on.
///
/// Stateful: create one per tracking stream. Pure Dart so it can be unit
/// tested without a device.
class TrackPointFilter {
  TrackPointFilter(this.activityType);

  final ActivityType activityType;

  /// Maximum horizontal accuracy we accept for a GPS fix.
  /// 25 m allows most urban rooftop-occlusion scenarios while still being reliable.
  static const double maxAccuracyMeters = 25.0;

  /// EMA smoothing coefficient for slow activities (0 = fully raw, 1 = fully previous).
  /// Applied to lat/lon to reduce GPS jitter at low speeds.
  static const double _slowSmoothWeight = 0.55;

  /// Smoothing restarts after a gap this long so a fresh fix is not dragged
  /// back toward a position from minutes ago (e.g. after a pause or tunnel).
  static const Duration _smoothingResetGap = Duration(seconds: 10);
  static const double _smoothingResetDistance = 50.0;

  /// Below this Doppler speed the device is treated as standing still.
  static const double _stationarySpeed = 0.4;

  TrackPoint? _lastSmoothed;
  TrackPoint? _lastAccepted;

  /// Returns the cleaned point to record, or null if [raw] should be dropped.
  TrackPoint? process(TrackPoint raw) {
    if (!_isUsable(raw)) return null;

    final point = _smooth(raw);

    final previous = _lastAccepted;
    if (previous == null) {
      _lastAccepted = point;
      return point;
    }

    final elapsedSeconds =
        point.timestamp.difference(previous.timestamp).inMilliseconds / 1000.0;
    if (elapsedSeconds <= 0) return null;

    final maxSpeed = activityType.maxReasonableSpeedMetersPerSecond;

    // Primary filter: GPS chip Doppler speed. This is far more accurate
    // than position-derived speed at all speeds.
    if (point.speed > maxSpeed) return null;

    // Secondary sanity check: implied position-derived speed should not
    // be more than 2× the activity max (very permissive — accounts for
    // accumulated positional error over short time windows).
    final distance = haversineMeters(previous, point);
    if (distance / elapsedSeconds > maxSpeed * 2) return null;

    // Movement gate. When Doppler says we're moving, a small step is real.
    // When it says we're still (or the device reports no speed at all), the
    // point must leave the fix's own error radius before it counts —
    // otherwise standing at a crossing slowly "walks" kilometres of jitter.
    final isMoving = point.speed >= _stationarySpeed;
    final minDistance = isMoving
        ? (activityType.isSlowMovement ? 1.0 : 0.5)
        : _jitterRadius(previous, point);
    if (distance < minDistance) return null;

    _lastAccepted = point;
    return point;
  }

  // No "fix too old" check on purpose: offline devices can't sync their
  // clock, so comparing GPS time with the wall clock would drop live fixes.
  bool _isUsable(TrackPoint p) {
    if (!p.latitude.isFinite || !p.longitude.isFinite) return false;
    if (p.latitude.abs() > 90 || p.longitude.abs() > 180) return false;
    // (0,0) is what some chipsets emit before they have a fix.
    if (p.latitude == 0 && p.longitude == 0) return false;
    if (!p.accuracy.isFinite || p.accuracy <= 0) return false;
    if (p.accuracy > maxAccuracyMeters) return false;
    return true;
  }

  TrackPoint _smooth(TrackPoint point) {
    // For run/cycle we trust the Doppler speed from the GPS chip and
    // do NOT smear the position — high-speed EMA causes significant lag.
    final previous = _lastSmoothed;
    if (!activityType.isSlowMovement ||
        previous == null ||
        point.timestamp.difference(previous.timestamp) > _smoothingResetGap ||
        haversineMeters(previous, point) > _smoothingResetDistance) {
      _lastSmoothed = point;
      return point;
    }

    const w = _slowSmoothWeight;
    final smoothed = TrackPoint(
      latitude: previous.latitude * w + point.latitude * (1 - w),
      longitude: previous.longitude * w + point.longitude * (1 - w),
      altitude: previous.altitude * w + point.altitude * (1 - w),
      timestamp: point.timestamp,
      accuracy: point.accuracy,
      speed: point.speed, // always keep raw Doppler speed
    );
    _lastSmoothed = smoothed;
    return smoothed;
  }

  /// Half the worse of the two fixes' accuracy, kept within 3–10 m.
  double _jitterRadius(TrackPoint a, TrackPoint b) =>
      (max(a.accuracy, b.accuracy) * 0.5).clamp(3.0, 10.0);
}
