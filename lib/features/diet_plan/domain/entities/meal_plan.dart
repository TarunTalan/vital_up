import 'package:equatable/equatable.dart';

/// One dish that could fill a meal: its foods and nutrition.
class MealOption extends Equatable {
  final List<String> items;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;

  const MealOption({
    required this.items,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  @override
  List<Object?> get props => [items, calories, protein, carbs, fat];
}

class Meal extends Equatable {
  final String name;
  final List<String> items;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;

  /// Other dishes for this meal (the plan generator offers 2), each close
  /// in calories, so one can be swapped in without another AI call.
  final List<MealOption> alternatives;

  const Meal({
    required this.name,
    required this.items,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.alternatives = const [],
  });

  /// The dish this meal has now, as an option.
  MealOption get dish => MealOption(
    items: items,
    calories: calories,
    protein: protein,
    carbs: carbs,
    fat: fat,
  );

  /// This meal with alternative [index] as its dish; the current dish
  /// takes that alternative's place, so swapping back is one more tap.
  Meal withAlternative(int index) {
    final chosen = alternatives[index];
    return Meal(
      name: name,
      items: chosen.items,
      calories: chosen.calories,
      protein: chosen.protein,
      carbs: chosen.carbs,
      fat: chosen.fat,
      alternatives: [
        for (var i = 0; i < alternatives.length; i++)
          i == index ? dish : alternatives[i],
      ],
    );
  }

  @override
  List<Object?> get props => [
    name,
    items,
    calories,
    protein,
    carbs,
    fat,
    alternatives,
  ];
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

  /// The plan with meal [mealIndex] switched to its alternative [option].
  /// Totals move by the difference between the two dishes (the plan's own
  /// totals may differ slightly from the sum of its meals; that gap stays).
  MealPlan withAlternative(int mealIndex, int option) {
    final before = meals[mealIndex];
    final after = before.withAlternative(option);
    int moved(int total, int Function(Meal m) of) {
      final value = total - of(before) + of(after);
      return value < 0 ? 0 : value;
    }

    return MealPlan(
      meals: [
        for (var i = 0; i < meals.length; i++)
          i == mealIndex ? after : meals[i],
      ],
      totalCalories: moved(totalCalories, (m) => m.calories),
      totalProtein: moved(totalProtein, (m) => m.protein),
      totalCarbs: moved(totalCarbs, (m) => m.carbs),
      totalFat: moved(totalFat, (m) => m.fat),
    );
  }

  @override
  List<Object?> get props => [
    meals,
    totalCalories,
    totalProtein,
    totalCarbs,
    totalFat,
  ];
}
