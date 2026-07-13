import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/diet_plan/domain/usecases/calculate_target_from_onboarding.dart';
import 'package:vital_up/features/onboarding/domain/entities/onboarding_data.dart';

void main() {
  late CalculateTargetFromOnboarding usecase;

  setUp(() {
    usecase = CalculateTargetFromOnboarding();
  });

  test('Calculates TDEE correctly for a 30yo, 70kg, 175cm male, moderately active', () {
    // Current year is dynamic in code, but assuming 30 years old logic works.
    // To ensure exact age 30, we calculate the year 30 years ago from today.
    final year = DateTime.now().year - 30;
    
    final data = OnboardingData(
      weight: '70',
      weightUnit: 'kg',
      height: '175',
      heightUnit: 'cm',
      dob: '01/01/$year',
      gender: 'Male',
      activity: 'Moderate',
    );

    final result = usecase(data);
    expect(result.calories, 2556); // 1648.75 * 1.55 = 2555.56 -> 2556
    
    expect(result.protein, 192); // 30% of 2556 / 4
    expect(result.carbs, 256);   // 40% of 2556 / 4
    expect(result.fat, 85);      // 30% of 2556 / 9
  });

  test('Adjusts macros for diabetes', () {
    final year = DateTime.now().year - 30;
    final data = OnboardingData(
      weight: '70',
      weightUnit: 'kg',
      height: '175',
      heightUnit: 'cm',
      dob: '01/01/$year',
      gender: 'Male',
      activity: 'Moderate',
      healthConditions: 'Diabetes, Hypertension',
    );
    
    final result = usecase(data);
    expect(result.calories, 2556);
    
    // Diabetes macros: 30% protein, 30% carbs, 40% fat
    expect(result.protein, 192);
    expect(result.carbs, 192);
    expect(result.fat, 114); // 40% of 2556 / 9 = 113.6 -> 114
  });

  test('Applies 1200 kcal safety floor', () {
    final year = DateTime.now().year - 90;
    final data = OnboardingData(
      weight: '40', // very low weight
      weightUnit: 'kg',
      height: '140',
      heightUnit: 'cm',
      dob: '01/01/$year',
      gender: 'Female',
      activity: 'Sedentary',
    );
    
    // BMR = 400 + 875 - 450 - 161 = 664
    // TDEE = 664 * 1.2 = 796.8
    // Should be floored to 1200
    final result = usecase(data);
    expect(result.calories, 1200);
  });
}
