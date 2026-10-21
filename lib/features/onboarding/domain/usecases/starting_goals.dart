import 'package:vital_up/features/dashboard/domain/tracker_input_rules.dart';
import 'package:vital_up/features/onboarding/domain/entities/onboarding_data.dart';
import 'package:vital_up/features/onboarding/domain/usecases/calculate_calorie_goal.dart';

/// A new user's first goals, worked out from their onboarding answers so
/// Home never opens on numbers nobody chose. Answers that were skipped
/// fall back to the app's usual defaults. Screen time has no limit: how
/// much is too much is the user's call, unlike water or sleep.
class StartingGoals {
  final int waterMl;
  final int dailySteps;
  final int weeklyWorkouts;
  final int sleepMinutes;

  const StartingGoals({
    required this.waterMl,
    required this.dailySteps,
    required this.weeklyWorkouts,
    required this.sleepMinutes,
  });

  static const defaultWaterMl = 2500;
  static const _defaultActivity = (steps: 8000, workouts: 3);

  /// Steps a day and workouts a week per onboarding activity level.
  static const _byActivity = {
    'Mostly resting': (steps: 6000, workouts: 2),
    'Light movement': (steps: 7500, workouts: 3),
    'Moderate activity': (steps: 9000, workouts: 4),
    'Very active': (steps: 11000, workouts: 5),
  };

  /// Teens need more sleep than adults (8-10 h vs 7-9 h).
  static const _adultSleep = 8 * 60;
  static const _teenSleep = 9 * 60;

  factory StartingGoals.from(OnboardingData data, {DateTime? now}) {
    final kg = CalculateCalorieGoal.weightInKg(data.weight, data.weightUnit);
    final activity = _byActivity[data.activity] ?? _defaultActivity;
    final age = CalculateCalorieGoal.ageFromDob(data.dob, now: now);
    return StartingGoals(
      waterMl: kg == null ? defaultWaterMl : recommendedWaterGoalMl(kg),
      dailySteps: activity.steps,
      weeklyWorkouts: activity.workouts,
      sleepMinutes: age != null && age < 18 ? _teenSleep : _adultSleep,
    );
  }
}
