import 'package:equatable/equatable.dart';
import 'food_item.dart';

class AdditionalNutrient extends Equatable {
  final String? id;
  final String name;
  final String unit;
  final double value;

  const AdditionalNutrient({
    this.id,
    required this.name,
    required this.unit,
    required this.value,
  });

  @override
  List<Object?> get props => [id, name, unit, value];
}

class NutritionInfo extends Equatable {
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
  final List<AdditionalNutrient> additionalNutrients;
  final FoodItem per;

  const NutritionInfo({
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

  NutritionInfo copyWith({
    double? calories,
    double? proteinG,
    double? carbsG,
    double? fatG,
    double? fiberG,
    double? sugarG,
    double? sodiumMg,
    double? calciumMg,
    double? ironMg,
    double? vitaminAIu,
    double? vitaminCMg,
    double? vitaminDIu,
    double? vitaminEMg,
    double? vitaminKMg,
    double? thiaminMg,
    double? riboflavinMg,
    double? niacinMg,
    double? vitaminB6Mg,
    double? vitaminB12Mcg,
    double? folateMcg,
    double? potassiumMg,
    double? phosphorusMg,
    double? magnesiumMg,
    double? zincMg,
    double? copperMg,
    double? manganeseMg,
    double? seleniumMcg,
    double? cholesterolMg,
    double? saturatedFatG,
    double? transFatG,
    double? monounsaturatedFatG,
    double? polyunsaturatedFatG,
    List<AdditionalNutrient>? additionalNutrients,
    FoodItem? per,
  }) {
    return NutritionInfo(
      calories: calories ?? this.calories,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
      fiberG: fiberG ?? this.fiberG,
      sugarG: sugarG ?? this.sugarG,
      sodiumMg: sodiumMg ?? this.sodiumMg,
      calciumMg: calciumMg ?? this.calciumMg,
      ironMg: ironMg ?? this.ironMg,
      vitaminAIu: vitaminAIu ?? this.vitaminAIu,
      vitaminCMg: vitaminCMg ?? this.vitaminCMg,
      vitaminDIu: vitaminDIu ?? this.vitaminDIu,
      vitaminEMg: vitaminEMg ?? this.vitaminEMg,
      vitaminKMg: vitaminKMg ?? this.vitaminKMg,
      thiaminMg: thiaminMg ?? this.thiaminMg,
      riboflavinMg: riboflavinMg ?? this.riboflavinMg,
      niacinMg: niacinMg ?? this.niacinMg,
      vitaminB6Mg: vitaminB6Mg ?? this.vitaminB6Mg,
      vitaminB12Mcg: vitaminB12Mcg ?? this.vitaminB12Mcg,
      folateMcg: folateMcg ?? this.folateMcg,
      potassiumMg: potassiumMg ?? this.potassiumMg,
      phosphorusMg: phosphorusMg ?? this.phosphorusMg,
      magnesiumMg: magnesiumMg ?? this.magnesiumMg,
      zincMg: zincMg ?? this.zincMg,
      copperMg: copperMg ?? this.copperMg,
      manganeseMg: manganeseMg ?? this.manganeseMg,
      seleniumMcg: seleniumMcg ?? this.seleniumMcg,
      cholesterolMg: cholesterolMg ?? this.cholesterolMg,
      saturatedFatG: saturatedFatG ?? this.saturatedFatG,
      transFatG: transFatG ?? this.transFatG,
      monounsaturatedFatG: monounsaturatedFatG ?? this.monounsaturatedFatG,
      polyunsaturatedFatG: polyunsaturatedFatG ?? this.polyunsaturatedFatG,
      additionalNutrients: additionalNutrients ?? this.additionalNutrients,
      per: per ?? this.per,
    );
  }

  NutritionInfo scaledBy(double factor) {
    return NutritionInfo(
      calories: calories * factor,
      proteinG: proteinG * factor,
      carbsG: carbsG * factor,
      fatG: fatG * factor,
      fiberG: fiberG * factor,
      sugarG: sugarG * factor,
      sodiumMg: sodiumMg * factor,
      calciumMg: calciumMg * factor,
      ironMg: ironMg * factor,
      vitaminAIu: vitaminAIu * factor,
      vitaminCMg: vitaminCMg * factor,
      vitaminDIu: vitaminDIu * factor,
      vitaminEMg: vitaminEMg * factor,
      vitaminKMg: vitaminKMg * factor,
      thiaminMg: thiaminMg * factor,
      riboflavinMg: riboflavinMg * factor,
      niacinMg: niacinMg * factor,
      vitaminB6Mg: vitaminB6Mg * factor,
      vitaminB12Mcg: vitaminB12Mcg * factor,
      folateMcg: folateMcg * factor,
      potassiumMg: potassiumMg * factor,
      phosphorusMg: phosphorusMg * factor,
      magnesiumMg: magnesiumMg * factor,
      zincMg: zincMg * factor,
      copperMg: copperMg * factor,
      manganeseMg: manganeseMg * factor,
      seleniumMcg: seleniumMcg * factor,
      cholesterolMg: cholesterolMg * factor,
      saturatedFatG: saturatedFatG * factor,
      transFatG: transFatG * factor,
      monounsaturatedFatG: monounsaturatedFatG * factor,
      polyunsaturatedFatG: polyunsaturatedFatG * factor,
      additionalNutrients: additionalNutrients.map((n) => AdditionalNutrient(
        id: n.id,
        name: n.name,
        unit: n.unit,
        value: n.value * factor,
      )).toList(),
      per: per.copyWith(quantity: per.quantity * factor),
    );
  }

  @override
  List<Object?> get props => [
        calories,
        proteinG,
        carbsG,
        fatG,
        fiberG,
        sugarG,
        sodiumMg,
        calciumMg,
        ironMg,
        vitaminAIu,
        vitaminCMg,
        vitaminDIu,
        vitaminEMg,
        vitaminKMg,
        thiaminMg,
        riboflavinMg,
        niacinMg,
        vitaminB6Mg,
        vitaminB12Mcg,
        folateMcg,
        potassiumMg,
        phosphorusMg,
        magnesiumMg,
        zincMg,
        copperMg,
        manganeseMg,
        seleniumMcg,
        cholesterolMg,
        saturatedFatG,
        transFatG,
        monounsaturatedFatG,
        polyunsaturatedFatG,
        additionalNutrients,
        per,
      ];
}
