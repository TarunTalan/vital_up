import 'package:equatable/equatable.dart';
import 'package:vital_up/features/food_scanner/domain/entities/meal_log_entry.dart';

abstract class MealLogState extends Equatable {
  const MealLogState();

  @override
  List<Object?> get props => [];
}

class MealLogLoading extends MealLogState {
  const MealLogLoading();
}

class MealLogLoaded extends MealLogState {
  final List<MealLogEntry> entries;
  final double totalCalories;
  final double totalProteinG;
  final double totalCarbsG;
  final double totalFatG;
  final int? dailyCalorieGoal;

  const MealLogLoaded({
    required this.entries,
    required this.totalCalories,
    required this.totalProteinG,
    required this.totalCarbsG,
    required this.totalFatG,
    this.dailyCalorieGoal,
  });

  /// Convenience: meals grouped by MealType (for the dashboard slot row).
  Set<MealType> get loggedMealTypes =>
      entries.map((e) => e.mealType).toSet();

  /// Calorie progress 0.0–1.0. Returns null if no goal is set.
  double? get calorieProgress {
    if (dailyCalorieGoal == null || dailyCalorieGoal! <= 0) return null;
    return (totalCalories / dailyCalorieGoal!).clamp(0.0, 1.0);
  }

  @override
  List<Object?> get props => [
        entries, totalCalories, totalProteinG, totalCarbsG, totalFatG,
        dailyCalorieGoal,
      ];
}

class MealLogError extends MealLogState {
  final String message;
  const MealLogError(this.message);

  @override
  List<Object?> get props => [message];
}
