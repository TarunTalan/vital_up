import 'package:equatable/equatable.dart';

class NutritionTarget extends Equatable {
  final int calories;
  final int protein;
  final int carbs;
  final int fat;

  const NutritionTarget({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  @override
  List<Object?> get props => [calories, protein, carbs, fat];
}
