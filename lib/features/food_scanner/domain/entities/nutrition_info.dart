import 'package:equatable/equatable.dart';
import 'food_item.dart';

class NutritionInfo extends Equatable {
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;
  final double sugarG;
  final double sodiumMg;
  final FoodItem per;

  const NutritionInfo({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
    required this.sugarG,
    required this.sodiumMg,
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
        per,
      ];
}
