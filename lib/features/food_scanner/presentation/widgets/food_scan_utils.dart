import 'package:vital_up/features/food_scanner/domain/entities/nutrition_info.dart';

class FoodScanUtils {
  static String formatCalories(double calories) {
    return '${calories.toStringAsFixed(0)} kcal';
  }

  static String formatMacro(double value, String unit) {
    return '${value.toStringAsFixed(1)}$unit';
  }

  static String formatConfidence(double confidence) {
    return '${(confidence * 100).toStringAsFixed(0)}%';
  }

  static String getConfidenceLabel(double confidence) {
    if (confidence >= 0.8) return 'High';
    if (confidence >= 0.6) return 'Medium';
    return 'Low';
  }

  static double calculateTotalCalories(List<NutritionInfo> nutritionList) {
    return nutritionList.fold<double>(0, (sum, nut) => sum + nut.calories);
  }

  static double calculateTotalProtein(List<NutritionInfo> nutritionList) {
    return nutritionList.fold<double>(0, (sum, nut) => sum + nut.proteinG);
  }

  static double calculateTotalCarbs(List<NutritionInfo> nutritionList) {
    return nutritionList.fold<double>(0, (sum, nut) => sum + nut.carbsG);
  }

  static double calculateTotalFat(List<NutritionInfo> nutritionList) {
    return nutritionList.fold<double>(0, (sum, nut) => sum + nut.fatG);
  }

  static double calculateProteinRatio(List<NutritionInfo> nutritionList) {
    final totalCalories = calculateTotalCalories(nutritionList);
    final totalProtein = calculateTotalProtein(nutritionList);
    if (totalCalories == 0) return 0;
    return (totalProtein * 4) / totalCalories;
  }

  static double calculateFatRatio(List<NutritionInfo> nutritionList) {
    final totalCalories = calculateTotalCalories(nutritionList);
    final totalFat = calculateTotalFat(nutritionList);
    if (totalCalories == 0) return 0;
    return (totalFat * 9) / totalCalories;
  }

  static double calculateCarbRatio(List<NutritionInfo> nutritionList) {
    final totalCalories = calculateTotalCalories(nutritionList);
    final totalCarbs = calculateTotalCarbs(nutritionList);
    if (totalCalories == 0) return 0;
    return (totalCarbs * 4) / totalCalories;
  }
}
