import 'package:equatable/equatable.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/features/food_scanner/domain/entities/food_item.dart';
import 'package:vital_up/features/food_scanner/domain/entities/meal_log_entry.dart';
import 'package:vital_up/features/food_scanner/domain/entities/nutrition_info.dart';
import 'dart:io';

abstract class FoodScanState extends Equatable {
  const FoodScanState();

  @override
  List<Object?> get props => [];
}

class ScanIdle extends FoodScanState {
  const ScanIdle();
}

class ImageCaptured extends FoodScanState {
  final File image;

  const ImageCaptured(this.image);

  @override
  List<Object?> get props => [image];
}

class RecognizingFood extends FoodScanState {
  final File image;

  const RecognizingFood(this.image);

  @override
  List<Object?> get props => [image];
}

class BarcodeScanning extends FoodScanState {
  const BarcodeScanning();
}

class LoadingNutrition extends FoodScanState {
  final File? image;
  final List<FoodItem> items;
  final List<NutritionInfo> nutrition;

  const LoadingNutrition({
    this.image,
    required this.items,
    required this.nutrition,
  });

  @override
  List<Object?> get props => [image, items, nutrition];
}

class RecognitionSucceeded extends FoodScanState {
  final File image;
  final List<FoodItem> items;
  final List<NutritionInfo> nutrition;

  const RecognitionSucceeded({
    required this.image,
    required this.items,
    required this.nutrition,
  });

  @override
  List<Object?> get props => [image, items, nutrition];
}

class RecognitionLowConfidence extends FoodScanState {
  final File image;
  final List<FoodItem> items;
  final List<NutritionInfo> nutrition;

  const RecognitionLowConfidence({
    required this.image,
    required this.items,
    required this.nutrition,
  });

  @override
  List<Object?> get props => [image, items, nutrition];
}

class RecognitionFailed extends FoodScanState {
  final Failure failure;
  final File? image;

  const RecognitionFailed(this.failure, {this.image});

  @override
  List<Object?> get props => [failure, image];
}

class NutritionLoaded extends FoodScanState {
  final File? image;
  final List<FoodItem> items;
  final List<NutritionInfo> nutrition;

  const NutritionLoaded({
    this.image,
    required this.items,
    required this.nutrition,
  });

  @override
  List<Object?> get props => [image, items, nutrition];
}

/// Saving the reviewed meal. Carries the items so the detail page keeps
/// showing them (with a busy button) while the save runs.
class SavingMealLog extends FoodScanState {
  final File? image;
  final List<FoodItem> items;
  final List<NutritionInfo> nutrition;

  const SavingMealLog({
    this.image,
    this.items = const [],
    this.nutrition = const [],
  });

  @override
  List<Object?> get props => [image, items, nutrition];
}

/// An action on the reviewed meal (save, edit, add) failed. Shown as a
/// snackbar by the detail page; the bloc then returns to the previous
/// content state, so the user keeps their items.
class ScanActionFailed extends FoodScanState {
  final Failure failure;

  const ScanActionFailed(this.failure);

  @override
  List<Object?> get props => [failure];
}

class MealLogSaved extends FoodScanState {
  final MealLogEntry entry;

  const MealLogSaved(this.entry);

  @override
  List<Object?> get props => [entry];
}

class BarcodeScanned extends FoodScanState {
  final FoodItem item;

  const BarcodeScanned(this.item);

  @override
  List<Object?> get props => [item];
}
