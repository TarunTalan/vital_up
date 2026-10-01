import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/features/food_scanner/data/models/food_item_dto.dart';
import 'package:vital_up/features/food_scanner/data/models/nutrition_response_parser.dart';
import 'package:vital_up/features/food_scanner/data/utils/food_image_encoder.dart';
import 'package:vital_up/features/food_scanner/domain/entities/food_item.dart';
import 'package:vital_up/features/food_scanner/domain/entities/recognized_food.dart';
import 'package:vital_up/features/food_scanner/domain/repositories/food_recognition_repository.dart';

class FoodRecognitionRepositoryImpl implements FoodRecognitionRepository {
  final Logger logger;
  final SupabaseClient supabaseClient;

  FoodRecognitionRepositoryImpl({
    required this.logger,
    required this.supabaseClient,
  });

  /// Upper bound for one recognition round trip. The edge function caps each
  /// provider at 30 s and hedges to a second provider, so this only trips
  /// when the network itself is stuck.
  static const Duration _recognitionTimeout = Duration(seconds: 50);

  final Map<String, List<RecognizedFood>> _cache = {};

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
  Future<Either<Failure, List<RecognizedFood>>> recognizeFood(File image) async {
    logger.i('recognizeFood called with image: ${image.path}');
    if (supabaseClient.auth.currentSession?.accessToken == null) {
      logger.e('recognizeFood failed: No active session found.');
      return const Left(ServerFailure('User is not authenticated. Please log in.'));
    }
    try {
      // The capture flow overwrites the same path with the cropped photo, so
      // the path alone would return a previous scan's result.
      final cacheKey = '${image.path}:${(await image.lastModified()).millisecondsSinceEpoch}';
      final cached = _cache[cacheKey];
      if (cached != null) {
        logger.d('Returning cached food recognition result');
        return Right(cached);
      }

      final stopwatch = Stopwatch()..start();
      final imageBytes = await encodeFoodImageForUpload(image.path);
      logger.d('Encoded image: ${imageBytes.length ~/ 1024} KB in ${stopwatch.elapsedMilliseconds} ms');

      final response = await supabaseClient.functions
          .invoke(
            'scan-food',
            body: {
              'image': base64Encode(imageBytes),
              'mime_type': 'image/jpeg',
            },
          )
          .timeout(_recognitionTimeout);

      logger.d('scan-food responded ${response.status} in ${stopwatch.elapsedMilliseconds} ms');

      final data = _decodeMap(response.data);
      final itemsData = data['items'] as List<dynamic>?;
      logger.d('Recognized items (${data['served_by']}): $itemsData');

      if (itemsData == null || itemsData.isEmpty) {
        return const Left(NoFoodDetectedFailure());
      }

      final foods = itemsData.whereType<Map<String, dynamic>>().map(_toRecognizedFood).toList();
      _cache[cacheKey] = foods;
      return Right(foods);
    } on FunctionException catch (e) {
      // Provider error details are for logs only; never show raw JSON to users.
      logger.e('scan-food function error: status=${e.status} details=${e.details}');
      switch (e.status) {
        case 402:
        case 403:
        case 429:
          return const Left(ScanQuotaExceededFailure());
        case 503:
          return const Left(RecognitionUnavailableFailure());
        default:
          return const Left(ServerFailure('Failed to recognize food. Please try again.'));
      }
    } on TimeoutException {
      logger.e('recognizeFood timed out after ${_recognitionTimeout.inSeconds}s');
      return const Left(NetworkFailure('Recognition is taking too long. Check your connection and try again.'));
    } catch (e) {
      logger.e('Unexpected error in recognizeFood: $e');
      final errorMessage = e.toString();
      if (errorMessage.contains('SocketException') || errorMessage.contains('Failed host lookup')) {
        return const Left(NetworkFailure('No internet connection. Please check your connection.'));
      }
      return const Left(ServerFailure('An unexpected error occurred.'));
    }
  }

  RecognizedFood _toRecognizedFood(Map<String, dynamic> json) {
    final dto = FoodItemDto.fromJson(json);
    final item = dto.toDomain();
    final nutritionJson = json['nutrition'];
    return RecognizedFood(
      item: item,
      lookupKey: dto.fdcId ?? item.name,
      nutrition: nutritionJson is Map<String, dynamic> ? parseNutritionResponse(nutritionJson, item) : null,
    );
  }

  @override
  Future<Either<Failure, List<FoodItem>>> searchByName(String query) async {
    if (supabaseClient.auth.currentSession?.accessToken == null) {
      logger.e('searchByName failed: No active session found.');
      return const Left(ServerFailure('User is not authenticated. Please log in.'));
    }
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
