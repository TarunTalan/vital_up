import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/cache/cache_store.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/core/network/connectivity_service.dart';
import 'package:vital_up/core/network/offline_errors.dart';
import 'package:vital_up/features/food_scanner/data/models/food_item_dto.dart';
import 'package:vital_up/features/food_scanner/data/models/nutrition_response_parser.dart';
import 'package:vital_up/features/food_scanner/data/utils/food_cache_keys.dart';
import 'package:vital_up/features/food_scanner/data/utils/food_image_encoder.dart';
import 'package:vital_up/features/food_scanner/domain/entities/recognized_food.dart';
import 'package:vital_up/features/food_scanner/domain/repositories/food_recognition_repository.dart';

/// Top-level so the isolate closure captures only [bytes].
Future<String> _hashInBackground(Uint8List bytes) => Isolate.run(() => hashBytes(bytes));

class FoodRecognitionRepositoryImpl implements FoodRecognitionRepository {
  final Logger logger;
  final SupabaseClient supabaseClient;
  final CacheStore cacheStore;
  final ConnectivityService connectivity;

  FoodRecognitionRepositoryImpl({
    required this.logger,
    required this.supabaseClient,
    required this.cacheStore,
    required this.connectivity,
  });

  /// Upper bound for one recognition round trip. The edge function caps each
  /// provider at 30 s and hedges to a second provider, so this only trips
  /// when the network itself is stuck.
  static const Duration _recognitionTimeout = Duration(seconds: 50);

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
    try {
      // Keyed by content, not path: the capture flow overwrites one path with
      // each new photo, and the gallery picker copies the same photo to a new
      // path every time. Hashing a few MB is milliseconds, far cheaper than
      // the edge function call (and a scan from the daily quota) it saves.
      final original = await image.readAsBytes();
      final cacheKey = FoodCacheKeys.recognition(await _hashInBackground(original));
      final cached = await cacheStore.read<List<dynamic>>(cacheKey, decode: (json) => json as List<dynamic>);
      if (cached != null) {
        logger.d('Returning cached food recognition result');
        return Right(_toRecognizedFoods(cached.value));
      }

      // Photos aren't queued for later: the user is waiting on the result.
      if (!connectivity.hasNetwork) {
        return const Left(NetworkFailure('No internet connection. Photo scans need a connection; you can still search or scan a barcode.'));
      }
      if (supabaseClient.auth.currentSession?.accessToken == null) {
        logger.e('recognizeFood failed: No active session found.');
        return const Left(ServerFailure('User is not authenticated. Please log in.'));
      }

      final stopwatch = Stopwatch()..start();
      final imageBytes = await encodeFoodImageBytesForUpload(original);
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
      connectivity.reportSuccess();

      logger.d('scan-food responded ${response.status} in ${stopwatch.elapsedMilliseconds} ms');

      final data = _decodeMap(response.data);
      final itemsData = data['items'] as List<dynamic>?;
      logger.d('Recognized items (${data['served_by']}): $itemsData');

      if (itemsData == null || itemsData.isEmpty) {
        return const Left(NoFoodDetectedFailure());
      }

      // Empty results aren't cached so a retry of the same photo gets a fresh try.
      await cacheStore.write(cacheKey, itemsData);
      await _consumeCachedScan();
      return Right(_toRecognizedFoods(itemsData));
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
          if (isOfflineError(e)) {
            connectivity.reportFailure();
            return const Left(NetworkFailure('No internet connection. Please check your connection.'));
          }
          return const Left(ServerFailure('Failed to recognize food. Please try again.'));
      }
    } on TimeoutException {
      logger.e('recognizeFood timed out after ${_recognitionTimeout.inSeconds}s');
      return const Left(NetworkFailure('Recognition is taking too long. Check your connection and try again.'));
    } catch (e) {
      logger.e('Unexpected error in recognizeFood: $e');
      if (isOfflineError(e)) {
        connectivity.reportFailure();
        return const Left(NetworkFailure('No internet connection. Please check your connection.'));
      }
      return const Left(ServerFailure('An unexpected error occurred.'));
    }
  }

  /// The server just used one of today's scans; keep the cached quota in
  /// step so the next check doesn't need a request to notice.
  Future<void> _consumeCachedScan() async {
    final userId = supabaseClient.auth.currentUser?.id;
    if (userId == null) return;
    await cacheStore.update(
      FoodCacheKeys.remainingScans(userId),
      (data) => data is int && data > 0 ? data - 1 : data,
    );
  }

  List<RecognizedFood> _toRecognizedFoods(List<dynamic> items) =>
      items.whereType<Map<String, dynamic>>().map(_toRecognizedFood).toList();

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
}
