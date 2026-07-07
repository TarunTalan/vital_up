import 'package:vital_up/features/food_scanner/domain/entities/nutrition_info.dart';
import 'food_item_dto.dart';

class NutritionInfoDto {
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;
  final double sugarG;
  final double sodiumMg;
  final FoodItemDto per;

  NutritionInfoDto({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
    required this.sugarG,
    required this.sodiumMg,
    required this.per,
  });

  factory NutritionInfoDto.fromJson(Map<String, dynamic> json) {
    return NutritionInfoDto(
      calories: (json['calories'] as num?)?.toDouble() ?? 0.0,
      proteinG: (json['protein'] as num?)?.toDouble() ?? (json['protein_g'] as num?)?.toDouble() ?? 0.0,
      carbsG: (json['carbohydrate'] as num?)?.toDouble() ?? (json['carbs_g'] as num?)?.toDouble() ?? 0.0,
      fatG: (json['fat'] as num?)?.toDouble() ?? (json['fat_g'] as num?)?.toDouble() ?? 0.0,
      fiberG: (json['fiber'] as num?)?.toDouble() ?? (json['fiber_g'] as num?)?.toDouble() ?? 0.0,
      sugarG: (json['sugar'] as num?)?.toDouble() ?? (json['sugar_g'] as num?)?.toDouble() ?? 0.0,
      sodiumMg: (json['sodium'] as num?)?.toDouble() ?? (json['sodium_mg'] as num?)?.toDouble() ?? 0.0,
      per: FoodItemDto.fromJson(json['per'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'calories': calories,
      'protein': proteinG,
      'carbohydrate': carbsG,
      'fat': fatG,
      'fiber': fiberG,
      'sugar': sugarG,
      'sodium': sodiumMg,
      'per': per.toJson(),
    };
  }

  NutritionInfo toDomain() {
    return NutritionInfo(
      calories: calories,
      proteinG: proteinG,
      carbsG: carbsG,
      fatG: fatG,
      fiberG: fiberG,
      sugarG: sugarG,
      sodiumMg: sodiumMg,
      per: per.toDomain(),
    );
  }

  static NutritionInfoDto fromDomain(NutritionInfo nutritionInfo) {
    return NutritionInfoDto(
      calories: nutritionInfo.calories,
      proteinG: nutritionInfo.proteinG,
      carbsG: nutritionInfo.carbsG,
      fatG: nutritionInfo.fatG,
      fiberG: nutritionInfo.fiberG,
      sugarG: nutritionInfo.sugarG,
      sodiumMg: nutritionInfo.sodiumMg,
      per: FoodItemDto.fromDomain(nutritionInfo.per),
    );
  }
}
