import 'package:vital_up/features/food_scan/domain/entities/meal_log_entry.dart';
import 'food_item_dto.dart';
import 'nutrition_info_dto.dart';

class MealLogEntryDto {
  final String id;
  final DateTime capturedAt;
  final String imagePath;
  final List<FoodItemDto> items;
  final List<NutritionInfoDto> nutrition;
  final double totalCalories;
  final MealType mealType;
  final bool userConfirmed;

  MealLogEntryDto({
    required this.id,
    required this.capturedAt,
    required this.imagePath,
    required this.items,
    required this.nutrition,
    required this.totalCalories,
    required this.mealType,
    required this.userConfirmed,
  });

  factory MealLogEntryDto.fromJson(Map<String, dynamic> json) {
    return MealLogEntryDto(
      id: json['id'] as String,
      capturedAt: DateTime.parse(json['captured_at'] as String),
      imagePath: json['image_path'] as String,
      items: (json['items'] as List<dynamic>)
          .map((item) => FoodItemDto.fromJson(item as Map<String, dynamic>))
          .toList(),
      nutrition: (json['nutrition'] as List<dynamic>)
          .map((nut) => NutritionInfoDto.fromJson(nut as Map<String, dynamic>))
          .toList(),
      totalCalories: (json['total_calories'] as num).toDouble(),
      mealType: MealType.values[json['meal_type'] as int],
      userConfirmed: json['user_confirmed'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'captured_at': capturedAt.toIso8601String(),
      'image_path': imagePath,
      'items': items.map((item) => item.toJson()).toList(),
      'nutrition': nutrition.map((nut) => nut.toJson()).toList(),
      'total_calories': totalCalories,
      'meal_type': mealType.index,
      'user_confirmed': userConfirmed,
    };
  }

  MealLogEntry toDomain() {
    return MealLogEntry(
      id: id,
      capturedAt: capturedAt,
      imagePath: imagePath,
      items: items.map((item) => item.toDomain()).toList(),
      nutrition: nutrition.map((nut) => nut.toDomain()).toList(),
      totalCalories: totalCalories,
      mealType: mealType,
      userConfirmed: userConfirmed,
    );
  }

  static MealLogEntryDto fromDomain(MealLogEntry entry) {
    return MealLogEntryDto(
      id: entry.id,
      capturedAt: entry.capturedAt,
      imagePath: entry.imagePath,
      items: entry.items.map((item) => FoodItemDto.fromDomain(item)).toList(),
      nutrition: entry.nutrition.map((nut) => NutritionInfoDto.fromDomain(nut)).toList(),
      totalCalories: entry.totalCalories,
      mealType: entry.mealType,
      userConfirmed: entry.userConfirmed,
    );
  }
}
