import 'package:vital_up/features/food_scan/domain/entities/food_item.dart';

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

  factory FoodItemDto.fromJson(Map<String, dynamic> json) {
    return FoodItemDto(
      id: json['id'] as String? ?? json['food_id']?.toString() ?? '',
      name: json['name'] as String? ?? json['food_name'] ?? '',
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.0,
      servingDescription: json['serving_description'] as String? ?? json['serving_description'] ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: json['unit'] as String? ?? json['serving_unit'] ?? 'serving',
      fdcId: json['fdc_id'] as String?,
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
