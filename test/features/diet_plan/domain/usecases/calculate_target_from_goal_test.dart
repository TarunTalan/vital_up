import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/diet_plan/domain/usecases/calculate_target_from_goal.dart';

void main() {
  late CalculateTargetFromGoal usecase;

  setUp(() {
    usecase = CalculateTargetFromGoal();
  });

  test('Lose 2kg in 4 weeks (0.5kg/week)', () {
    final result = usecase(
      currentTdee: 2500,
      currentWeightKg: 80,
      targetWeightKg: 78,
      timeframeWeeks: 4,
    );
    
    // Deficit of 550 kcal/day
    expect(result.calories, 1950);
  });
  
  test('Caps weight loss deficit at 1% bodyweight per week', () {
    final result = usecase(
      currentTdee: 2500,
      currentWeightKg: 80,
      targetWeightKg: 76, // 4kg loss
      timeframeWeeks: 2,  // in 2 weeks (2kg/week)
    );
    
    // Max deficit = 80 * 11.0 = 880 kcal/day
    expect(result.calories, 2500 - 880); // 1620
  });

  test('Caps weight gain surplus at 1% bodyweight per week', () {
    final result = usecase(
      currentTdee: 2500,
      currentWeightKg: 80,
      targetWeightKg: 84, // 4kg gain
      timeframeWeeks: 2,  // in 2 weeks (2kg/week)
    );
    
    // Max surplus = 80 * 11.0 = 880 kcal/day
    expect(result.calories, 2500 + 880); // 3380
  });

  test('Adjusts macros for muscle gain', () {
    final result = usecase(
      currentTdee: 2500,
      currentWeightKg: 80,
      targetWeightKg: 80, // maintain
      timeframeWeeks: 4,
      isMuscleGainGoal: true,
    );
    
    expect(result.calories, 2500);
    // Muscle gain macros: 35% protein, 40% carbs, 25% fat
    expect(result.protein, ((2500 * 0.35) / 4).round());
    expect(result.carbs, ((2500 * 0.40) / 4).round());
    expect(result.fat, ((2500 * 0.25) / 9).round());
  });
}
