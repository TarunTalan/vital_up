import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/features/food_scanner/domain/entities/nutrition_info.dart';
import 'package:vital_up/features/food_scanner/domain/entities/recognized_food.dart';
import 'package:vital_up/features/food_scanner/domain/repositories/food_recognition_repository.dart';
import 'package:vital_up/features/food_scanner/domain/repositories/nutrition_repository.dart';

class ScanFoodImage {
  final FoodRecognitionRepository foodRecognitionRepository;
  final NutritionRepository nutritionRepository;

  ScanFoodImage({
    required this.foodRecognitionRepository,
    required this.nutritionRepository,
  });

  /// Returns one [NutritionInfo] per recognized food, in recognition order.
  ///
  /// Nutrition normally arrives inline with recognition; items without it are
  /// looked up concurrently. An item whose lookup fails is still returned with
  /// zeroed nutrition so the caller can estimate it rather than silently
  /// dropping a food the user can see on their plate.
  Future<Either<Failure, List<NutritionInfo>>> call(File image) async {
    final recognitionResult = await foodRecognitionRepository.recognizeFood(image);

    return recognitionResult.fold(
      (failure) async => Left(failure),
      (foods) async {
        if (foods.isEmpty) return const Left(NoFoodDetectedFailure());
        return Right(await Future.wait(foods.map(_resolveNutrition)));
      },
    );
  }

  Future<NutritionInfo> _resolveNutrition(RecognizedFood food) async {
    final inline = food.nutrition;
    if (inline != null) return inline;

    final result = await nutritionRepository.getNutrition(
      food.item.copyWith(id: food.lookupKey),
    );
    return result.fold(
      (_) => NutritionInfo(
        calories: 0,
        proteinG: 0,
        carbsG: 0,
        fatG: 0,
        fiberG: 0,
        sugarG: 0,
        sodiumMg: 0,
        per: food.item,
      ),
      // Keep the recognized item's own id so per-item edits still find it.
      (nutrition) => nutrition.copyWith(per: food.item),
    );
  }
}
