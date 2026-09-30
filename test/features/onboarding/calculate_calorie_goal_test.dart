import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/onboarding/domain/entities/onboarding_data.dart';
import 'package:vital_up/features/onboarding/domain/entities/weight_goal.dart';
import 'package:vital_up/features/onboarding/domain/usecases/calculate_calorie_goal.dart';

void main() {
  const calc = CalculateCalorieGoal();
  final now = DateTime(2026, 9, 30);

  // 30-year-old male, 80 kg, 180 cm, moderate activity.
  // BMR = 10*80 + 6.25*180 - 5*30 + 5 = 1780; TDEE = 1780 * 1.55 = 2759.
  const base = OnboardingData(
    dob: '15061996',
    gender: 'male',
    weight: '80',
    weightUnit: 'kg',
    height: '180',
    heightUnit: 'cm',
    activity: 'Moderate activity',
  );

  test('TDEE uses Mifflin-St Jeor with activity factor', () {
    expect(calc.totalDailyEnergy(base, now: now), closeTo(2759, 0.01));
  });

  test('maintain returns TDEE rounded to 10', () {
    final data = base.copyWith(goalType: GoalType.maintain.id);
    expect(calc(data, now: now), 2760);
  });

  test('lose at normal pace subtracts ~550 kcal/day', () {
    final data = base.copyWith(
      goalType: GoalType.lose.id,
      weeklyPace: WeeklyPace.normal.id,
    );
    expect(calc(data, now: now), 2210);
  });

  test('build muscle at relaxed pace adds ~275 kcal/day', () {
    final data = base.copyWith(
      goalType: GoalType.buildMuscle.id,
      weeklyPace: WeeklyPace.relaxed.id,
    );
    expect(calc(data, now: now), 3030);
  });

  test('never goes below the safe minimum', () {
    final data = base.copyWith(
      gender: 'female',
      weight: '45',
      height: '150',
      activity: 'Mostly resting',
      goalType: GoalType.lose.id,
      weeklyPace: WeeklyPace.aggressive.id,
    );
    expect(calc(data, now: now), CalculateCalorieGoal.minSafeCalories);
  });

  test('converts imperial height and weight', () {
    expect(CalculateCalorieGoal.heightInCm('5-11', 'ft'), closeTo(180.34, 0.01));
    expect(CalculateCalorieGoal.weightInKg('176', 'lb'), closeTo(79.83, 0.01));
  });

  test('age accounts for birthday not yet reached this year', () {
    expect(CalculateCalorieGoal.ageFromDob('01121996', now: now), 29);
    expect(CalculateCalorieGoal.ageFromDob('01091996', now: now), 30);
  });

  test('months to target rounds up', () {
    expect(
      CalculateCalorieGoal.monthsToTarget(
        currentKg: 80,
        targetKg: 70,
        pace: WeeklyPace.normal,
      ),
      5, // 20 weeks / 4.345 = 4.6 -> 5
    );
  });
}
