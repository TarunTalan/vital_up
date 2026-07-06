import 'package:equatable/equatable.dart';

class FoodNutrition extends Equatable {
  final String name;
  final int healthScore;
  final String healthLabel;
  final int totalCalories;
  final List<Ingredient> ingredients;
  final MacroNutrients macros;
  final String mealType;
  final String mealTime;
  final String mealMessage;
  final List<String> suggestions;
  final List<String> imagePaths;

  const FoodNutrition({
    required this.name,
    required this.healthScore,
    required this.healthLabel,
    required this.totalCalories,
    required this.ingredients,
    required this.macros,
    required this.mealType,
    required this.mealTime,
    required this.mealMessage,
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
    mealType,
    mealTime,
    mealMessage,
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
  final double proteinGrams;
  final int proteinPercent;
  final double carbsGrams;
  final int carbsPercent;
  final double fatGrams;
  final int fatPercent;

  const MacroNutrients({
    required this.proteinGrams,
    required this.proteinPercent,
    required this.carbsGrams,
    required this.carbsPercent,
    required this.fatGrams,
    required this.fatPercent,
  });

  @override
  List<Object?> get props => [
    proteinGrams,
    proteinPercent,
    carbsGrams,
    carbsPercent,
    fatGrams,
    fatPercent,
  ];
}
