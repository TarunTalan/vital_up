import 'dart:math';

import 'package:vital_up/features/activity_tracking/domain/entities/track_point.dart';

const double _earthRadiusMeters = 6371000.0;

/// Horizontal (great-circle) distance in meters between two points.
///
/// Altitude is deliberately ignored: GPS altitude is 3–5× noisier than the
/// horizontal fix, and folding it in inflates distance on every jittery
/// sample. Running/cycling apps measure distance on the horizontal plane.
double haversineMeters(TrackPoint a, TrackPoint b) {
  final dLat = _degreesToRadians(b.latitude - a.latitude);
  final dLng = _degreesToRadians(b.longitude - a.longitude);
  final lat1 = _degreesToRadians(a.latitude);
  final lat2 = _degreesToRadians(b.latitude);

  final h = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
  return _earthRadiusMeters * 2 * atan2(sqrt(h), sqrt(1 - h));
}

double _degreesToRadians(double degrees) => degrees * pi / 180.0;
