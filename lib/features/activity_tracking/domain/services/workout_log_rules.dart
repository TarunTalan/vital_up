import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/workout_intensity.dart';

/// Rules for workouts without a route, timed in the app or logged after
/// the fact. Pure, so the sheet, the timer and the tests share them.
abstract final class WorkoutLogRules {
  /// Shorter than this isn't a workout (a mis-tap on Start).
  static const minLength = Duration(minutes: 1);

  /// Longest single workout; a timer left running stops here.
  static const maxLength = Duration(hours: 6);

  /// How far back a past workout can be logged.
  static const maxBackfillDays = 30;

  /// Weight used for calories when the profile has none.
  static const fallbackWeightKg = 70.0;
}

/// Calories for [length] of [type] at [intensity]: MET x weight x hours.
int estimateWorkoutCalories(
  ActivityType type,
  WorkoutIntensity intensity,
  Duration length, {
  required double weightKg,
}) {
  final weight = weightKg.isFinite && weightKg > 0
      ? weightKg
      : WorkoutLogRules.fallbackWeightKg;
  final hours = length.inSeconds / 3600.0;
  final kcal = type.met * intensity.metFactor * weight * hours;
  return kcal.round().clamp(0, InputLimits.caloriesMax);
}

/// Why a workout starting at [start] and lasting [length] can't be saved,
/// or null when it can.
String? workoutEntryError(
  DateTime start,
  Duration length, {
  required DateTime now,
}) {
  if (length < WorkoutLogRules.minLength) {
    return 'Enter at least 1 minute.';
  }
  if (length > WorkoutLogRules.maxLength) {
    return 'A workout can be up to 6 hours.';
  }
  if (start.add(length).isAfter(now)) {
    return 'This workout ends in the future. Check the time.';
  }
  final earliest = DateTime(
    now.year,
    now.month,
    now.day - WorkoutLogRules.maxBackfillDays,
  );
  if (start.isBefore(earliest)) {
    return 'You can log workouts from the last 30 days.';
  }
  return null;
}

/// A finished workout without a route, ready to save.
ActivitySession buildWorkoutSession({
  required String id,
  required ActivityType type,
  required DateTime start,
  required Duration length,
  required WorkoutIntensity intensity,
  required double weightKg,
}) {
  return ActivitySession(
    id: id,
    activityType: type,
    startTime: start,
    endTime: start.add(length),
    totalDistanceMeters: 0,
    totalDurationSeconds: length.inSeconds,
    avgPaceSecondsPerKm: 0,
    calories: estimateWorkoutCalories(
      type,
      intensity,
      length,
      weightKg: weightKg,
    ),
    steps: 0,
    stepCountReliable: true,
    points: const [],
    intensity: intensity,
  );
}
