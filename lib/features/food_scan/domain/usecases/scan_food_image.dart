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
    print('ScanFoodImage use case called');
    // Check quota before making API calls
    print('Checking quota...');
    final quotaResult = await subscriptionRepository.remainingFreeScans();
    print('Quota result: $quotaResult');
    
    if (quotaResult.isLeft()) {
      print('Quota check failed');
      return Left(quotaResult.swap().getOrElse(() => const ServerFailure('Failed to check quota')));
    }

    final remainingScans = quotaResult.getOrElse(() => 0);
    print('Remaining scans: $remainingScans');
    
    if (remainingScans == 0) {
      print('Scan quota exceeded');
      return const Left(ScanQuotaExceededFailure());
    }

    print('Calling foodRecognitionRepository.recognizeFood');
    final recognitionResult = await foodRecognitionRepository.recognizeFood(
      image,
    );
    print('Recognition result: $recognitionResult');

    if (recognitionResult.isLeft()) {
      print('Recognition failed');
      return Left(
        recognitionResult.swap().getOrElse(
          () => const ServerFailure('Unknown error'),
        ),
      );
    }

    final foodItems = recognitionResult.getOrElse(() => []);
    print('Food items count: ${foodItems.length}');
    
    if (foodItems.isEmpty) {
      print('No food items detected');
      return const Left(NoFoodDetectedFailure());
    }

    print('Fetching nutrition for ${foodItems.length} items');
    final nutritionResults = <NutritionInfo>[];
    for (final item in foodItems) {
      print('Fetching nutrition for: ${item.name}');
      final nutritionResult = await nutritionRepository.getNutrition(item);
      nutritionResult.fold(
        (failure) {
          print('Failed to get nutrition for ${item.name}: $failure');
        },
        (nutrition) {
          print('Got nutrition for ${item.name}');
          nutritionResults.add(nutrition);
        },
      );
    }

    print('Nutrition results count: ${nutritionResults.length}');
    
    if (nutritionResults.isEmpty) {
      print('No nutrition results');
      return const Left(
        ServerFailure('Failed to retrieve nutrition information.'),
      );
    }

    print('Returning ${nutritionResults.length} nutrition results');
    return Right(nutritionResults);
  }
}
