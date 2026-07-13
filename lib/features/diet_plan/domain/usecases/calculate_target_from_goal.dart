import '../entities/nutrition_target.dart';

class CalculateTargetFromGoal {
  // We take current TDEE, current weight, target weight, timeframe in weeks.
  NutritionTarget call({
    required double currentTdee,
    required double currentWeightKg,
    required double targetWeightKg,
    required int timeframeWeeks,
    bool isMuscleGainGoal = false,
  }) {
    if (timeframeWeeks <= 0) timeframeWeeks = 1;

    final weightDiffKg = targetWeightKg - currentWeightKg;
    // 7700 kcal per kg of bodyweight
    final totalCalorieDiff = weightDiffKg * 7700;
    
    // Daily diff
    final days = timeframeWeeks * 7;
    double dailyDiff = totalCalorieDiff / days;

    // Cap rate of change at 1% of bodyweight per week.
    // 1% of bodyweight = currentWeightKg * 0.01
    // max total calorie diff per week = (currentWeightKg * 0.01) * 7700
    // max daily diff = max total calorie diff / 7 = currentWeightKg * 11.0
    final maxDailyDiff = currentWeightKg * 11.0; 
    
    if (dailyDiff > maxDailyDiff) {
      dailyDiff = maxDailyDiff;
    } else if (dailyDiff < -maxDailyDiff) {
      dailyDiff = -maxDailyDiff;
    }

    int targetCalories = (currentTdee + dailyDiff).round();
    if (targetCalories < 1200) targetCalories = 1200; // safety floor

    // Macros
    double proteinPct = isMuscleGainGoal ? 0.35 : 0.30;
    double carbPct = isMuscleGainGoal ? 0.40 : 0.40;
    double fatPct = isMuscleGainGoal ? 0.25 : 0.30;

    final protein = ((targetCalories * proteinPct) / 4).round();
    final carbs = ((targetCalories * carbPct) / 4).round();
    final fat = ((targetCalories * fatPct) / 9).round();

    return NutritionTarget(
      calories: targetCalories,
      protein: protein,
      carbs: carbs,
      fat: fat,
    );
  }
}
