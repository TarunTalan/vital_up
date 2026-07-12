import 'package:equatable/equatable.dart';
import 'package:vital_up/features/food_scanner/domain/entities/meal_log_entry.dart';
import 'dart:io';

abstract class FoodScanEvent extends Equatable {
  const FoodScanEvent();

  @override
  List<Object?> get props => [];
}

class CaptureImageRequested extends FoodScanEvent {}

class ImageSelected extends FoodScanEvent {
  final File image;

  const ImageSelected(this.image);

  @override
  List<Object?> get props => [image];
}

class RecognizeFoodRequested extends FoodScanEvent {}

class AdjustPortionRequested extends FoodScanEvent {
  final String itemId;
  final double newQuantity;

  const AdjustPortionRequested(this.itemId, this.newQuantity);

  @override
  List<Object?> get props => [itemId, newQuantity];
}

class RemoveDetectedItemRequested extends FoodScanEvent {
  final String itemId;

  const RemoveDetectedItemRequested(this.itemId);

  @override
  List<Object?> get props => [itemId];
}

class AddManualItemRequested extends FoodScanEvent {
  final String name;
  final double quantity;
  final String unit;

  const AddManualItemRequested({
    required this.name,
    required this.quantity,
    required this.unit,
  });

  @override
  List<Object?> get props => [name, quantity, unit];
}

class EditFoodItemRequested extends FoodScanEvent {
  final String itemId;
  final String name;
  final double quantity;
  final String unit;

  const EditFoodItemRequested({
    required this.itemId,
    required this.name,
    required this.quantity,
    required this.unit,
  });

  @override
  List<Object?> get props => [itemId, name, quantity, unit];
}

class ConfirmAndSaveRequested extends FoodScanEvent {
  final MealType mealType;

  const ConfirmAndSaveRequested(this.mealType);

  @override
  List<Object?> get props => [mealType];
}

class ScanBarcodeRequested extends FoodScanEvent {
  final String barcode;

  const ScanBarcodeRequested(this.barcode);

  @override
  List<Object?> get props => [barcode];
}

class RetryRecognitionRequested extends FoodScanEvent {}

class UpdateMealImageRequested extends FoodScanEvent {
  final File image;

  const UpdateMealImageRequested(this.image);

  @override
  List<Object?> get props => [image];
}
