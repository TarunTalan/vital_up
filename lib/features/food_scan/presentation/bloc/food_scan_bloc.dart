import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/features/food_scan/domain/entities/food_item.dart';
import 'package:vital_up/features/food_scan/domain/entities/meal_log_entry.dart';
import 'package:vital_up/features/food_scan/domain/entities/nutrition_info.dart';
import 'package:vital_up/features/food_scan/domain/usecases/get_meal_recommendation.dart';
import 'package:vital_up/features/food_scan/domain/usecases/scan_barcode.dart';
import 'package:vital_up/features/food_scan/domain/usecases/scan_food_image.dart';
import 'package:vital_up/features/food_scan/domain/usecases/save_meal_log.dart';
import 'package:vital_up/features/food_scan/presentation/bloc/food_scan_event.dart';
import 'package:vital_up/features/food_scan/presentation/bloc/food_scan_state.dart';

class FoodScanBloc extends Bloc<FoodScanEvent, FoodScanState> {
  final ScanFoodImage scanFoodImage;
  final ScanBarcode scanBarcode;
  final SaveMealLog saveMealLog;
  final GetMealRecommendation getMealRecommendation;
  final Uuid uuid;
  final Logger logger;

  File? _currentImage;
  List<FoodItem> _currentItems = [];
  List<NutritionInfo> _currentNutrition = [];

  FoodScanBloc({
    required this.scanFoodImage,
    required this.scanBarcode,
    required this.saveMealLog,
    required this.getMealRecommendation,
    required this.uuid,
    required this.logger,
  }) : super(ScanIdle()) {
    on<CaptureImageRequested>(_onCaptureImageRequested);
    on<ImageSelected>(_onImageSelected);
    on<RecognizeFoodRequested>(_onRecognizeFoodRequested);
    on<AdjustPortionRequested>(_onAdjustPortionRequested);
    on<RemoveDetectedItemRequested>(_onRemoveDetectedItemRequested);
    on<AddManualItemRequested>(_onAddManualItemRequested);
    on<ConfirmAndSaveRequested>(_onConfirmAndSaveRequested);
    on<ScanBarcodeRequested>(_onScanBarcodeRequested);
    on<RetryRecognitionRequested>(_onRetryRecognitionRequested);
  }

  Future<void> _onCaptureImageRequested(
    CaptureImageRequested event,
    Emitter<FoodScanState> emit,
  ) async {
    // This would typically open camera/gallery
    // For now, we'll emit a state that the UI can use to trigger the picker
    emit(ScanIdle());
  }

  Future<void> _onImageSelected(
    ImageSelected event,
    Emitter<FoodScanState> emit,
  ) async {
    _currentImage = event.image;
    emit(ImageCaptured(event.image));
  }

  Future<void> _onRecognizeFoodRequested(
    RecognizeFoodRequested event,
    Emitter<FoodScanState> emit,
  ) async {
    if (_currentImage == null) {
      emit(RecognitionFailed(
        ValidationFailure('No image selected. Please capture or select an image first.'),
      ));
      return;
    }

    emit(RecognizingFood(_currentImage!));

    final result = await scanFoodImage(_currentImage!);

    logger.d('ScanFoodImage result: $result');

    result.fold(
      (failure) {
        logger.e('Recognition failed: $failure');
        emit(RecognitionFailed(failure, image: _currentImage));
      },
      (nutritionList) {
        logger.d('Nutrition list received: ${nutritionList.length} items');
        _currentNutrition = nutritionList;
        _currentItems = nutritionList.map((nut) => nut.per).toList();

        logger.d('Current items: $_currentItems');
        logger.d('Current nutrition: $_currentNutrition');

        final hasLowConfidence = _currentItems.any((item) => item.confidenceScore < 0.7);

        if (hasLowConfidence) {
          logger.d('Emitting RecognitionLowConfidence');
          emit(RecognitionLowConfidence(
            image: _currentImage!,
            items: _currentItems,
            nutrition: _currentNutrition,
          ));
        } else {
          logger.d('Emitting RecognitionSucceeded');
          emit(RecognitionSucceeded(
            image: _currentImage!,
            items: _currentItems,
            nutrition: _currentNutrition,
          ));
        }
      },
    );
  }

  Future<void> _onAdjustPortionRequested(
    AdjustPortionRequested event,
    Emitter<FoodScanState> emit,
  ) async {
    final itemIndex = _currentItems.indexWhere((item) => item.id == event.itemId);
    if (itemIndex == -1) return;

    final oldItem = _currentItems[itemIndex];
    final oldNutrition = _currentNutrition[itemIndex];

    final scaleFactor = event.newQuantity / oldItem.quantity;

    final newItem = oldItem.copyWith(quantity: event.newQuantity);
    final newNutrition = oldNutrition.scaledBy(scaleFactor);

    _currentItems[itemIndex] = newItem;
    _currentNutrition[itemIndex] = newNutrition;

    if (state is RecognitionSucceeded) {
      emit(RecognitionSucceeded(
        image: _currentImage!,
        items: _currentItems,
        nutrition: _currentNutrition,
      ));
    } else if (state is RecognitionLowConfidence) {
      emit(RecognitionLowConfidence(
        image: _currentImage!,
        items: _currentItems,
        nutrition: _currentNutrition,
      ));
    } else if (state is NutritionLoaded) {
      emit(NutritionLoaded(
        image: _currentImage!,
        items: _currentItems,
        nutrition: _currentNutrition,
      ));
    }
  }

  Future<void> _onRemoveDetectedItemRequested(
    RemoveDetectedItemRequested event,
    Emitter<FoodScanState> emit,
  ) async {
    final itemIndex = _currentItems.indexWhere((item) => item.id == event.itemId);
    if (itemIndex == -1) return;

    _currentItems.removeAt(itemIndex);
    _currentNutrition.removeAt(itemIndex);

    if (_currentItems.isEmpty) {
      emit(RecognitionFailed(
        NoFoodDetectedFailure('All items removed. Please try again.'),
        image: _currentImage,
      ));
      return;
    }

    if (state is RecognitionSucceeded) {
      emit(RecognitionSucceeded(
        image: _currentImage!,
        items: _currentItems,
        nutrition: _currentNutrition,
      ));
    } else if (state is RecognitionLowConfidence) {
      emit(RecognitionLowConfidence(
        image: _currentImage!,
        items: _currentItems,
        nutrition: _currentNutrition,
      ));
    } else if (state is NutritionLoaded) {
      emit(NutritionLoaded(
        image: _currentImage!,
        items: _currentItems,
        nutrition: _currentNutrition,
      ));
    }
  }

  Future<void> _onAddManualItemRequested(
    AddManualItemRequested event,
    Emitter<FoodScanState> emit,
  ) async {
    final newItem = FoodItem(
      id: uuid.v4(),
      name: event.name,
      confidenceScore: 1.0,
      servingDescription: '${event.quantity} ${event.unit}',
      quantity: event.quantity,
      unit: event.unit,
    );

    // For manual items, we'll need to fetch nutrition
    // For now, we'll add with placeholder nutrition
    final placeholderNutrition = NutritionInfo(
      calories: 0,
      proteinG: 0,
      carbsG: 0,
      fatG: 0,
      fiberG: 0,
      sugarG: 0,
      sodiumMg: 0,
      per: newItem,
    );

    _currentItems.add(newItem);
    _currentNutrition.add(placeholderNutrition);

    if (state is RecognitionSucceeded) {
      emit(RecognitionSucceeded(
        image: _currentImage!,
        items: _currentItems,
        nutrition: _currentNutrition,
      ));
    } else if (state is RecognitionLowConfidence) {
      emit(RecognitionLowConfidence(
        image: _currentImage!,
        items: _currentItems,
        nutrition: _currentNutrition,
      ));
    } else if (state is NutritionLoaded) {
      emit(NutritionLoaded(
        image: _currentImage!,
        items: _currentItems,
        nutrition: _currentNutrition,
      ));
    }
  }

  Future<void> _onConfirmAndSaveRequested(
    ConfirmAndSaveRequested event,
    Emitter<FoodScanState> emit,
  ) async {
    if (_currentImage == null || _currentItems.isEmpty) {
      emit(RecognitionFailed(
        ValidationFailure('No items to save. Please add food items first.'),
      ));
      return;
    }

    emit(SavingMealLog());

    final totalCalories = _currentNutrition.fold<double>(
      0,
      (sum, nut) => sum + nut.calories,
    );

    final entry = MealLogEntry(
      id: uuid.v4(),
      capturedAt: DateTime.now(),
      imagePath: _currentImage!.path,
      items: _currentItems,
      nutrition: _currentNutrition,
      totalCalories: totalCalories,
      mealType: event.mealType,
      userConfirmed: true,
    );

    final result = await saveMealLog(entry);

    result.fold(
      (failure) {
        emit(RecognitionFailed(failure, image: _currentImage));
      },
      (savedEntry) {
        emit(MealLogSaved(savedEntry));
        _reset();
      },
    );
  }

  Future<void> _onScanBarcodeRequested(
    ScanBarcodeRequested event,
    Emitter<FoodScanState> emit,
  ) async {
    emit(BarcodeScanning());

    final result = await scanBarcode(event.barcode);

    result.fold(
      (failure) {
        emit(RecognitionFailed(failure));
      },
      (item) {
        emit(BarcodeScanned(item));
      },
    );
  }

  Future<void> _onRetryRecognitionRequested(
    RetryRecognitionRequested event,
    Emitter<FoodScanState> emit,
  ) async {
    if (_currentImage != null) {
      add(RecognizeFoodRequested());
    }
  }

  void _reset() {
    _currentImage = null;
    _currentItems = [];
    _currentNutrition = [];
  }
}
