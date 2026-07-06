import 'dart:convert';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/features/food_scan/data/models/food_item_dto.dart';
import 'package:vital_up/features/food_scan/domain/entities/food_item.dart';
import 'package:vital_up/features/food_scan/domain/repositories/food_recognition_repository.dart';

class FoodRecognitionRepositoryImpl implements FoodRecognitionRepository {
  final Logger logger;
  final SupabaseClient supabaseClient;

  FoodRecognitionRepositoryImpl({
    required this.logger,
    required this.supabaseClient,
  });

  final Map<String, FoodItem> _cache = {};

  @override
  Future<Either<Failure, List<FoodItem>>> recognizeFood(File image) async {
    try {
      final cacheKey = image.path;
      if (_cache.containsKey(cacheKey)) {
        logger.d('Returning cached food recognition result');
        return Right([_cache[cacheKey]!]);
      }

      final imageBytes = await image.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      final response = await supabaseClient.functions.invoke(
        'scan-food',
        body: {
          'image': base64Image,
        },
      );

      logger.d('Supabase response status: ${response.status}');
      logger.d('Supabase response data: ${response.data}');

      if (response.status == 200) {
        final data = response.data as Map<String, dynamic>;
        final itemsData = data['items'] as List<dynamic>?;
        logger.d('Items data: $itemsData');
        
        if (itemsData == null || itemsData.isEmpty) {
          return const Left(NoFoodDetectedFailure());
        }

        final foodItems = itemsData
            .map((item) => FoodItemDto.fromJson(item as Map<String, dynamic>).toDomain())
            .toList();

        for (final item in foodItems) {
          _cache[cacheKey] = item;
        }

        return Right(foodItems);
      } else if (response.status == 402 || response.status == 403) {
        return const Left(ScanQuotaExceededFailure());
      } else if (response.status == 503) {
        return const Left(RecognitionUnavailableFailure());
      } else {
        return const Left(ServerFailure('Failed to recognize food. Please try again.'));
      }
    } catch (e) {
      logger.e('Unexpected error in recognizeFood: $e');
      return const Left(ServerFailure('An unexpected error occurred.'));
    }
  }

  @override
  Future<Either<Failure, List<FoodItem>>> searchByName(String query) async {
    try {
      final response = await supabaseClient.functions.invoke(
        'scan-food',
        body: {
          'search_query': query,
        },
      );

      if (response.status == 200) {
        final data = response.data as Map<String, dynamic>;
        final itemsData = data['items'] as List<dynamic>?;
        
        if (itemsData == null || itemsData.isEmpty) {
          return const Left(ServerFailure('No results found.'));
        }

        final foodItems = itemsData
            .map((item) => FoodItemDto.fromJson(item as Map<String, dynamic>).toDomain())
            .toList();

        return Right(foodItems);
      } else {
        return const Left(ServerFailure('Failed to search food. Please try again.'));
      }
    } catch (e) {
      logger.e('Unexpected error in searchByName: $e');
      return const Left(ServerFailure('An unexpected error occurred.'));
    }
  }

  void clearCache() {
    _cache.clear();
  }
}
