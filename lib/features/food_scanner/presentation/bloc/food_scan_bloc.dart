import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/features/food_scanner/domain/entities/food_item.dart';
import 'package:vital_up/features/food_scanner/domain/entities/meal_log_entry.dart';
import 'package:vital_up/features/food_scanner/domain/entities/nutrition_info.dart';
import 'package:vital_up/features/food_scanner/domain/repositories/nutrition_repository.dart';
import 'package:vital_up/features/food_scanner/domain/usecases/get_meal_recommendation.dart';
import 'package:vital_up/features/food_scanner/domain/usecases/scan_barcode.dart';
import 'package:vital_up/features/food_scanner/domain/usecases/scan_food_image.dart';
import 'package:vital_up/features/food_scanner/domain/usecases/save_meal_log.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/food_scan_event.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/food_scan_state.dart';

class FoodScanBloc extends Bloc<FoodScanEvent, FoodScanState> {
  final ScanFoodImage scanFoodImage;
  final ScanBarcode scanBarcode;
  final SaveMealLog saveMealLog;
  final GetMealRecommendation getMealRecommendation;
  final NutritionRepository nutritionRepository;
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
    required this.nutritionRepository,
    required this.uuid,
    required this.logger,
  }) : super(ScanIdle()) {
    on<CaptureImageRequested>(_onCaptureImageRequested);
    on<ImageSelected>(_onImageSelected);
    on<RecognizeFoodRequested>(_onRecognizeFoodRequested);
    on<AdjustPortionRequested>(_onAdjustPortionRequested);
    on<RemoveDetectedItemRequested>(_onRemoveDetectedItemRequested);
    on<AddManualItemRequested>(_onAddManualItemRequested);
    on<EditFoodItemRequested>(_onEditFoodItemRequested);
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
        logger.i('Nutrition list received: ${nutritionList.length} items');
        _currentNutrition = nutritionList;
        _currentItems = nutritionList.map((nut) => nut.per).toList();

        logger.d('Current items: $_currentItems');
        logger.d('Current nutrition: $_currentNutrition');

        final hasLowConfidence = _currentItems.any((item) => item.confidenceScore < 0.7);

        if (hasLowConfidence) {
          logger.w('Emitting RecognitionLowConfidence due to low confidence item(s)');
          emit(RecognitionLowConfidence(
            image: _currentImage!,
            items: _currentItems,
            nutrition: _currentNutrition,
          ));
        } else {
          logger.i('Emitting RecognitionSucceeded');
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
    // Emit loading state
    emit(LoadingNutrition(
      image: _currentImage,
      items: _currentItems,
      nutrition: _currentNutrition,
    ));

    // Search for the food name to get the correct fdc_id
    final searchResult = await nutritionRepository.searchByName(event.name);

    Failure? searchFailure;
    List<FoodItem>? searchResultsList;

    searchResult.fold(
      (l) => searchFailure = l,
      (r) => searchResultsList = r,
    );

    if (searchFailure != null || searchResultsList == null) {
      logger.e('Failed to search for manual food: $searchFailure');
      // If search fails, add with placeholder nutrition
      final newItem = FoodItem(
        id: uuid.v4(),
        name: event.name,
        confidenceScore: 1.0,
        servingDescription: '${event.quantity} ${event.unit}',
        quantity: event.quantity,
        unit: event.unit,
      );
      
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

      _emitCurrentState(emit);
      return;
    }

    if (searchResultsList!.isEmpty) {
      logger.e('No search results for: ${event.name}');
      // Add with placeholder nutrition
      final newItem = FoodItem(
        id: uuid.v4(),
        name: event.name,
        confidenceScore: 1.0,
        servingDescription: '${event.quantity} ${event.unit}',
        quantity: event.quantity,
        unit: event.unit,
      );
      
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

      _emitCurrentState(emit);
      return;
    }

    // Use the first search result
    final searchItem = searchResultsList!.first;
    
    final newItem = FoodItem(
      id: searchItem.id,
      name: event.name,
      confidenceScore: 1.0,
      servingDescription: '${event.quantity} ${event.unit}',
      quantity: event.quantity,
      unit: event.unit,
    );

    // Fetch nutrition for the manual item
    final nutritionResult = await nutritionRepository.getNutrition(newItem);

    Failure? nutritionFailure;
    NutritionInfo? nutritionInfo;

    nutritionResult.fold(
      (l) => nutritionFailure = l,
      (r) => nutritionInfo = r,
    );

    if (nutritionFailure != null || nutritionInfo == null) {
      logger.e('Failed to fetch nutrition for manual item: $nutritionFailure');
      // If nutrition fetch fails, add with zero nutrition
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

      _emitCurrentState(emit);
      return;
    }

    _currentItems.add(newItem);
    _currentNutrition.add(nutritionInfo!);

    _emitCurrentState(emit);
  }

  Future<void> _onEditFoodItemRequested(
    EditFoodItemRequested event,
    Emitter<FoodScanState> emit,
  ) async {
    final itemIndex = _currentItems.indexWhere((item) => item.id == event.itemId);
    if (itemIndex == -1) return;

    // Emit loading state
    emit(LoadingNutrition(
      image: _currentImage,
      items: _currentItems,
      nutrition: _currentNutrition,
    ));

    // Search for the new food name to get the correct fdc_id
    final searchResult = await nutritionRepository.searchByName(event.name);

    Failure? searchFailure;
    List<FoodItem>? searchResultsList;

    searchResult.fold(
      (l) => searchFailure = l,
      (r) => searchResultsList = r,
    );

    if (searchFailure != null || searchResultsList == null) {
      logger.e('Failed to search for edited food: $searchFailure');
      // If search fails, scale existing nutrition by quantity change
      final oldItem = _currentItems[itemIndex];
      final oldNutrition = _currentNutrition[itemIndex];
      final scaleFactor = event.quantity / oldItem.quantity;
      
      final updatedItem = FoodItem(
        id: event.itemId,
        name: event.name,
        confidenceScore: _currentItems[itemIndex].confidenceScore,
        servingDescription: '${event.quantity} ${event.unit}',
        quantity: event.quantity,
        unit: event.unit,
      );
      
      _currentItems[itemIndex] = updatedItem;
      _currentNutrition[itemIndex] = oldNutrition.scaledBy(scaleFactor);
      
      _emitCurrentState(emit);
      return;
    }

    if (searchResultsList!.isEmpty) {
      logger.e('No search results for: ${event.name}');
      // Scale existing nutrition by quantity change
      final oldItem = _currentItems[itemIndex];
      final oldNutrition = _currentNutrition[itemIndex];
      final scaleFactor = event.quantity / oldItem.quantity;
      
      final updatedItem = FoodItem(
        id: event.itemId,
        name: event.name,
        confidenceScore: _currentItems[itemIndex].confidenceScore,
        servingDescription: '${event.quantity} ${event.unit}',
        quantity: event.quantity,
        unit: event.unit,
      );
      
      _currentItems[itemIndex] = updatedItem;
      _currentNutrition[itemIndex] = oldNutrition.scaledBy(scaleFactor);
      
      _emitCurrentState(emit);
      return;
    }

    // Use the first search result
    final searchItem = searchResultsList!.first;
    
    final updatedItem = FoodItem(
      id: searchItem.id,
      name: event.name,
      confidenceScore: _currentItems[itemIndex].confidenceScore,
      servingDescription: '${event.quantity} ${event.unit}',
      quantity: event.quantity,
      unit: event.unit,
    );

    // Fetch nutrition for the updated item with new fdc_id
    final nutritionResult = await nutritionRepository.getNutrition(updatedItem);

    Failure? nutritionFailure;
    NutritionInfo? nutritionInfo;

    nutritionResult.fold(
      (l) => nutritionFailure = l,
      (r) => nutritionInfo = r,
    );

    if (nutritionFailure != null || nutritionInfo == null) {
      logger.e('Failed to fetch nutrition for edited item: $nutritionFailure');
      // If nutrition fetch fails, scale existing nutrition by quantity change
      final oldItem = _currentItems[itemIndex];
      final oldNutrition = _currentNutrition[itemIndex];
      final scaleFactor = event.quantity / oldItem.quantity;
      
      _currentItems[itemIndex] = updatedItem;
      _currentNutrition[itemIndex] = oldNutrition.scaledBy(scaleFactor);
      
      _emitCurrentState(emit);
      return;
    }

    _currentItems[itemIndex] = updatedItem;
    _currentNutrition[itemIndex] = nutritionInfo!;
    
    _emitCurrentState(emit);
  }

  void _emitCurrentState(Emitter<FoodScanState> emit) {
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
    } else {
      // Default to RecognitionSucceeded if we have data
      if (_currentImage != null && _currentItems.isNotEmpty) {
        emit(RecognitionSucceeded(
          image: _currentImage!,
          items: _currentItems,
          nutrition: _currentNutrition,
        ));
      }
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
