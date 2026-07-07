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
  final double calciumMg;
  final double ironMg;
  final double vitaminAIu;
  final double vitaminCMg;
  final double vitaminDIu;
  final double vitaminEMg;
  final double vitaminKMg;
  final double thiaminMg;
  final double riboflavinMg;
  final double niacinMg;
  final double vitaminB6Mg;
  final double vitaminB12Mcg;
  final double folateMcg;
  final double potassiumMg;
  final double phosphorusMg;
  final double magnesiumMg;
  final double zincMg;
  final double copperMg;
  final double manganeseMg;
  final double seleniumMcg;
  final double cholesterolMg;
  final double saturatedFatG;
  final double transFatG;
  final double monounsaturatedFatG;
  final double polyunsaturatedFatG;
  final List<AdditionalNutrientDto> additionalNutrients;
  final FoodItemDto per;

  NutritionInfoDto({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
    required this.sugarG,
    required this.sodiumMg,
    this.calciumMg = 0,
    this.ironMg = 0,
    this.vitaminAIu = 0,
    this.vitaminCMg = 0,
    this.vitaminDIu = 0,
    this.vitaminEMg = 0,
    this.vitaminKMg = 0,
    this.thiaminMg = 0,
    this.riboflavinMg = 0,
    this.niacinMg = 0,
    this.vitaminB6Mg = 0,
    this.vitaminB12Mcg = 0,
    this.folateMcg = 0,
    this.potassiumMg = 0,
    this.phosphorusMg = 0,
    this.magnesiumMg = 0,
    this.zincMg = 0,
    this.copperMg = 0,
    this.manganeseMg = 0,
    this.seleniumMcg = 0,
    this.cholesterolMg = 0,
    this.saturatedFatG = 0,
    this.transFatG = 0,
    this.monounsaturatedFatG = 0,
    this.polyunsaturatedFatG = 0,
    this.additionalNutrients = const [],
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
      calciumMg: (json['calcium_mg'] as num?)?.toDouble() ?? 0.0,
      ironMg: (json['iron_mg'] as num?)?.toDouble() ?? 0.0,
      vitaminAIu: (json['vitamin_a_iu'] as num?)?.toDouble() ?? 0.0,
      vitaminCMg: (json['vitamin_c_mg'] as num?)?.toDouble() ?? 0.0,
      vitaminDIu: (json['vitamin_d_iu'] as num?)?.toDouble() ?? 0.0,
      vitaminEMg: (json['vitamin_e_mg'] as num?)?.toDouble() ?? 0.0,
      vitaminKMg: (json['vitamin_k_mg'] as num?)?.toDouble() ?? 0.0,
      thiaminMg: (json['thiamin_mg'] as num?)?.toDouble() ?? 0.0,
      riboflavinMg: (json['riboflavin_mg'] as num?)?.toDouble() ?? 0.0,
      niacinMg: (json['niacin_mg'] as num?)?.toDouble() ?? 0.0,
      vitaminB6Mg: (json['vitamin_b6_mg'] as num?)?.toDouble() ?? 0.0,
      vitaminB12Mcg: (json['vitamin_b12_mcg'] as num?)?.toDouble() ?? 0.0,
      folateMcg: (json['folate_mcg'] as num?)?.toDouble() ?? 0.0,
      potassiumMg: (json['potassium_mg'] as num?)?.toDouble() ?? 0.0,
      phosphorusMg: (json['phosphorus_mg'] as num?)?.toDouble() ?? 0.0,
      magnesiumMg: (json['magnesium_mg'] as num?)?.toDouble() ?? 0.0,
      zincMg: (json['zinc_mg'] as num?)?.toDouble() ?? 0.0,
      copperMg: (json['copper_mg'] as num?)?.toDouble() ?? 0.0,
      manganeseMg: (json['manganese_mg'] as num?)?.toDouble() ?? 0.0,
      seleniumMcg: (json['selenium_mcg'] as num?)?.toDouble() ?? 0.0,
      cholesterolMg: (json['cholesterol_mg'] as num?)?.toDouble() ?? 0.0,
      saturatedFatG: (json['saturated_fat_g'] as num?)?.toDouble() ?? 0.0,
      transFatG: (json['trans_fat_g'] as num?)?.toDouble() ?? 0.0,
      monounsaturatedFatG: (json['monounsaturated_fat_g'] as num?)?.toDouble() ?? 0.0,
      polyunsaturatedFatG: (json['polyunsaturated_fat_g'] as num?)?.toDouble() ?? 0.0,
      additionalNutrients: (json['additional_nutrients'] as List<dynamic>?)
          ?.map((e) => AdditionalNutrientDto.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      per: FoodItemDto.fromJson(json['per'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'calories': calories,
      'protein_g': proteinG,
      'carbs_g': carbsG,
      'fat_g': fatG,
      'fiber_g': fiberG,
      'sugar_g': sugarG,
      'sodium_mg': sodiumMg,
      'calcium_mg': calciumMg,
      'iron_mg': ironMg,
      'vitamin_a_iu': vitaminAIu,
      'vitamin_c_mg': vitaminCMg,
      'vitamin_d_iu': vitaminDIu,
      'vitamin_e_mg': vitaminEMg,
      'vitamin_k_mg': vitaminKMg,
      'thiamin_mg': thiaminMg,
      'riboflavin_mg': riboflavinMg,
      'niacin_mg': niacinMg,
      'vitamin_b6_mg': vitaminB6Mg,
      'vitamin_b12_mcg': vitaminB12Mcg,
      'folate_mcg': folateMcg,
      'potassium_mg': potassiumMg,
      'phosphorus_mg': phosphorusMg,
      'magnesium_mg': magnesiumMg,
      'zinc_mg': zincMg,
      'copper_mg': copperMg,
      'manganese_mg': manganeseMg,
      'selenium_mcg': seleniumMcg,
      'cholesterol_mg': cholesterolMg,
      'saturated_fat_g': saturatedFatG,
      'trans_fat_g': transFatG,
      'monounsaturated_fat_g': monounsaturatedFatG,
      'polyunsaturated_fat_g': polyunsaturatedFatG,
      'additional_nutrients': additionalNutrients.map((e) => e.toJson()).toList(),
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
      calciumMg: calciumMg,
      ironMg: ironMg,
      vitaminAIu: vitaminAIu,
      vitaminCMg: vitaminCMg,
      vitaminDIu: vitaminDIu,
      vitaminEMg: vitaminEMg,
      vitaminKMg: vitaminKMg,
      thiaminMg: thiaminMg,
      riboflavinMg: riboflavinMg,
      niacinMg: niacinMg,
      vitaminB6Mg: vitaminB6Mg,
      vitaminB12Mcg: vitaminB12Mcg,
      folateMcg: folateMcg,
      potassiumMg: potassiumMg,
      phosphorusMg: phosphorusMg,
      magnesiumMg: magnesiumMg,
      zincMg: zincMg,
      copperMg: copperMg,
      manganeseMg: manganeseMg,
      seleniumMcg: seleniumMcg,
      cholesterolMg: cholesterolMg,
      saturatedFatG: saturatedFatG,
      transFatG: transFatG,
      monounsaturatedFatG: monounsaturatedFatG,
      polyunsaturatedFatG: polyunsaturatedFatG,
      additionalNutrients: additionalNutrients.map((e) => e.toDomain()).toList(),
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
      calciumMg: nutritionInfo.calciumMg,
      ironMg: nutritionInfo.ironMg,
      vitaminAIu: nutritionInfo.vitaminAIu,
      vitaminCMg: nutritionInfo.vitaminCMg,
      vitaminDIu: nutritionInfo.vitaminDIu,
      vitaminEMg: nutritionInfo.vitaminEMg,
      vitaminKMg: nutritionInfo.vitaminKMg,
      thiaminMg: nutritionInfo.thiaminMg,
      riboflavinMg: nutritionInfo.riboflavinMg,
      niacinMg: nutritionInfo.niacinMg,
      vitaminB6Mg: nutritionInfo.vitaminB6Mg,
      vitaminB12Mcg: nutritionInfo.vitaminB12Mcg,
      folateMcg: nutritionInfo.folateMcg,
      potassiumMg: nutritionInfo.potassiumMg,
      phosphorusMg: nutritionInfo.phosphorusMg,
      magnesiumMg: nutritionInfo.magnesiumMg,
      zincMg: nutritionInfo.zincMg,
      copperMg: nutritionInfo.copperMg,
      manganeseMg: nutritionInfo.manganeseMg,
      seleniumMcg: nutritionInfo.seleniumMcg,
      cholesterolMg: nutritionInfo.cholesterolMg,
      saturatedFatG: nutritionInfo.saturatedFatG,
      transFatG: nutritionInfo.transFatG,
      monounsaturatedFatG: nutritionInfo.monounsaturatedFatG,
      polyunsaturatedFatG: nutritionInfo.polyunsaturatedFatG,
      additionalNutrients: nutritionInfo.additionalNutrients.map((e) => AdditionalNutrientDto.fromDomain(e)).toList(),
      per: FoodItemDto.fromDomain(nutritionInfo.per),
    );
  }
}

class AdditionalNutrientDto {
  final String? id;
  final String name;
  final String unit;
  final double value;

  AdditionalNutrientDto({
    this.id,
    required this.name,
    required this.unit,
    required this.value,
  });

  factory AdditionalNutrientDto.fromJson(Map<String, dynamic> json) {
    return AdditionalNutrientDto(
      id: json['id']?.toString(),
      name: json['name'] as String? ?? '',
      unit: json['unit'] as String? ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'unit': unit,
      'value': value,
    };
  }

  AdditionalNutrient toDomain() {
    return AdditionalNutrient(
      id: id,
      name: name,
      unit: unit,
      value: value,
    );
  }

  static AdditionalNutrientDto fromDomain(AdditionalNutrient nutrient) {
    return AdditionalNutrientDto(
      id: nutrient.id,
      name: nutrient.name,
      unit: nutrient.unit,
      value: nutrient.value,
    );
  }
}
