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
  // Tracks the state type we were in before entering LoadingNutrition,
  // so _emitCurrentState can return to the correct state.
  Type? _preLoadingStateType;

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
    on<UpdateMealImageRequested>(_onUpdateMealImageRequested);
  }

  @override
  void onChange(Change<FoodScanState> change) {
    super.onChange(change);
    logger.i('FoodScanBloc State Change: ${change.currentState.runtimeType} -> ${change.nextState.runtimeType}');
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
        
        final resolvedList = <NutritionInfo>[];
        for (final nut in nutritionList) {
          if (_isZeroPlaceholder(nut)) {
            logger.w('Scanned item "${nut.per.name}" is all zeros (placeholder). Resolving offline.');
            resolvedList.add(_estimateOfflineNutrition(nut.per));
          } else {
            resolvedList.add(nut);
          }
        }

        _currentNutrition = resolvedList;
        _currentItems = resolvedList.map((nut) => nut.per).toList();

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

    // Re-assign new list instances to prevent mutating previous state's lists in-place
    _currentItems = List<FoodItem>.of(_currentItems)..[itemIndex] = newItem;
    _currentNutrition = List<NutritionInfo>.of(_currentNutrition)..[itemIndex] = newNutrition;

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
        image: _currentImage,
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

    // Re-assign new list instances to prevent mutating previous state's lists in-place
    _currentItems = List<FoodItem>.of(_currentItems)..removeAt(itemIndex);
    _currentNutrition = List<NutritionInfo>.of(_currentNutrition)..removeAt(itemIndex);

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
        image: _currentImage,
        items: _currentItems,
        nutrition: _currentNutrition,
      ));
    }
  }

  Future<void> _onAddManualItemRequested(
    AddManualItemRequested event,
    Emitter<FoodScanState> emit,
  ) async {
    // Remember state before loading so we can return to it after fetch
    _preLoadingStateType = state.runtimeType;
    // Emit loading state
    emit(LoadingNutrition(
      image: _currentImage,
      items: _currentItems,
      nutrition: _currentNutrition,
    ));

    // Search for the food name to get the correct fdc_id
    logger.d('Searching USDA for manual food name: "${event.name}"');
    final searchResult = await nutritionRepository.searchByName(event.name);

    Failure? searchFailure;
    List<FoodItem>? searchResultsList;

    searchResult.fold(
      (l) => searchFailure = l,
      (r) => searchResultsList = r,
    );

    if (searchFailure != null || searchResultsList == null) {
      logger.w('Failed to search for manual food: $searchFailure. Estimating offline.');
      final newItem = FoodItem(
        id: uuid.v4(),
        name: event.name,
        confidenceScore: 1.0,
        servingDescription: '${event.quantity} ${event.unit}',
        quantity: event.quantity,
        unit: event.unit,
      );
      
      final estimatedNutrition = _estimateOfflineNutrition(newItem);

      _currentItems = List<FoodItem>.of(_currentItems)..add(newItem);
      _currentNutrition = List<NutritionInfo>.of(_currentNutrition)..add(estimatedNutrition);

      _emitCurrentState(emit);
      return;
    }

    if (searchResultsList!.isEmpty) {
      logger.w('No USDA search results found for: "${event.name}". Estimating offline.');
      final newItem = FoodItem(
        id: uuid.v4(),
        name: event.name,
        confidenceScore: 1.0,
        servingDescription: '${event.quantity} ${event.unit}',
        quantity: event.quantity,
        unit: event.unit,
      );
      
      final estimatedNutrition = _estimateOfflineNutrition(newItem);

      _currentItems = List<FoodItem>.of(_currentItems)..add(newItem);
      _currentNutrition = List<NutritionInfo>.of(_currentNutrition)..add(estimatedNutrition);

      _emitCurrentState(emit);
      return;
    }

    logger.d('Found search results. First match: ${searchResultsList!.first}');

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
    logger.d('Fetching nutrition for item ID: ${newItem.id}, servingDescription: "${newItem.servingDescription}"');
    final nutritionResult = await nutritionRepository.getNutrition(newItem);

    Failure? nutritionFailure;
    NutritionInfo? nutritionInfo;

    nutritionResult.fold(
      (l) {
        nutritionFailure = l;
        logger.w('getNutrition failed: $l');
      },
      (r) {
        nutritionInfo = r;
        logger.d('getNutrition succeeded! Calories: ${r.calories}, Protein: ${r.proteinG}, Carbs: ${r.carbsG}, Fat: ${r.fatG}');
      },
    );

    if (nutritionFailure != null || nutritionInfo == null || _isZeroPlaceholder(nutritionInfo!)) {
      if (nutritionInfo != null && _isZeroPlaceholder(nutritionInfo!)) {
        logger.w('getNutrition returned all zeros (placeholder). Estimating offline.');
      } else {
        logger.e('Failed to fetch nutrition for manual item: $nutritionFailure. Estimating offline.');
      }

      final estimatedNutrition = _estimateOfflineNutrition(newItem);

      _currentItems = List<FoodItem>.of(_currentItems)..add(newItem);
      _currentNutrition = List<NutritionInfo>.of(_currentNutrition)..add(estimatedNutrition);

      _emitCurrentState(emit);
      return;
    }

    _currentItems = List<FoodItem>.of(_currentItems)..add(newItem);
    _currentNutrition = List<NutritionInfo>.of(_currentNutrition)..add(nutritionInfo!);

    _emitCurrentState(emit);
  }

  Future<void> _onEditFoodItemRequested(
    EditFoodItemRequested event,
    Emitter<FoodScanState> emit,
  ) async {
    final itemIndex = _currentItems.indexWhere((item) => item.id == event.itemId);
    if (itemIndex == -1) return;

    final oldItem = _currentItems[itemIndex];
    
    // If the name did not change, we can perform the nutrition scaling in-place
    // entirely client-side without any network calls! This prevents DNS/connection
    // timeouts from turning values to 0.
    if (oldItem.name.trim().toLowerCase() == event.name.trim().toLowerCase()) {
      logger.i('Editing food item portion for "${event.name}" without name change. Scaling locally.');
      final oldNutrition = _currentNutrition[itemIndex];

      final updatedItem = oldItem.copyWith(
        name: event.name,
        quantity: event.quantity,
        unit: event.unit,
        servingDescription: '${event.quantity} ${event.unit}',
      );

      // If the old nutrition was all zeros (because the initial scan failed to fetch
      // nutrition due to network timeout), estimate the offline nutrition now instead
      // of scaling zero.
      if (_isZeroPlaceholder(oldNutrition)) {
        logger.i('Initial scanned nutrition was zero placeholder. Estimating offline nutrition.');
        _currentItems = List<FoodItem>.of(_currentItems)..[itemIndex] = updatedItem;
        _currentNutrition = List<NutritionInfo>.of(_currentNutrition)..[itemIndex] = _estimateOfflineNutrition(updatedItem);
        _emitCurrentState(emit);
        return;
      }

      double scaleFactor = event.quantity / oldItem.quantity;
      logger.d('Scaling: oldQty=${oldItem.quantity} ${oldItem.unit}, newQty=${event.quantity} ${event.unit}, scaleFactor=$scaleFactor');

      // Handle conversion scaling if units are different
      if (oldItem.unit != event.unit) {
        double getWeightInGrams(double qty, String unit) {
          switch (unit.toLowerCase()) {
            case 'g':
              return qty;
            case 'oz':
              return qty * 28.35;
            case 'cup':
              return qty * 240;
            case 'piece':
            case 'slice':
              return qty * 50;
            case 'tbsp':
              return qty * 15;
            case 'tsp':
              return qty * 5;
            default:
              return qty * 100;
          }
        }
        final oldGrams = getWeightInGrams(oldItem.quantity, oldItem.unit);
        final newGrams = getWeightInGrams(event.quantity, event.unit);
        scaleFactor = oldGrams > 0 ? (newGrams / oldGrams) : 1.0;
        logger.d('Unit conversion scaling: oldGrams=$oldGrams, newGrams=$newGrams, scaleFactor=$scaleFactor');
      }

      final scaledNutrition = oldNutrition.scaledBy(scaleFactor);
      logger.d('Scaled calories: old=${oldNutrition.calories} -> new=${scaledNutrition.calories}');

      _currentItems = List<FoodItem>.of(_currentItems)..[itemIndex] = updatedItem;
      _currentNutrition = List<NutritionInfo>.of(_currentNutrition)..[itemIndex] = scaledNutrition;
      
      _emitCurrentState(emit);
      return;
    }

    // Remember state before loading so we can return to it after fetch
    _preLoadingStateType = state.runtimeType;
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
      
      _currentItems = List<FoodItem>.of(_currentItems)..[itemIndex] = updatedItem;
      _currentNutrition = List<NutritionInfo>.of(_currentNutrition)..[itemIndex] = oldNutrition.scaledBy(scaleFactor);
      
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
      
      _currentItems = List<FoodItem>.of(_currentItems)..[itemIndex] = updatedItem;
      _currentNutrition = List<NutritionInfo>.of(_currentNutrition)..[itemIndex] = oldNutrition.scaledBy(scaleFactor);
      
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

    if (nutritionFailure != null || nutritionInfo == null || _isZeroPlaceholder(nutritionInfo!)) {
      if (nutritionInfo != null && _isZeroPlaceholder(nutritionInfo!)) {
        logger.w('getNutrition returned all zeros (placeholder) for edit. Scaling existing nutrition.');
      } else {
        logger.e('Failed to fetch nutrition for edited item: $nutritionFailure. Scaling existing.');
      }
      
      // Scale existing nutrition by portion size change
      final oldItem = _currentItems[itemIndex];
      final oldNutrition = _currentNutrition[itemIndex];
      double scaleFactor = event.quantity / oldItem.quantity;

      if (oldItem.unit != event.unit) {
        double getWeightInGrams(double qty, String unit) {
          switch (unit.toLowerCase()) {
            case 'g':
              return qty;
            case 'oz':
              return qty * 28.35;
            case 'cup':
              return qty * 240;
            case 'piece':
            case 'slice':
              return qty * 50;
            case 'tbsp':
              return qty * 15;
            case 'tsp':
              return qty * 5;
            default:
              return qty * 100;
          }
        }
        final oldGrams = getWeightInGrams(oldItem.quantity, oldItem.unit);
        final newGrams = getWeightInGrams(event.quantity, event.unit);
        scaleFactor = oldGrams > 0 ? (newGrams / oldGrams) : 1.0;
      }
      
      _currentItems = List<FoodItem>.of(_currentItems)..[itemIndex] = updatedItem;
      _currentNutrition = List<NutritionInfo>.of(_currentNutrition)..[itemIndex] = oldNutrition.scaledBy(scaleFactor);
      
      _emitCurrentState(emit);
      return;
    }

    _currentItems = List<FoodItem>.of(_currentItems)..[itemIndex] = updatedItem;
    _currentNutrition = List<NutritionInfo>.of(_currentNutrition)..[itemIndex] = nutritionInfo!;
    
    _emitCurrentState(emit);
  }

  void _emitCurrentState(Emitter<FoodScanState> emit) {
    // Use the pre-loading state type when we are currently in LoadingNutrition,
    // because `state` was already overwritten to LoadingNutrition before the
    // async work ran. Fall back to the live state type for other cases.
    final effectiveType =
        (state is LoadingNutrition) ? _preLoadingStateType : state.runtimeType;

    // IMPORTANT: always pass NEW list copies so that Equatable does not
    // consider the new state equal to the previous one (which holds a
    // reference to the same list objects).  Without this, in-place mutations
    // like `_currentItems[i] = updatedItem` or `_currentItems.add(newItem)`
    // would make the new state look identical to the old one and the bloc
    // would silently drop the emission — leaving the UI showing stale data.
    final items = List<FoodItem>.of(_currentItems);
    final nutrition = List<NutritionInfo>.of(_currentNutrition);

    if (effectiveType == RecognitionSucceeded && _currentImage != null) {
      emit(RecognitionSucceeded(
        image: _currentImage!,
        items: items,
        nutrition: nutrition,
      ));
    } else if (effectiveType == RecognitionLowConfidence && _currentImage != null) {
      emit(RecognitionLowConfidence(
        image: _currentImage!,
        items: items,
        nutrition: nutrition,
      ));
    } else if (effectiveType == NutritionLoaded) {
      emit(NutritionLoaded(
        image: _currentImage,
        items: items,
        nutrition: nutrition,
      ));
    } else if (_currentImage != null && _currentItems.isNotEmpty) {
      // Fallback with image: default to RecognitionSucceeded
      emit(RecognitionSucceeded(
        image: _currentImage!,
        items: items,
        nutrition: nutrition,
      ));
    } else if (_currentItems.isNotEmpty) {
      // No image (manual-only entry) — emit NutritionLoaded with null image
      emit(NutritionLoaded(
        image: null,
        items: items,
        nutrition: nutrition,
      ));
    }

    // Clear the remembered pre-loading state
    _preLoadingStateType = null;
  }

  Future<void> _onConfirmAndSaveRequested(
    ConfirmAndSaveRequested event,
    Emitter<FoodScanState> emit,
  ) async {
    if (_currentItems.isEmpty) {
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
      imagePath: _currentImage?.path ?? '',
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

  Future<void> _onUpdateMealImageRequested(
    UpdateMealImageRequested event,
    Emitter<FoodScanState> emit,
  ) async {
    _currentImage = event.image;
    _emitCurrentState(emit);
  }

  void _reset() {
    _currentImage = null;
    _currentItems = [];
    _currentNutrition = [];
  }

  // --- Offline Fallback Heuristics and Estimation ---

  static final Map<String, Map<String, double>> _offlineNutritionData = {
    'apple': {'calories': 52, 'protein': 0.3, 'carbs': 13.8, 'fat': 0.2, 'fiber': 2.4, 'sugar': 10.4, 'sodium': 1},
    'banana': {'calories': 89, 'protein': 1.1, 'carbs': 22.8, 'fat': 0.3, 'fiber': 2.6, 'sugar': 12.2, 'sodium': 1},
    'chicken': {'calories': 165, 'protein': 31.0, 'carbs': 0.0, 'fat': 3.6, 'fiber': 0.0, 'sugar': 0.0, 'sodium': 74},
    'egg': {'calories': 155, 'protein': 13.0, 'carbs': 1.1, 'fat': 11.0, 'fiber': 0.0, 'sugar': 1.1, 'sodium': 124},
    'rice': {'calories': 130, 'protein': 2.7, 'carbs': 28.0, 'fat': 0.3, 'fiber': 0.4, 'sugar': 0.1, 'sodium': 1},
    'milk': {'calories': 42, 'protein': 3.4, 'carbs': 5.0, 'fat': 1.0, 'fiber': 0.0, 'sugar': 5.0, 'sodium': 44},
    'bread': {'calories': 265, 'protein': 9.0, 'carbs': 49.0, 'fat': 3.2, 'fiber': 2.7, 'sugar': 5.0, 'sodium': 491},
    'potato': {'calories': 77, 'protein': 2.0, 'carbs': 17.0, 'fat': 0.1, 'fiber': 2.2, 'sugar': 0.8, 'sodium': 6},
    'salmon': {'calories': 208, 'protein': 20.0, 'carbs': 0.0, 'fat': 13.0, 'fiber': 0.0, 'sugar': 0.0, 'sodium': 59},
    'avocado': {'calories': 160, 'protein': 2.0, 'carbs': 8.5, 'fat': 15.0, 'fiber': 6.7, 'sugar': 0.7, 'sodium': 7},
    'oats': {'calories': 389, 'protein': 16.9, 'carbs': 66.3, 'fat': 6.9, 'fiber': 10.6, 'sugar': 0.0, 'sodium': 2},
    'samosa': {'calories': 260, 'protein': 4.5, 'carbs': 24.0, 'fat': 17.0, 'fiber': 1.5, 'sugar': 1.0, 'sodium': 380},
    'french fries': {'calories': 312, 'protein': 3.4, 'carbs': 41.0, 'fat': 15.0, 'fiber': 3.8, 'sugar': 0.3, 'sodium': 210},
    'fries': {'calories': 312, 'protein': 3.4, 'carbs': 41.0, 'fat': 15.0, 'fiber': 3.8, 'sugar': 0.3, 'sodium': 210},
    'gulab jamun': {'calories': 320, 'protein': 4.0, 'carbs': 52.0, 'fat': 11.0, 'fiber': 0.8, 'sugar': 44.0, 'sodium': 110},
    'ice cream': {'calories': 207, 'protein': 3.5, 'carbs': 24.0, 'fat': 11.0, 'fiber': 0.7, 'sugar': 21.0, 'sodium': 80},
    'pizza': {'calories': 266, 'protein': 11.4, 'carbs': 33.0, 'fat': 10.0, 'fiber': 2.3, 'sugar': 3.6, 'sodium': 598},
    'burger': {'calories': 295, 'protein': 17.0, 'carbs': 24.0, 'fat': 14.0, 'fiber': 1.5, 'sugar': 4.0, 'sodium': 500},
    'cake': {'calories': 350, 'protein': 3.0, 'carbs': 55.0, 'fat': 14.0, 'fiber': 1.0, 'sugar': 38.0, 'sodium': 320},
    'sweet': {'calories': 380, 'protein': 4.0, 'carbs': 60.0, 'fat': 14.0, 'fiber': 1.0, 'sugar': 50.0, 'sodium': 150},
  };

  NutritionInfo _estimateOfflineNutrition(FoodItem item) {
    final nameLower = item.name.toLowerCase();
    
    // Default fallback values (per 100g)
    double cal = 120;
    double protein = 3;
    double carbs = 15;
    double fat = 4;
    double fiber = 1;
    double sugar = 2;
    double sodium = 60;

    for (final key in _offlineNutritionData.keys) {
      if (nameLower.contains(key)) {
        final data = _offlineNutritionData[key]!;
        cal = data['calories']!;
        protein = data['protein']!;
        carbs = data['carbs']!;
        fat = data['fat']!;
        fiber = data['fiber']!;
        sugar = data['sugar']!;
        sodium = data['sodium']!;
        break;
      }
    }

    // Dynamic heuristic adjustments based on description/name
    if (nameLower.contains('fried') || nameLower.contains('deep-fried') || nameLower.contains('crispy')) {
      // Deep fried food has much higher fat and calories
      fat = (fat * 3.5).clamp(12.0, 30.0);
      cal = (cal + fat * 9).clamp(250.0, 600.0);
    }
    if (nameLower.contains('sweet') || nameLower.contains('chocolate') || nameLower.contains('candy') || nameLower.contains('dessert') || nameLower.contains('syrup')) {
      // Sweets have much higher sugar and carbs
      sugar = (sugar * 8.0).clamp(20.0, 60.0);
      carbs = (carbs + sugar).clamp(35.0, 80.0);
      cal = (cal + sugar * 4).clamp(250.0, 600.0);
    }

    // Estimate saturated fat (usually ~25% of total fat, but ~50% for fried/dairy foods)
    double satFat = fat * 0.25;
    if (nameLower.contains('fried') || 
        nameLower.contains('samosa') || 
        nameLower.contains('fries') || 
        nameLower.contains('burger') || 
        nameLower.contains('pizza') || 
        nameLower.contains('butter') || 
        nameLower.contains('cheese') || 
        nameLower.contains('milk') || 
        nameLower.contains('cream')) {
      satFat = fat * 0.50;
    }

    // Estimate trans fat (negligible unless fried or pastry/donuts)
    double transFat = 0.0;
    if (nameLower.contains('fried') || 
        nameLower.contains('samosa') || 
        nameLower.contains('fries') || 
        nameLower.contains('donut') || 
        nameLower.contains('pastry') || 
        nameLower.contains('cookie') || 
        nameLower.contains('cake')) {
      transFat = 0.5; // ~0.5g per 100g
    }

    // Estimate cholesterol
    double cholesterol = 0.0;
    if (nameLower.contains('egg')) {
      cholesterol = 373.0; // mg per 100g
    } else if (nameLower.contains('chicken') || nameLower.contains('salmon') || nameLower.contains('meat')) {
      cholesterol = 80.0;
    } else if (nameLower.contains('milk') || nameLower.contains('cheese') || nameLower.contains('cream') || nameLower.contains('ice cream') || nameLower.contains('butter')) {
      cholesterol = 30.0;
    }

    double scaleFactor = 1.0;
    switch (item.unit.toLowerCase()) {
      case 'g':
        scaleFactor = item.quantity / 100;
        break;
      case 'oz':
        scaleFactor = (item.quantity * 28.35) / 100;
        break;
      case 'cup':
        scaleFactor = (item.quantity * 240) / 100;
        break;
      case 'piece':
      case 'slice':
        scaleFactor = (item.quantity * 80) / 100;
        break;
      default:
        scaleFactor = (item.quantity * 150) / 100;
        break;
    }

    return NutritionInfo(
      calories: cal * scaleFactor,
      proteinG: protein * scaleFactor,
      carbsG: carbs * scaleFactor,
      fatG: fat * scaleFactor,
      fiberG: fiber * scaleFactor,
      sugarG: sugar * scaleFactor,
      sodiumMg: sodium * scaleFactor,
      saturatedFatG: satFat * scaleFactor,
      transFatG: transFat * scaleFactor,
      cholesterolMg: cholesterol * scaleFactor,
      per: item,
    );
  }

  bool _isZeroPlaceholder(NutritionInfo info) {
    if (info.calories == 0 && info.proteinG == 0 && info.carbsG == 0 && info.fatG == 0) {
      final name = info.per.name.toLowerCase();
      if (name.contains('water') || name.contains('tea') || name.contains('diet') || name.contains('zero')) {
        return false;
      }
      return true;
    }
    return false;
  }
}
