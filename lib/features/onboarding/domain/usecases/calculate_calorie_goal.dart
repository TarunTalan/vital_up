import 'dart:math' as math;

import 'package:vital_up/features/onboarding/domain/entities/onboarding_data.dart';
import 'package:vital_up/features/onboarding/domain/entities/weight_goal.dart';

/// Derives the daily calorie goal from the onboarding answers:
/// TDEE (Mifflin-St Jeor BMR × activity factor) adjusted by the weekly pace.
class CalculateCalorieGoal {
  const CalculateCalorieGoal();

  static const double kgPerLb = 0.453592;
  static const double cmPerInch = 2.54;
  static const double weeksPerMonth = 4.345;

  /// ~7700 kcal per kg of body weight, spread over 7 days.
  static const double kcalPerKgPerWeek = 7700 / 7;

  /// Never set a goal below this without medical supervision.
  static const int minSafeCalories = 1200;
  static const int maxCalories = 5000;
  static const int roundTo = 10;

  static const int _defaultAge = 30;

  static const Map<String, double> _activityFactors = {
    'Mostly resting': 1.2,
    'Light movement': 1.375,
    'Moderate activity': 1.55,
    'Very active': 1.725,
  };

  /// Returns the goal in kcal/day, or null if weight is unknown.
  int? call(OnboardingData data, {DateTime? now}) {
    final tdee = totalDailyEnergy(data, now: now);
    if (tdee == null) return null;

    final goal = GoalType.fromId(data.goalType);
    final pace = WeeklyPace.fromId(data.weeklyPace) ?? WeeklyPace.normal;
    final delta = switch (goal) {
      GoalType.lose => -pace.kgPerWeek * kcalPerKgPerWeek,
      GoalType.buildMuscle => pace.kgPerWeek * kcalPerKgPerWeek,
      GoalType.maintain || null => 0.0,
    };

    final raw = (tdee + delta).clamp(
      minSafeCalories.toDouble(),
      maxCalories.toDouble(),
    );
    return (raw / roundTo).round() * roundTo;
  }

  /// Total daily energy expenditure in kcal, or null if weight is unknown.
  double? totalDailyEnergy(OnboardingData data, {DateTime? now}) {
    final weightKg = weightInKg(data.weight, data.weightUnit);
    if (weightKg == null) return null;

    final heightCm = heightInCm(data.height, data.heightUnit);
    final age = ageFromDob(data.dob, now: now) ?? _defaultAge;

    final double bmr;
    if (heightCm == null) {
      // No height: fall back to a weight-only estimate (~24 kcal/kg/day).
      bmr = weightKg * 24;
    } else {
      final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
      bmr = switch (data.gender.toLowerCase()) {
        'male' => base + 5,
        'female' => base - 161,
        _ => base - 78, // midpoint when gender isn't provided
      };
    }

    final factor = _activityFactors[data.activity] ?? _activityFactors['Mostly resting']!;
    return bmr * factor;
  }

  /// Estimated months to go from current to target weight at [pace].
  static int monthsToTarget({
    required double currentKg,
    required double targetKg,
    required WeeklyPace pace,
  }) {
    final weeks = (targetKg - currentKg).abs() / pace.kgPerWeek;
    return math.max(1, (weeks / weeksPerMonth).ceil());
  }

  static double? weightInKg(String value, String unit) {
    final w = double.tryParse(value);
    if (w == null || w <= 0) return null;
    return unit.toLowerCase().startsWith('lb') ? w * kgPerLb : w;
  }

  /// Height is stored as "170" (cm) or "5-7" (ft-in).
  static double? heightInCm(String value, String unit) {
    if (value.isEmpty) return null;
    if (unit == 'ft') {
      final parts = value.split('-');
      final feet = int.tryParse(parts.first);
      if (feet == null) return null;
      final inches = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      return (feet * 12 + inches) * cmPerInch;
    }
    final cm = double.tryParse(value);
    return (cm == null || cm <= 0) ? null : cm;
  }

  /// DOB is stored as "ddMMyyyy".
  static int? ageFromDob(String dob, {DateTime? now}) {
    if (dob.length != 8) return null;
    final day = int.tryParse(dob.substring(0, 2));
    final month = int.tryParse(dob.substring(2, 4));
    final year = int.tryParse(dob.substring(4));
    if (day == null || month == null || year == null) return null;
    final today = now ?? DateTime.now();
    var age = today.year - year;
    if (today.month < month || (today.month == month && today.day < day)) {
      age--;
    }
    return age > 0 ? age : null;
  }
}
