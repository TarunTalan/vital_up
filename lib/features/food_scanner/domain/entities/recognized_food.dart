import 'package:equatable/equatable.dart';
import 'package:vital_up/features/food_scanner/domain/entities/food_item.dart';
import 'package:vital_up/features/food_scanner/domain/entities/nutrition_info.dart';

/// One food detected in a photo.
///
/// The recognizer usually returns [nutrition] for the estimated portion in
/// the same response, so no follow-up lookup is needed. When it doesn't,
/// [lookupKey] (a USDA FDC id or the food name) resolves it via
/// `NutritionRepository.getNutrition`.
class RecognizedFood extends Equatable {
  final FoodItem item;
  final NutritionInfo? nutrition;
  final String lookupKey;

  const RecognizedFood({
    required this.item,
    required this.lookupKey,
    this.nutrition,
  });

  @override
  List<Object?> get props => [item, nutrition, lookupKey];
}
