import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/core/network/dio_client.dart';
import 'package:vital_up/features/food_scan/data/models/nutrition_info_dto.dart';
import 'package:vital_up/features/food_scan/domain/entities/nutrition_info.dart';
import 'package:vital_up/features/food_scan/domain/entities/food_item.dart';
import 'package:vital_up/features/food_scan/domain/repositories/nutrition_repository.dart';

class NutritionRepositoryImpl implements NutritionRepository {
  final DioClient dioClient;
  final Logger logger;

  NutritionRepositoryImpl({
    required this.dioClient,
    required this.logger,
  });

  final String _fatSecretBaseUrl = 'https://your-backend-proxy.com/api'; // Replace with actual backend proxy URL
  final String _openFoodFactsBaseUrl = 'https://world.openfoodfacts.org/api/v0';

  @override
  Future<Either<Failure, NutritionInfo>> getNutrition(FoodItem item) async {
    try {
      final response = await dioClient.dio.get(
        '$_fatSecretBaseUrl/food/nutrition',
        queryParameters: {
          'food_id': item.id,
          'serving_description': item.servingDescription,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final nutritionDto = NutritionInfoDto.fromJson(data);
        return Right(nutritionDto.toDomain());
      } else {
        return const Left(ServerFailure('Failed to retrieve nutrition information.'));
      }
    } on DioException catch (e) {
      logger.e('Dio error in getNutrition: ${e.message}');
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return const Left(NetworkFailure('Request timed out. Please check your connection.'));
      } else if (e.type == DioExceptionType.connectionError) {
        return const Left(NetworkFailure('No internet connection. Please check your network settings.'));
      }
      return Left(ServerFailure('Network error: ${e.message}'));
    } catch (e) {
      logger.e('Unexpected error in getNutrition: $e');
      return const Left(ServerFailure('An unexpected error occurred.'));
    }
  }

  @override
  Future<Either<Failure, FoodItem>> lookupBarcode(String barcode) async {
    try {
      final response = await dioClient.dio.get(
        '$_openFoodFactsBaseUrl/product/$barcode.json',
        options: Options(
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final product = data['product'] as Map<String, dynamic>?;
        
        if (product == null) {
          return const Left(BarcodeNotFoundFailure());
        }

        final productName = product['product_name'] as String? ?? product['product_name_en'] as String? ?? 'Unknown Product';
        final servingSize = product['serving_size'] as String? ?? '100g';
        
        final foodItem = FoodItem(
          id: barcode,
          name: productName,
          confidenceScore: 1.0,
          servingDescription: servingSize,
          quantity: 1.0,
          unit: 'serving',
        );

        return Right(foodItem);
      } else if (response.statusCode == 404) {
        return const Left(BarcodeNotFoundFailure());
      } else {
        return const Left(ServerFailure('Failed to lookup barcode. Please try again.'));
      }
    } on DioException catch (e) {
      logger.e('Dio error in lookupBarcode: ${e.message}');
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return const Left(NetworkFailure('Request timed out. Please check your connection.'));
      } else if (e.type == DioExceptionType.connectionError) {
        return const Left(NetworkFailure('No internet connection. Please check your network settings.'));
      }
      return Left(ServerFailure('Network error: ${e.message}'));
    } catch (e) {
      logger.e('Unexpected error in lookupBarcode: $e');
      return const Left(ServerFailure('An unexpected error occurred.'));
    }
  }
}
