import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/track_point.dart';
import 'package:vital_up/features/activity_tracking/domain/services/geo_math.dart';
import 'package:vital_up/features/activity_tracking/domain/services/track_point_filter.dart';

final _t0 = DateTime.utc(2026, 10, 1, 7);
const _lat0 = 12.9716;
const _lng0 = 77.5946;

/// Meters north of the origin, converted to degrees of latitude.
double _north(double meters) => _lat0 + meters / 111195.0;

TrackPoint _p(
  int second, {
  double northMeters = 0,
  double eastMeters = 0,
  double speed = 0,
  double accuracy = 5,
  double altitude = 900,
}) {
  final lngPerMeter = 1 / (111195.0 * cos(_lat0 * pi / 180));
  return TrackPoint(
    latitude: _north(northMeters),
    longitude: _lng0 + eastMeters * lngPerMeter,
    timestamp: _t0.add(Duration(seconds: second)),
    accuracy: accuracy,
    speed: speed,
    altitude: altitude,
  );
}

double _trackLength(List<TrackPoint> points) {
  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    total += haversineMeters(points[i - 1], points[i]);
  }
  return total;
}

void main() {
  group('TrackPointFilter', () {
    test('standing still with GPS jitter adds (almost) no distance', () {
      final filter = TrackPointFilter(ActivityType.walk);
      final rng = Random(7);
      final accepted = <TrackPoint>[];
      for (var s = 0; s < 300; s++) {
        final p = filter.process(_p(
          s,
          northMeters: (rng.nextDouble() - 0.5) * 6, // ±3 m wander
          eastMeters: (rng.nextDouble() - 0.5) * 6,
          speed: rng.nextDouble() * 0.3,
          accuracy: 8,
        ));
        if (p != null) accepted.add(p);
      }
      expect(_trackLength(accepted), lessThan(10));
    });

    test('a steady walk keeps its true distance', () {
      final filter = TrackPointFilter(ActivityType.walk);
      final accepted = <TrackPoint>[];
      for (var s = 0; s <= 600; s++) {
        final p = filter.process(_p(s, northMeters: s * 1.4, speed: 1.4));
        if (p != null) accepted.add(p);
      }
      // 600 s × 1.4 m/s = 840 m. Smoothing lags the last fix slightly.
      expect(_trackLength(accepted), closeTo(840, 5));
    });

    test('a walk on a device that reports no speed still counts', () {
      final filter = TrackPointFilter(ActivityType.walk);
      final accepted = <TrackPoint>[];
      for (var s = 0; s <= 300; s++) {
        final p = filter.process(_p(s, northMeters: s * 1.3));
        if (p != null) accepted.add(p);
      }
      expect(_trackLength(accepted), closeTo(390, 10));
    });

    test('drops a teleport spike and keeps going', () {
      final filter = TrackPointFilter(ActivityType.run);
      expect(filter.process(_p(0, speed: 3)), isNotNull);
      expect(filter.process(_p(1, northMeters: 3, speed: 3)), isNotNull);
      expect(filter.process(_p(2, northMeters: 300, speed: 3)), isNull);
      expect(filter.process(_p(3, northMeters: 9, speed: 3)), isNotNull);
    });

    test('rejects poor, invalid and out-of-order fixes', () {
      final filter = TrackPointFilter(ActivityType.walk);
      expect(filter.process(_p(0, accuracy: 60)), isNull);
      expect(
        filter.process(TrackPoint(
          latitude: 0,
          longitude: 0,
          timestamp: _t0,
          accuracy: 5,
          speed: 0,
          altitude: 0,
        )),
        isNull,
      );
      expect(filter.process(_p(5, speed: 1.4)), isNotNull);
      expect(filter.process(_p(4, northMeters: 2, speed: 1.4)), isNull);
    });

    test('rejects Doppler speeds impossible for the activity', () {
      final filter = TrackPointFilter(ActivityType.walk);
      expect(filter.process(_p(0, speed: 1)), isNotNull);
      // 8 m/s is a car, not a walk.
      expect(filter.process(_p(1, northMeters: 8, speed: 8)), isNull);
    });

    test('distance ignores GPS altitude noise', () {
      final a = _p(0, altitude: 900);
      final b = _p(1, northMeters: 1, altitude: 915);
      expect(haversineMeters(a, b), closeTo(1, 0.01));
    });
  });
}
