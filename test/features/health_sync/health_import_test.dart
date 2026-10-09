import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/health_sync/health_import_service.dart';

void main() {
  final start = DateTime(2026, 10, 1, 7);
  final end = start.add(const Duration(minutes: 30));

  test('a watch run becomes a VitalUp run with pace and calories', () {
    final session = HealthImportService.workoutToSession(
      'abc',
      start,
      end,
      WorkoutHealthValue(
        workoutActivityType: HealthWorkoutActivityType.RUNNING,
        totalDistance: 5000,
        totalDistanceUnit: HealthDataUnit.METER,
        totalEnergyBurned: 320,
        totalEnergyBurnedUnit: HealthDataUnit.KILOCALORIE,
      ),
    )!;
    expect(session.id, 'health_abc');
    expect(session.activityType, ActivityType.run);
    expect(session.totalDurationSeconds, 1800);
    expect(session.avgPaceSecondsPerKm, 360);
    expect(session.calories, 320);
    expect(session.stepCountReliable, isFalse);
  });

  test('miles and small calories are converted', () {
    final session = HealthImportService.workoutToSession(
      'x',
      start,
      end,
      WorkoutHealthValue(
        workoutActivityType: HealthWorkoutActivityType.BIKING,
        totalDistance: 2,
        totalDistanceUnit: HealthDataUnit.MILE,
        totalEnergyBurned: 250000,
        totalEnergyBurnedUnit: HealthDataUnit.SMALL_CALORIE,
      ),
    )!;
    expect(session.activityType, ActivityType.cycle);
    expect(session.totalDistanceMeters, closeTo(3218.7, 0.1));
    expect(session.calories, 250);
  });

  test('workout types VitalUp does not track are skipped', () {
    expect(
      HealthImportService.workoutToSession(
        'y',
        start,
        end,
        WorkoutHealthValue(workoutActivityType: HealthWorkoutActivityType.YOGA),
      ),
      isNull,
    );
  });

  test('implausible watch data is not imported as-is', () {
    WorkoutHealthValue walk({double? distance, int? kcal, int? steps}) =>
        WorkoutHealthValue(
          workoutActivityType: HealthWorkoutActivityType.WALKING,
          totalDistance: distance?.round(),
          totalDistanceUnit: HealthDataUnit.METER,
          totalEnergyBurned: kcal,
          totalEnergyBurnedUnit: HealthDataUnit.KILOCALORIE,
          totalSteps: steps,
        );
    // 50 km walked in 30 minutes: distance dropped, workout kept.
    final fast = HealthImportService.workoutToSession(
      'a', start, end, walk(distance: 50000, kcal: -20, steps: -5))!;
    expect(fast.totalDistanceMeters, 0);
    expect(fast.avgPaceSecondsPerKm, 0);
    expect(fast.calories, 0);
    expect(fast.stepCountReliable, isFalse);

    // Left running on the watch for two days.
    expect(
      HealthImportService.workoutToSession(
        'b', start, start.add(const Duration(hours: 48)), walk()),
      isNull,
    );
  });

  test('scale readings outside the human range are skipped', () {
    expect(HealthImportService.isPlausibleWeightKg(72.4), isTrue);
    expect(HealthImportService.isPlausibleWeightKg(0), isFalse);
    expect(HealthImportService.isPlausibleWeightKg(900), isFalse);
    expect(HealthImportService.isPlausibleWeightKg(double.nan), isFalse);
  });
}
