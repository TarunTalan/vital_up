import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/services/activity_calories.dart';

int _kcal(
  ActivityType type, {
  required int minutes,
  required double km,
  double climb = 0,
  double weight = 70,
}) =>
    estimateGpsCalories(
      type,
      elapsed: Duration(minutes: minutes),
      distanceMeters: km * 1000,
      elevationGainMeters: climb,
      weightKg: weight,
    );

void main() {
  group('estimateGpsCalories', () {
    test('matches the Compendium at typical speeds (70 kg, 1 hour)', () {
      // Walking 5 km/h ~3.5 MET = 245 kcal.
      expect(_kcal(ActivityType.walk, minutes: 60, km: 5), closeTo(245, 10));
      // Running 10 km/h ~10-11 MET = 700-770 kcal.
      expect(_kcal(ActivityType.run, minutes: 60, km: 10), closeTo(770, 40));
      // Cycling 20 km/h ~8 MET = 560 kcal.
      expect(_kcal(ActivityType.cycle, minutes: 60, km: 20), closeTo(560, 30));
      // Hiking 4 km/h with 150 m of climb ~5.5 MET.
      expect(
        _kcal(ActivityType.trekking, minutes: 60, km: 4, climb: 150),
        closeTo(380, 20),
      );
      // Climbing uses its MET over time.
      expect(_kcal(ActivityType.climbing, minutes: 60, km: 1), 560);
    });

    test('scales with weight', () {
      final light = _kcal(ActivityType.run, minutes: 30, km: 5, weight: 50);
      final heavy = _kcal(ActivityType.run, minutes: 30, km: 5, weight: 100);
      expect(heavy, closeTo(light * 2, 1));
    });

    test('never goes down while standing still or slowing', () {
      for (final type in ActivityType.outdoor) {
        var last = 0;
        // 20 minutes moving, then 10 minutes stopped at the same distance.
        for (var minute = 0; minute <= 30; minute++) {
          final km = minute <= 20 ? minute * 0.2 : 4.0;
          final now = _kcal(type, minutes: minute, km: km);
          expect(now, greaterThanOrEqualTo(last), reason: '${type.name} $minute');
          last = now;
        }
      }
    });

    test('climbing a hill costs more than the flat', () {
      expect(
        _kcal(ActivityType.walk, minutes: 30, km: 2, climb: 100),
        greaterThan(_kcal(ActivityType.walk, minutes: 30, km: 2)),
      );
    });

    test('a missing or broken weight uses the average', () {
      expect(
        estimateGpsCalories(
          ActivityType.walk,
          elapsed: const Duration(hours: 1),
          distanceMeters: 5000,
          weightKg: double.nan,
        ),
        _kcal(ActivityType.walk, minutes: 60, km: 5),
      );
      expect(
        estimateGpsCalories(
          ActivityType.walk,
          elapsed: Duration.zero,
          distanceMeters: 0,
          weightKg: 70,
        ),
        0,
      );
    });
  });
}
