import 'package:equatable/equatable.dart';
import 'food_item.dart';
import 'nutrition_info.dart';

enum MealType {
  breakfast,
  lunch,
  dinner,
  snack,
}

class MealLogEntry extends Equatable {
  final String id;
  final DateTime capturedAt;
  final String imagePath;
  final List<FoodItem> items;
  final List<NutritionInfo> nutrition;
  final double totalCalories;
  final MealType mealType;
  final bool userConfirmed;

  const MealLogEntry({
    required this.id,
    required this.capturedAt,
    required this.imagePath,
    required this.items,
    required this.nutrition,
    required this.totalCalories,
    required this.mealType,
    required this.userConfirmed,
  });

  MealLogEntry copyWith({
    String? id,
    DateTime? capturedAt,
    String? imagePath,
    List<FoodItem>? items,
    List<NutritionInfo>? nutrition,
    double? totalCalories,
    MealType? mealType,
    bool? userConfirmed,
  }) {
    return MealLogEntry(
      id: id ?? this.id,
      capturedAt: capturedAt ?? this.capturedAt,
      imagePath: imagePath ?? this.imagePath,
      items: items ?? this.items,
      nutrition: nutrition ?? this.nutrition,
      totalCalories: totalCalories ?? this.totalCalories,
      mealType: mealType ?? this.mealType,
      userConfirmed: userConfirmed ?? this.userConfirmed,
    );
  }

  static MealType mealTypeFromTime(DateTime dateTime) {
    final hour = dateTime.hour;
    if (hour >= 5 && hour < 11) {
      return MealType.breakfast;
    } else if (hour >= 11 && hour < 15) {
      return MealType.lunch;
    } else if (hour >= 15 && hour < 21) {
      return MealType.dinner;
    } else {
      return MealType.snack;
    }
  }

  @override
  List<Object?> get props => [
        id,
        capturedAt,
        imagePath,
        items,
        nutrition,
        totalCalories,
        mealType,
        userConfirmed,
      ];
}
