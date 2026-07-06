import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/core/network/dio_client.dart';
import 'package:vital_up/features/food_scan/data/models/food_item_dto.dart';
import 'package:vital_up/features/food_scan/domain/entities/food_item.dart';
import 'package:vital_up/features/food_scan/domain/repositories/food_recognition_repository.dart';
import 'dart:io';

class FoodRecognitionRepositoryImpl implements FoodRecognitionRepository {
  final DioClient dioClient;
  final Logger logger;

  FoodRecognitionRepositoryImpl({
    required this.dioClient,
    required this.logger,
  });

  final String _baseUrl = 'https://your-backend-proxy.com/api'; // Replace with actual backend proxy URL
  final Map<String, FoodItem> _cache = {};

  @override
  Future<Either<Failure, List<FoodItem>>> recognizeFood(File image) async {
    try {
      final cacheKey = image.path;
      if (_cache.containsKey(cacheKey)) {
        logger.d('Returning cached food recognition result');
        return Right([_cache[cacheKey]!]);
      }

      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(image.path),
      });

      final response = await dioClient.dio.post(
        '$_baseUrl/food/recognize',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final itemsData = data['items'] as List<dynamic>?;
        
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
      } else {
        return const Left(ServerFailure('Failed to recognize food. Please try again.'));
      }
    } on DioException catch (e) {
      logger.e('Dio error in recognizeFood: ${e.message}');
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return const Left(NetworkFailure('Request timed out. Please check your connection.'));
      } else if (e.type == DioExceptionType.connectionError) {
        return const Left(NetworkFailure('No internet connection. Please check your network settings.'));
      }
      return Left(ServerFailure('Network error: ${e.message}'));
    } catch (e) {
      logger.e('Unexpected error in recognizeFood: $e');
      return const Left(ServerFailure('An unexpected error occurred.'));
    }
  }

  @override
  Future<Either<Failure, List<FoodItem>>> searchByName(String query) async {
    try {
      final response = await dioClient.dio.get(
        '$_baseUrl/food/search',
        queryParameters: {'query': query},
        options: Options(
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      if (response.statusCode == 200) {
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
    } on DioException catch (e) {
      logger.e('Dio error in searchByName: ${e.message}');
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return const Left(NetworkFailure('Request timed out. Please check your connection.'));
      } else if (e.type == DioExceptionType.connectionError) {
        return const Left(NetworkFailure('No internet connection. Please check your network settings.'));
      }
      return Left(ServerFailure('Network error: ${e.message}'));
    } catch (e) {
      logger.e('Unexpected error in searchByName: $e');
      return const Left(ServerFailure('An unexpected error occurred.'));
    }
  }

  void clearCache() {
    _cache.clear();
  }
}
