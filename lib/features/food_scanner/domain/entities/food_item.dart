import 'package:equatable/equatable.dart';

class FoodItem extends Equatable {
  final String id;
  final String name;
  final double confidenceScore;
  final String servingDescription;
  final double quantity;
  final String unit;

  const FoodItem({
    required this.id,
    required this.name,
    required this.confidenceScore,
    required this.servingDescription,
    required this.quantity,
    required this.unit,
  });

  FoodItem copyWith({
    String? id,
    String? name,
    double? confidenceScore,
    String? servingDescription,
    double? quantity,
    String? unit,
  }) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      servingDescription: servingDescription ?? this.servingDescription,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        confidenceScore,
        servingDescription,
        quantity,
        unit,
      ];
}
