import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/features/food_scanner/domain/entities/nutrition_info.dart';
import 'package:vital_up/features/food_scanner/domain/repositories/food_recognition_repository.dart';
import 'package:vital_up/features/food_scanner/domain/repositories/nutrition_repository.dart';

class ScanFoodImage {
  final FoodRecognitionRepository foodRecognitionRepository;
  final NutritionRepository nutritionRepository;

  ScanFoodImage({
    required this.foodRecognitionRepository,
    required this.nutritionRepository,
  });

  Future<Either<Failure, List<NutritionInfo>>> call(File image) async {
    final recognitionResult = await foodRecognitionRepository.recognizeFood(
      image,
    );

    if (recognitionResult.isLeft()) {
      return Left(
        recognitionResult.swap().getOrElse(
          () => const ServerFailure('Unknown error'),
        ),
      );
    }

    final foodItems = recognitionResult.getOrElse(() => []);
    
    if (foodItems.isEmpty) {
      return const Left(NoFoodDetectedFailure());
    }

    final nutritionResults = <NutritionInfo>[];
    for (final item in foodItems) {
      final nutritionResult = await nutritionRepository.getNutrition(item);
      nutritionResult.fold(
        (failure) {},
        (nutrition) {
          nutritionResults.add(nutrition);
        },
      );
    }
    
    if (nutritionResults.isEmpty) {
      return const Left(
        ServerFailure('Failed to retrieve nutrition information.'),
      );
    }

    return Right(nutritionResults);
  }
}
