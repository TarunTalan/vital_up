import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/features/food_scanner/domain/entities/nutrition_info.dart';
import 'package:vital_up/features/food_scanner/domain/entities/food_item.dart';
import 'package:vital_up/features/food_scanner/domain/repositories/nutrition_repository.dart';

class NutritionRepositoryImpl implements NutritionRepository {
  final Dio dio;
  final Logger logger;
  final SupabaseClient supabaseClient;

  NutritionRepositoryImpl({
    required this.dio,
    required this.logger,
    required this.supabaseClient,
  });

  final String _usdaBaseUrl = 'https://api.nal.usda.gov/fdc/v1';
  final String _openFoodFactsBaseUrl = 'https://world.openfoodfacts.org/api/v0';

  /// Supabase Edge Functions only auto-decode the response body into a
  /// [Map] when the function sets `Content-Type: application/json`.
  /// If that header is missing, `response.data` comes back as a raw
  /// JSON string instead, which crashes a plain `as Map<String, dynamic>`
  /// cast. This normalizes either case.
  Map<String, dynamic> _decodeMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String) return jsonDecode(raw) as Map<String, dynamic>;
    throw FormatException('Unexpected response type: ${raw.runtimeType}');
  }

  @override
  Future<Either<Failure, NutritionInfo>> getNutrition(FoodItem item) async {
    try {
      // Get USDA API key from Supabase Edge Function or environment
      final response = await supabaseClient.functions.invoke(
        'scan-food',
        body: {
          'get_nutrition': true,
          'fdc_id': item.id,
        },
      );

      if (response.status == 200) {
        final data = _decodeMap(response.data);
        // The nutrition edge function only returns calorie/macro numbers —
        // it has no knowledge of the FoodItem this lookup was for, so it
        // never sends back a `per` field. Attach the actual item we were
        // called with directly rather than relying on NutritionInfoDto's
        // `per` JSON parsing (which would otherwise fall back to an
        // empty/blank FoodItem).
        
        // Parse additional nutrients
        final additionalNutrientsList = (data['additional_nutrients'] as List<dynamic>?)
            ?.map((e) => AdditionalNutrient(
              id: (e['id'] as dynamic)?.toString(),
              name: e['name'] as String? ?? '',
              unit: e['unit'] as String? ?? '',
              value: (e['value'] as num?)?.toDouble() ?? 0.0,
            ))
            .toList() ?? [];
        
        final nutritionInfo = NutritionInfo(
          calories: (data['calories'] as num?)?.toDouble() ?? 0.0,
          proteinG: (data['protein_g'] as num?)?.toDouble() ?? 0.0,
          carbsG: (data['carbs_g'] as num?)?.toDouble() ?? 0.0,
          fatG: (data['fat_g'] as num?)?.toDouble() ?? 0.0,
          fiberG: (data['fiber_g'] as num?)?.toDouble() ?? 0.0,
          sugarG: (data['sugar_g'] as num?)?.toDouble() ?? 0.0,
          sodiumMg: (data['sodium_mg'] as num?)?.toDouble() ?? 0.0,
          calciumMg: (data['calcium_mg'] as num?)?.toDouble() ?? 0.0,
          ironMg: (data['iron_mg'] as num?)?.toDouble() ?? 0.0,
          vitaminAIu: (data['vitamin_a_iu'] as num?)?.toDouble() ?? 0.0,
          vitaminCMg: (data['vitamin_c_mg'] as num?)?.toDouble() ?? 0.0,
          vitaminDIu: (data['vitamin_d_iu'] as num?)?.toDouble() ?? 0.0,
          vitaminEMg: (data['vitamin_e_mg'] as num?)?.toDouble() ?? 0.0,
          vitaminKMg: (data['vitamin_k_mg'] as num?)?.toDouble() ?? 0.0,
          thiaminMg: (data['thiamin_mg'] as num?)?.toDouble() ?? 0.0,
          riboflavinMg: (data['riboflavin_mg'] as num?)?.toDouble() ?? 0.0,
          niacinMg: (data['niacin_mg'] as num?)?.toDouble() ?? 0.0,
          vitaminB6Mg: (data['vitamin_b6_mg'] as num?)?.toDouble() ?? 0.0,
          vitaminB12Mcg: (data['vitamin_b12_mcg'] as num?)?.toDouble() ?? 0.0,
          folateMcg: (data['folate_mcg'] as num?)?.toDouble() ?? 0.0,
          potassiumMg: (data['potassium_mg'] as num?)?.toDouble() ?? 0.0,
          phosphorusMg: (data['phosphorus_mg'] as num?)?.toDouble() ?? 0.0,
          magnesiumMg: (data['magnesium_mg'] as num?)?.toDouble() ?? 0.0,
          zincMg: (data['zinc_mg'] as num?)?.toDouble() ?? 0.0,
          copperMg: (data['copper_mg'] as num?)?.toDouble() ?? 0.0,
          manganeseMg: (data['manganese_mg'] as num?)?.toDouble() ?? 0.0,
          seleniumMcg: (data['selenium_mcg'] as num?)?.toDouble() ?? 0.0,
          cholesterolMg: (data['cholesterol_mg'] as num?)?.toDouble() ?? 0.0,
          saturatedFatG: (data['saturated_fat_g'] as num?)?.toDouble() ?? 0.0,
          transFatG: (data['trans_fat_g'] as num?)?.toDouble() ?? 0.0,
          monounsaturatedFatG: (data['monounsaturated_fat_g'] as num?)?.toDouble() ?? 0.0,
          polyunsaturatedFatG: (data['polyunsaturated_fat_g'] as num?)?.toDouble() ?? 0.0,
          additionalNutrients: additionalNutrientsList,
          per: item,
        );
        return Right(nutritionInfo);
      } else {
        return const Left(ServerFailure('Failed to retrieve nutrition information.'));
      }
    } catch (e) {
      logger.e('Unexpected error in getNutrition: $e');
      return const Left(ServerFailure('An unexpected error occurred.'));
    }
  }

  @override
  Future<Either<Failure, FoodItem>> lookupBarcode(String barcode) async {
    try {
      final response = await dio.get(
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
        final data = _decodeMap(response.data);
        final itemsData = data['items'] as List<dynamic>?;

        if (itemsData == null || itemsData.isEmpty) {
          return const Left(ServerFailure('No results found.'));
        }

        final foodItems = itemsData
            .map((item) {
          final dto = item as Map<String, dynamic>;
          return FoodItem(
            id: dto['fdc_id']?.toString() ?? dto['id']?.toString() ?? '',
            name: dto['name'] as String? ?? '',
            confidenceScore: 1.0,
            servingDescription: dto['serving_description'] as String? ?? '100g',
            quantity: 1.0,
            unit: 'serving',
          );
        })
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
}