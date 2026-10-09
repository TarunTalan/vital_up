import 'package:vital_up/features/food_scanner/domain/entities/food_item.dart';
import 'package:vital_up/features/food_scanner/domain/nutrition_sanity.dart';

class FoodItemDto {
  final String id;
  final String name;
  final double confidenceScore;
  final String servingDescription;
  final double quantity;
  final String unit;
  final String? fdcId;

  FoodItemDto({
    required this.id,
    required this.name,
    required this.confidenceScore,
    required this.servingDescription,
    required this.quantity,
    required this.unit,
    this.fdcId,
  });

  /// Tolerates ids sent as numbers and clamps AI values (confidence 0..1,
  /// a usable quantity, clean single-line text).
  factory FoodItemDto.fromJson(Map<String, dynamic> json) {
    String? text(Object? v) => v?.toString();
    final unit = saneFoodName(json['unit'] ?? json['serving_unit']);
    return FoodItemDto(
      id: text(json['id']) ?? text(json['food_id']) ?? '',
      name: saneFoodName(json['name'] ?? json['food_name']),
      confidenceScore: saneConfidence(json['confidence_score']),
      servingDescription: saneFoodName(json['serving_description']),
      quantity: saneQuantity(json['quantity']),
      unit: unit.isEmpty ? 'serving' : unit,
      fdcId: text(json['fdc_id']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'confidence_score': confidenceScore,
      'serving_description': servingDescription,
      'quantity': quantity,
      'unit': unit,
      if (fdcId != null) 'fdc_id': fdcId,
    };
  }

  FoodItem toDomain() {
    return FoodItem(
      id: id,
      name: name,
      confidenceScore: confidenceScore,
      servingDescription: servingDescription,
      quantity: quantity,
      unit: unit,
    );
  }

  static FoodItemDto fromDomain(FoodItem foodItem) {
    return FoodItemDto(
      id: foodItem.id,
      name: foodItem.name,
      confidenceScore: foodItem.confidenceScore,
      servingDescription: foodItem.servingDescription,
      quantity: foodItem.quantity,
      unit: foodItem.unit,
    );
  }
}
