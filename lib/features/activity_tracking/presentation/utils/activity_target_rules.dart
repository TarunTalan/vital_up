import 'package:vital_up/core/preferences/distance_unit_notifier.dart';
import 'package:vital_up/core/preferences/workout_prefs_notifier.dart';
import 'package:vital_up/core/utils/input_rules.dart';

/// Ranges accepted for a workout target. Distance is stored in km.
abstract final class ActivityTargetLimits {
  static const double distanceKmMin = 0.1;
  static const double distanceKmMax = 300;
  static const double caloriesMin = 10;
  static const double caloriesMax = 5000;
  static const double kmPerMile = 1.60934;
}

/// Parsed target value, or the inline error to show for what was typed.
typedef ActivityTargetResult = ({double? value, String? error});

/// Validates a typed workout target. Distance is typed in [unit] and
/// returned in km; calories are returned as typed (kcal).
ActivityTargetResult parseActivityTarget(
  WorkoutTargetType type,
  String input,
  DistanceUnit unit,
) {
  if (input.trim().isEmpty) return (value: null, error: 'Enter a target');

  if (type == WorkoutTargetType.distance) {
    final miles = unit == DistanceUnit.miles;
    final factor = miles ? ActivityTargetLimits.kmPerMile : 1.0;
    final min = ActivityTargetLimits.distanceKmMin / factor;
    final max = ActivityTargetLimits.distanceKmMax / factor;
    final typed = parseNumberInRange(input, min: min, max: max);
    if (typed == null) {
      return (
        value: null,
        error: 'Enter ${_fmt(min)} to ${_fmt(max)} ${unit.label}',
      );
    }
    return (value: typed * factor, error: null);
  }

  final kcal = parseNumberInRange(
    input,
    min: ActivityTargetLimits.caloriesMin,
    max: ActivityTargetLimits.caloriesMax,
  );
  if (kcal == null) {
    return (
      value: null,
      error:
          'Enter ${_fmt(ActivityTargetLimits.caloriesMin)} to '
          '${_fmt(ActivityTargetLimits.caloriesMax)} kcal',
    );
  }
  return (value: kcal.roundToDouble(), error: null);
}

String _fmt(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
