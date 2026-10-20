import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/services/workout_log_rules.dart';

/// Resting energy, 1 MET: 3.5 ml O2 per kg per minute at 5 kcal per litre.
const double kcalPerKgPerRestingHour = 1.05;

/// Calories for a GPS workout: resting energy for the active time, plus the
/// cost of the distance covered and the height climbed (ACSM metabolic
/// equations; see [ActivityType.kcalPerKgPerKm]). Climbing, whose effort
/// is vertical rather than distance, uses its MET over time.
///
/// Every term only grows with time, distance and climb, so the live figure
/// never goes down (a stop at a crossing or a slower stretch used to lower
/// an average-speed based estimate). Gross calories, like
/// [estimateWorkoutCalories], so GPS and timed workouts add up the same way.
int estimateGpsCalories(
  ActivityType type, {
  required Duration elapsed,
  required double distanceMeters,
  double elevationGainMeters = 0,
  required double weightKg,
}) {
  final weight = weightKg.isFinite && weightKg > 0
      ? weightKg
      : WorkoutLogRules.fallbackWeightKg;
  final hours = elapsed.inMilliseconds / Duration.millisecondsPerHour;
  if (hours <= 0) return 0;
  final km = distanceMeters.isFinite && distanceMeters > 0
      ? distanceMeters / 1000.0
      : 0.0;
  final climb = elevationGainMeters.isFinite && elevationGainMeters > 0
      ? elevationGainMeters
      : 0.0;

  final double perKg;
  if (type.kcalPerKgPerKm > 0) {
    perKg = kcalPerKgPerRestingHour * hours +
        type.kcalPerKgPerKm * km +
        type.kcalPerKgPerClimbMeter * climb;
  } else {
    perKg = type.met * hours;
  }
  return (perKg * weight).round().clamp(0, InputLimits.caloriesMax);
}
