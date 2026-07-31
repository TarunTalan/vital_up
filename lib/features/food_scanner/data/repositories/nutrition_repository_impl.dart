import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/features/food_scanner/domain/entities/nutrition_info.dart';
import 'package:vital_up/features/food_scanner/domain/entities/food_item.dart';
import 'package:vital_up/features/food_scanner/domain/repositories/nutrition_repository.dart';
import 'package:vital_up/core/database/isar_service.dart';
import 'package:vital_up/core/database/collections/barcode_cache.dart';
import 'package:vital_up/core/database/collections/offline_food.dart';
import 'package:isar_community/isar.dart';

class NutritionRepositoryImpl implements NutritionRepository {
  final Dio dio;
  final Logger logger;
  final SupabaseClient supabaseClient;
  final IsarService isarService;

  NutritionRepositoryImpl({
    required this.dio,
    required this.logger,
    required this.supabaseClient,
    required this.isarService,
  });


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
          'serving_description': item.servingDescription,
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
  Future<Either<Failure, NutritionInfo>> lookupBarcode(String barcode) async {
    try {
      String cleanBarcode = barcode.trim();
      if (cleanBarcode.startsWith('http://') || cleanBarcode.startsWith('https://')) {
        try {
          final uri = Uri.parse(cleanBarcode);
          final segments = uri.pathSegments;
          if (segments.isNotEmpty) {
            bool foundDigits = false;
            for (final segment in segments.reversed) {
              final cleaned = segment.replaceAll(RegExp(r'\D'), '');
              if (cleaned.length >= 8) {
                cleanBarcode = cleaned;
                foundDigits = true;
                break;
              }
            }
            if (!foundDigits) {
              cleanBarcode = segments.last;
            }
          }
        } catch (_) {}
      }

      // 1. Try local Isar cache first (Zero network cost)
      try {
        final cached = await isarService.isar.barcodeCaches
            .where()
            .barcodeEqualTo(cleanBarcode)
            .findFirst();
        if (cached != null) {
          logger.i('Local cache hit for barcode: "$cleanBarcode" -> "${cached.productName}"');
          final foodItem = FoodItem(
            id: barcode,
            name: cached.productName,
            confidenceScore: 1.0,
            servingDescription: cached.servingSize,
            quantity: 1.0,
            unit: 'serving',
          );
          final nutritionInfo = NutritionInfo(
            calories: cached.calories,
            proteinG: cached.proteinG,
            carbsG: cached.carbsG,
            fatG: cached.fatG,
            fiberG: cached.fiberG,
            sugarG: cached.sugarG,
            sodiumMg: cached.sodiumMg,
            per: foodItem,
          );
          return Right(nutritionInfo);
        }
      } catch (cacheErr) {
        logger.e('Failed to lookup barcode in local Isar cache: $cacheErr');
      }

      // 2. Query Open Food Facts directly from client (Indian mirror preferred)
      bool offSuccess = false;
      NutritionInfo? offNutrition;

      try {
        logger.i('Secondary lookup: Querying Open Food Facts for barcode: "$cleanBarcode"');
        final response = await dio.get(
          'https://in.openfoodfacts.org/api/v0/product/$cleanBarcode.json',
          options: Options(
            sendTimeout: const Duration(seconds: 6),
            receiveTimeout: const Duration(seconds: 6),
          ),
        );

        if (response.statusCode == 200) {
          final data = response.data as Map<String, dynamic>;
          final product = data['product'] as Map<String, dynamic>?;
          final status = data['status'];
          final isFound = status == 1 || status == '1';

          if (isFound && product != null && product.isNotEmpty) {
            final productName = product['product_name'] as String? ?? product['product_name_en'] as String? ?? 'Unknown Product';
            final servingSize = product['serving_size'] as String? ?? '100g';

            final countriesTags = product['countries_tags'] as List<dynamic>?;
            final isIndian = countriesTags?.any((t) => t.toString().toLowerCase().contains('india')) ?? false;
            logger.d('Open Food Facts hit countries: $countriesTags (isIndian: $isIndian)');

            final foodItem = FoodItem(
              id: barcode,
              name: productName,
              confidenceScore: 1.0,
              servingDescription: servingSize,
              quantity: 1.0,
              unit: 'serving',
            );

            final nutriments = product['nutriments'] as Map<String, dynamic>? ?? {};

            double parseDouble(dynamic value) {
              if (value == null) return 0.0;
              if (value is num) return value.toDouble();
              if (value is String) return double.tryParse(value) ?? 0.0;
              return 0.0;
            }

            double getNutrientValue(String baseKey) {
              final servingVal = parseDouble(nutriments['${baseKey}_serving']);
              if (servingVal != 0.0) return servingVal;
              final hundredGVal = parseDouble(nutriments['${baseKey}_100g']);
              if (hundredGVal != 0.0) return hundredGVal;
              return parseDouble(nutriments[baseKey]);
            }

            double getNutrientInGrams(String baseKey) {
              final val = getNutrientValue(baseKey);
              final unit = (nutriments['${baseKey}_unit'] as String? ?? 'g').toLowerCase();
              if (unit == 'mg') return val / 1000.0;
              if (unit == 'mcg' || unit == 'µg') return val / 1000000.0;
              return val;
            }

            double getNutrientInMilligrams(String baseKey) {
              final val = getNutrientValue(baseKey);
              final unit = (nutriments['${baseKey}_unit'] as String? ?? 'g').toLowerCase();
              if (unit == 'g') return val * 1000.0;
              if (unit == 'mcg' || unit == 'µg') return val / 1000.0;
              return val;
            }

            double calories = getNutrientValue('energy-kcal');
            if (calories == 0.0) {
              final energyKj = getNutrientValue('energy');
              final energyUnit = (nutriments['energy_unit'] as String? ?? '').toLowerCase();
              if (energyUnit == 'kcal') {
                calories = energyKj;
              } else {
                calories = energyKj / 4.184;
              }
            }

            double sodiumMg = getNutrientInMilligrams('sodium');
            if (sodiumMg == 0.0) {
              sodiumMg = getNutrientInMilligrams('salt') / 2.5;
            }

            final proteinG = getNutrientInGrams('proteins');
            final carbsG = getNutrientInGrams('carbohydrates');
            final fatG = getNutrientInGrams('fat');

            offNutrition = NutritionInfo(
              calories: calories,
              proteinG: proteinG,
              carbsG: carbsG,
              fatG: fatG,
              fiberG: getNutrientInGrams('fiber'),
              sugarG: getNutrientInGrams('sugars'),
              sodiumMg: sodiumMg,
              saturatedFatG: getNutrientInGrams('saturated-fat'),
              transFatG: getNutrientInGrams('trans-fat'),
              cholesterolMg: getNutrientInMilligrams('cholesterol'),
              calciumMg: getNutrientInMilligrams('calcium'),
              ironMg: getNutrientInMilligrams('iron'),
              potassiumMg: getNutrientInMilligrams('potassium'),
              per: foodItem,
            );

            if (productName != 'Unknown Product' && (calories > 0 || proteinG > 0 || carbsG > 0 || fatG > 0)) {
              offSuccess = true;
            }
          }
        }
      } catch (e) {
        logger.w('Open Food Facts lookup failed or timed out: $e');
      }

      if (offSuccess && offNutrition != null) {
        logger.i('Secondary Open Food Facts lookup succeeded for barcode "$cleanBarcode"');
        // Save to local cache
        await _cacheLocally(cleanBarcode, offNutrition.per.name, offNutrition.per.servingDescription, offNutrition);
        return Right(offNutrition);
      }

      // 3. Fallback: Query the Supabase Edge Function (checks proprietary DB first, then OFF global, then Gemini search grounding)
      logger.i('Tertiary lookup: Querying Edge Function for barcode: "$cleanBarcode"');
      final response = await supabaseClient.functions.invoke(
        'scan-food',
        body: {
          'barcode': cleanBarcode,
        },
      );

      final decoded = _decodeMap(response.data);
      if (response.status == 200 && decoded.containsKey('productName')) {
        final productName = decoded['productName'] as String;
        final servingSize = decoded['servingSize'] as String? ?? '100g';
        final nutriments = decoded['nutriments'] as Map<String, dynamic>;

        final foodItem = FoodItem(
          id: barcode,
          name: productName,
          confidenceScore: 1.0,
          servingDescription: servingSize,
          quantity: 1.0,
          unit: 'serving',
        );

        final double calories = (nutriments['calories'] as num?)?.toDouble() ?? 0.0;
        final double proteinG = (nutriments['protein'] as num?)?.toDouble() ?? 0.0;
        final double carbsG = (nutriments['carbs'] as num?)?.toDouble() ?? 0.0;
        final double fatG = (nutriments['fat'] as num?)?.toDouble() ?? 0.0;
        final double fiberG = (nutriments['fiber'] as num?)?.toDouble() ?? 0.0;
        final double sugarG = (nutriments['sugar'] as num?)?.toDouble() ?? 0.0;
        final double sodiumMg = (nutriments['sodium'] as num?)?.toDouble() ?? 0.0;

        final nutritionInfo = NutritionInfo(
          calories: calories,
          proteinG: proteinG,
          carbsG: carbsG,
          fatG: fatG,
          fiberG: fiberG,
          sugarG: sugarG,
          sodiumMg: sodiumMg,
          per: foodItem,
        );

        // Save to local cache
        await _cacheLocally(cleanBarcode, productName, servingSize, nutritionInfo);

        return Right(nutritionInfo);
      } else {
        return const Left(BarcodeNotFoundFailure());
      }
    } on FunctionException catch (e) {
      logger.e('Function error in lookupBarcode: status=${e.status} details=${e.details}');
      if (e.status == 404) {
        return const Left(BarcodeNotFoundFailure());
      }
      return const Left(ServerFailure('Failed to lookup barcode. Please try again.'));
    } catch (e) {
      logger.e('Unexpected error in lookupBarcode: $e');
      final errorMessage = e.toString();
      if (errorMessage.contains('SocketException') || errorMessage.contains('Failed host lookup')) {
        return const Left(NetworkFailure('No internet connection. Please check your connection.'));
      }
      return const Left(ServerFailure('An unexpected error occurred.'));
    }
  }

  @override
  Future<Either<Failure, void>> saveProprietaryProduct(
    String barcode,
    String productName,
    NutritionInfo nutrition,
    String source,
  ) async {
    try {
      final cleanBarcode = barcode.trim();
      if (cleanBarcode.isEmpty) {
        return const Left(ValidationFailure('Barcode cannot be empty.'));
      }

      // 1. Cache locally in Isar
      await _cacheLocally(
        cleanBarcode,
        productName,
        nutrition.per.servingDescription,
        nutrition,
      );

      // 2. Cache remotely in Supabase proprietary_products database
      logger.i('Saving barcode "$cleanBarcode" to Supabase proprietary_products...');
      final payload = {
        'barcode': cleanBarcode,
        'product_name': productName,
        'serving_size': nutrition.per.servingDescription,
        'calories': nutrition.calories,
        'protein_g': nutrition.proteinG,
        'carbs_g': nutrition.carbsG,
        'fat_g': nutrition.fatG,
        'fiber_g': nutrition.fiberG,
        'sugar_g': nutrition.sugarG,
        'sodium_mg': nutrition.sodiumMg,
        'source': source,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      await supabaseClient.from('proprietary_products').upsert(payload);
      logger.i('Successfully saved product "$productName" to remote proprietary DB.');

      // 3. Contribute to Open Food Facts in the background
      _contributeToOpenFoodFacts(cleanBarcode, productName, nutrition);

      return const Right(null);
    } catch (e) {
      logger.e('Error in saveProprietaryProduct: $e');
      return Left(ServerFailure('Failed to save product details: $e'));
    }
  }

  Future<void> _cacheLocally(
    String barcodeStr,
    String productName,
    String servingSize,
    NutritionInfo info,
  ) async {
    try {
      final cache = BarcodeCache()
        ..barcode = barcodeStr
        ..productName = productName
        ..servingSize = servingSize
        ..calories = info.calories
        ..proteinG = info.proteinG
        ..carbsG = info.carbsG
        ..fatG = info.fatG
        ..fiberG = info.fiberG
        ..sugarG = info.sugarG
        ..sodiumMg = info.sodiumMg
        ..cachedAt = DateTime.now();

      await isarService.isar.writeTxn(() async {
        await isarService.isar.barcodeCaches.put(cache);
      });
      logger.i('Saved barcode "$barcodeStr" to local Isar cache.');
    } catch (e) {
      logger.e('Failed to save barcode to local cache: $e');
    }
  }

  void _contributeToOpenFoodFacts(
    String barcode,
    String productName,
    NutritionInfo nutrition,
  ) async {
    try {
      final double calories = nutrition.calories;
      final double protein = nutrition.proteinG;
      final double carbs = nutrition.carbsG;
      final double fat = nutrition.fatG;
      final double fiber = nutrition.fiberG;
      final double sugar = nutrition.sugarG;
      final double sodiumG = nutrition.sodiumMg / 1000.0;

      final Map<String, String> params = {
        'code': barcode,
        'product_name': productName,
        'brands': 'Unknown Brand',
        'countries': 'India',
        'nutriment_energy-kcal': calories.toStringAsFixed(1),
        'nutriment_proteins': protein.toStringAsFixed(1),
        'nutriment_carbohydrates': carbs.toStringAsFixed(1),
        'nutriment_fat': fat.toStringAsFixed(1),
        'nutriment_fiber': fiber.toStringAsFixed(1),
        'nutriment_sugars': sugar.toStringAsFixed(1),
        'nutriment_sodium': sodiumG.toStringAsFixed(3),
        'nutrition_data_per': '100g',
        'user_id': 'vitalup_app',
        'password': 'vitalup_password_123',
      };

      logger.i('Contributing product to Open Food Facts in background: $barcode - $productName');
      await dio.get(
        'https://in.openfoodfacts.org/cgi/product_jqm2.pl',
        queryParameters: params,
        options: Options(
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'User-Agent': 'VitalUp - Android/iOS - Version 1.0.0',
          },
        ),
      );
      logger.i('Successfully sent contribution request to Open Food Facts write API.');
    } catch (e) {
      logger.e('Failed to contribute to Open Food Facts: $e');
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

  @override
  Future<List<OfflineFood>> searchOfflineFoods(String query) async {
    try {
      final queryLower = query.toLowerCase().trim();
      if (queryLower.isEmpty) return [];

      final results = await isarService.isar.offlineFoods
          .filter()
          .nameContains(queryLower, caseSensitive: false)
          .limit(20)
          .findAll();

      // Prioritize exact prefix matches (e.g. "Roti" prioritizes "Roti" over "Aloo Paratha with Roti")
      results.sort((a, b) {
        final aStart = a.name.toLowerCase().startsWith(queryLower);
        final bStart = b.name.toLowerCase().startsWith(queryLower);
        if (aStart && !bStart) return -1;
        if (!aStart && bStart) return 1;
        return a.name.compareTo(b.name);
      });

      return results;
    } catch (e) {
      logger.e('Error searching offline foods: $e');
      return [];
    }
  }
}