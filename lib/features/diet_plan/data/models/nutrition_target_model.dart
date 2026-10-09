import '../../domain/entities/nutrition_target.dart';

class NutritionTargetModel extends NutritionTarget {
  const NutritionTargetModel({
    required super.calories,
    required super.protein,
    required super.carbs,
    required super.fat,
  });

  factory NutritionTargetModel.fromJson(Map<String, dynamic> json) {
    return NutritionTargetModel(
      calories: (json['calories'] as num?)?.round() ?? 0,
      protein: (json['protein'] as num?)?.round() ?? 0,
      carbs: (json['carbs'] as num?)?.round() ?? 0,
      fat: (json['fat'] as num?)?.round() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    };
  }

  factory NutritionTargetModel.fromEntity(NutritionTarget target) {
    return NutritionTargetModel(
      calories: target.calories,
      protein: target.protein,
      carbs: target.carbs,
      fat: target.fat,
    );
  }
}
