import 'package:equatable/equatable.dart';

class FoodNutrition extends Equatable {
  final String name;
  final int healthScore;
  final String healthLabel;
  final int totalCalories;
  final List<Ingredient> ingredients;
  final MacroNutrients macros;
  final MealInfo mealInfo;
  final List<String> suggestions;
  final List<String> imagePaths;

  const FoodNutrition({
    required this.name,
    required this.healthScore,
    required this.healthLabel,
    required this.totalCalories,
    required this.ingredients,
    required this.macros,
    required this.mealInfo,
    required this.suggestions,
    required this.imagePaths,
  });

  @override
  List<Object?> get props => [
    name,
    healthScore,
    healthLabel,
    totalCalories,
    ingredients,
    macros,
    mealInfo,
    suggestions,
    imagePaths,
  ];
}

class Ingredient extends Equatable {
  final String name;
  final int calories;

  const Ingredient({required this.name, required this.calories});

  @override
  List<Object?> get props => [name, calories];
}

class MacroNutrients extends Equatable {
  final List<MacroMain> mainMacros;
  final List<MacroDetail> details;
  final int totalGrams;

  const MacroNutrients({
    required this.mainMacros,
    required this.details,
    required this.totalGrams,
  });

  @override
  List<Object?> get props => [mainMacros, details, totalGrams];
}

class MacroMain extends Equatable {
  final String name;
  final int grams;
  final int percent;
  final int colorHex;

  const MacroMain({
    required this.name,
    required this.grams,
    required this.percent,
    required this.colorHex,
  });

  @override
  List<Object?> get props => [name, grams, percent, colorHex];
}

class MacroDetail extends Equatable {
  final String name;
  final int grams;

  const MacroDetail({required this.name, required this.grams});

  @override
  List<Object?> get props => [name, grams];
}

class MealInfo extends Equatable {
  final String title;
  final String time;
  final List<String> points;

  const MealInfo({
    required this.title,
    required this.time,
    required this.points,
  });

  @override
  List<Object?> get props => [title, time, points];
}
