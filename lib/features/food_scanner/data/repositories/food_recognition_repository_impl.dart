import 'dart:convert';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/features/food_scanner/data/models/food_item_dto.dart';
import 'package:vital_up/features/food_scanner/domain/entities/food_item.dart';
import 'package:vital_up/features/food_scanner/domain/repositories/food_recognition_repository.dart';

class FoodRecognitionRepositoryImpl implements FoodRecognitionRepository {
  final Logger logger;
  final SupabaseClient supabaseClient;

  FoodRecognitionRepositoryImpl({
    required this.logger,
    required this.supabaseClient,
  });

  final Map<String, FoodItem> _cache = {};

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
  Future<Either<Failure, List<FoodItem>>> recognizeFood(File image) async {
    print('recognizeFood called with image: ${image.path}');
    try {
      final cacheKey = image.path;
      if (_cache.containsKey(cacheKey)) {
        print('Returning cached food recognition result');
        return Right([_cache[cacheKey]!]);
      }

      print('Reading image bytes...');
      final imageBytes = await image.readAsBytes();
      print('Encoding to base64...');
      final base64Image = base64Encode(imageBytes);

      final response = await supabaseClient.functions.invoke(
        'scan-food',
        body: {
          'image': base64Image,
        },
      );

      print('Supabase response status: ${response.status}');
      print('Supabase response data: ${response.data}');

      final data = _decodeMap(response.data);
      final itemsData = data['items'] as List<dynamic>?;
      print('Items data: $itemsData');

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
    } on FunctionException catch (e) {
      logger.e('scan-food function error: status=${e.status} details=${e.details}');
      switch (e.status) {
        case 402:
        case 403:
          return const Left(ScanQuotaExceededFailure());
        case 503:
          return Left(RecognitionUnavailableFailure(_detailsMessage(e.details) ??
              'Food recognition is temporarily busy. Please try again shortly.'));
        default:
          return Left(ServerFailure(
              _detailsMessage(e.details) ?? 'Failed to recognize food. Please try again.'));
      }
    } catch (e) {
      logger.e('Unexpected error in recognizeFood: $e');
      return const Left(ServerFailure('An unexpected error occurred.'));
    }
  }

  String? _detailsMessage(dynamic details) {
    if (details is Map && details['error'] is String) {
      final error = details['error'] as String;
      final extra = details['details'];
      return extra is String ? '$error ($extra)' : error;
    }
    if (details is String && details.isNotEmpty) return details;
    return null;
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