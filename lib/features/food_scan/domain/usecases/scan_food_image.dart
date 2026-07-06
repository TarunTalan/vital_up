import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/features/food_scan/domain/entities/nutrition_info.dart';
import 'package:vital_up/features/food_scan/domain/repositories/food_recognition_repository.dart';
import 'package:vital_up/features/food_scan/domain/repositories/nutrition_repository.dart';
import 'package:vital_up/features/food_scan/domain/repositories/subscription_repository.dart';

class ScanFoodImage {
  final FoodRecognitionRepository foodRecognitionRepository;
  final NutritionRepository nutritionRepository;
  final SubscriptionRepository subscriptionRepository;

  ScanFoodImage({
    required this.foodRecognitionRepository,
    required this.nutritionRepository,
    required this.subscriptionRepository,
  });

  Future<Either<Failure, List<NutritionInfo>>> call(File image) async {
    // Check quota before making API calls
    final quotaResult = await subscriptionRepository.remainingFreeScans();
    if (quotaResult.isLeft()) {
      return Left(quotaResult.swap().getOrElse(() => const ServerFailure('Failed to check quota')));
    }

    final remainingScans = quotaResult.getOrElse(() => 0);
    if (remainingScans == 0) {
      return const Left(ScanQuotaExceededFailure());
    }

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
        (failure) => null,
        (nutrition) => nutritionResults.add(nutrition),
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
