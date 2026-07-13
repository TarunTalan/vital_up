import 'package:equatable/equatable.dart';

class Meal extends Equatable {
  final String name;
  final List<String> items;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;

  const Meal({
    required this.name,
    required this.items,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  @override
  List<Object?> get props => [name, items, calories, protein, carbs, fat];
}

class MealPlan extends Equatable {
  final List<Meal> meals;
  final int totalCalories;
  final int totalProtein;
  final int totalCarbs;
  final int totalFat;

  const MealPlan({
    required this.meals,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
  });

  @override
  List<Object?> get props => [
        meals,
        totalCalories,
        totalProtein,
        totalCarbs,
        totalFat,
      ];
}
