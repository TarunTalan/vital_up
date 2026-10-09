import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/cache/cache_store.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/core/network/connectivity_service.dart';
import 'package:vital_up/core/network/offline_errors.dart';
import 'package:vital_up/core/sync/pending_writes.dart';
import 'package:vital_up/features/food_scanner/data/utils/food_cache_keys.dart';
import 'package:vital_up/features/food_scanner/data/models/nutrition_response_parser.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/features/food_scanner/domain/entities/nutrition_info.dart';
import 'package:vital_up/features/food_scanner/domain/nutrition_sanity.dart';
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
  final CacheStore cacheStore;
  final ConnectivityService connectivity;
  final PendingWrites pendingWrites;

  NutritionRepositoryImpl({
    required this.dio,
    required this.logger,
    required this.supabaseClient,
    required this.isarService,
    required this.cacheStore,
    required this.connectivity,
    required this.pendingWrites,
  });

  /// Nutrition facts and search results for a food don't change, so a
  /// lookup is served from cache for a long time.
  static const Duration _lookupMaxAge = Duration(days: 30);

  /// Id prefix for [FoodItem]s built from the seeded offline foods, whose
  /// nutrition is resolved locally.
  static const String _offlineIdPrefix = 'offline:';

  static const _offlineMessage = "You're offline. Check your connection.";
  static const _signInMessage = 'Please sign in to look up food.';

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

  /// Calls the `scan-food` edge function through [cacheStore]: a cached
  /// response is reused for [_lookupMaxAge], concurrent identical lookups
  /// share one request, and offline the last response is returned.
  ///
  /// Responses failing [worthCaching] (empty / placeholder answers) are
  /// returned but not stored, so a later lookup tries the server again.
  ///
  /// Throws a [SocketException] straight away when there is no network and
  /// nothing cached, rather than waiting for the request to fail, and
  /// [_NoSession] when a request is needed but nobody is signed in.
  Future<Map<String, dynamic>> _invokeCached(
    String key,
    Map<String, dynamic> body, {
    required bool Function(Map<String, dynamic> data) worthCaching,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    if (!connectivity.hasNetwork) {
      final cached = await cacheStore.read<Map<String, dynamic>>(key, decode: _asMap);
      if (cached != null) return cached.value;
      throw const SocketException('No network');
    }
    try {
      return await cacheStore.fetch<Map<String, dynamic>>(
        key,
        maxAge: _lookupMaxAge,
        decode: _asMap,
        remote: () async {
          if (supabaseClient.auth.currentSession?.accessToken == null) throw const _NoSession();
          final response = await supabaseClient.functions.invoke('scan-food', body: body).timeout(timeout);
          if (response.status != 200) throw _BadStatus(response.status);
          final data = _decodeMap(response.data);
          if (!worthCaching(data)) throw _Uncached(data);
          return data;
        },
      );
    } on _Uncached catch (e) {
      return e.data;
    }
  }

  static Map<String, dynamic> _asMap(Object? json) => Map<String, dynamic>.from(json as Map);

  @override
  Future<Either<Failure, NutritionInfo>> getNutrition(FoodItem item) async {
    // Seeded offline foods carry their own facts; no request needed.
    if (item.id.startsWith(_offlineIdPrefix)) {
      final local = await _offlineNutrition(item);
      if (local != null) return Right(local);
    }
    try {
      final data = await _invokeCached(
        FoodCacheKeys.nutrition(item.id, item.name, item.servingDescription),
        {
          'get_nutrition': true,
          'fdc_id': item.id,
          // Lets the server fall back to a name lookup / estimate when the id
          // is a USDA id or barcode it can't resolve.
          'food_name': item.name,
          'serving_description': item.servingDescription,
        },
        // All zeros means "not found, estimate offline"; worth asking again later.
        worthCaching: (data) => const ['calories', 'protein_g', 'carbs_g', 'fat_g'].any((k) => saneAmount(data[k]) != 0),
      );
      return Right(parseNutritionResponse(data, item));
    } on _NoSession {
      logger.e('getNutrition failed: No active session found.');
      return const Left(ServerFailure(_signInMessage));
    } on _BadStatus catch (e) {
      logger.e('getNutrition failed: $e');
      return const Left(ServerFailure("Couldn't load nutrition. Try again."));
    } catch (e) {
      if (isOfflineError(e)) {
        final local = await _offlineNutrition(item);
        if (local != null) {
          logger.i('getNutrition offline: using seeded offline food for "${item.name}"');
          return Right(local);
        }
        return const Left(NetworkFailure(_offlineMessage));
      }
      logger.e('Unexpected error in getNutrition: $e');
      return const Left(ServerFailure("Couldn't load nutrition. Try again."));
    }
  }

  /// Nutrition for [item] from the seeded offline foods (exact name match),
  /// scaled from the food's serving to [item]'s quantity where the units
  /// line up. Null when there is no match.
  Future<NutritionInfo?> _offlineNutrition(FoodItem item) async {
    final name = item.id.startsWith(_offlineIdPrefix) ? item.id.substring(_offlineIdPrefix.length) : item.name;
    final wanted = normalizeFoodQuery(name);
    if (wanted.isEmpty) return null;
    final matches = await searchOfflineFoods(wanted);
    final food = matches.where((f) => normalizeFoodQuery(f.name) == wanted).firstOrNull;
    if (food == null) return null;

    final base = NutritionInfo(
      calories: food.calories,
      proteinG: food.proteinG,
      carbsG: food.carbsG,
      fatG: food.fatG,
      fiberG: food.fiberG,
      sugarG: food.sugarG,
      sodiumMg: food.sodiumMg,
      per: item,
    );
    final factor = servingScale(food.servingSize, item);
    return sanitizeNutrition(factor == 1.0 ? base : base.scaledBy(factor).copyWith(per: item));
  }

  /// How many of [serving] (e.g. "1 bowl (150g)", "2 pieces (60g)") make up
  /// [item]'s quantity: by weight for gram quantities, by count otherwise.
  /// 1.0 when it can't tell.
  @visibleForTesting
  static double servingScale(String serving, FoodItem item) {
    if (item.quantity <= 0) return 1.0;
    final unit = item.unit.toLowerCase();
    if (unit == 'g' || unit == 'ml') {
      final grams = RegExp(r'(\d+(?:\.\d+)?)\s*(?:g|ml)\b').firstMatch(serving.toLowerCase());
      final amount = double.tryParse(grams?.group(1) ?? '');
      return amount == null || amount <= 0 ? 1.0 : item.quantity / amount;
    }
    final count = double.tryParse(RegExp(r'^\s*(\d+(?:\.\d+)?)').firstMatch(serving)?.group(1) ?? '');
    return count == null || count <= 0 ? item.quantity : item.quantity / count;
  }

  @override
  Future<Either<Failure, NutritionInfo>> lookupBarcode(String barcode) async {
    try {
      // Plain QR codes and malformed scans never reach the network.
      final cleanBarcode = normalizeProductBarcode(barcode);
      if (cleanBarcode == null) {
        logger.w('lookupBarcode: "$barcode" is not a product barcode');
        return const Left(ValidationFailure("That isn't a product barcode. Try another."));
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
            id: cleanBarcode,
            name: saneFoodName(cached.productName, fallback: 'Product'),
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
          return Right(sanitizeNutrition(nutritionInfo));
        }
      } catch (cacheErr) {
        logger.e('Failed to lookup barcode in local Isar cache: $cacheErr');
      }

      // Not cached and no network: don't wait on two requests to time out.
      if (!connectivity.hasNetwork) {
        return const Left(NetworkFailure(_offlineMessage));
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

        final data = response.data;
        if (response.statusCode == 200 && data is Map) {
          final rawProduct = data['product'];
          final product = rawProduct is Map ? Map<String, dynamic>.from(rawProduct) : null;
          final status = data['status'];
          final isFound = status == 1 || status == '1';

          if (isFound && product != null && product.isNotEmpty) {
            final productName = saneFoodName(
              product['product_name'] ?? product['product_name_en'],
              fallback: 'Unknown Product',
            );
            final rawNutriments = product['nutriments'];
            final nutriments = rawNutriments is Map ? Map<String, dynamic>.from(rawNutriments) : <String, dynamic>{};

            // Read every nutrient on one basis: per serving when the label
            // gives energy per serving, otherwise per 100 g. Mixing the two
            // (calories per serving, protein per 100 g) skews the entry.
            final perServing = saneAmount(nutriments['energy-kcal_serving']) > 0 ||
                saneAmount(nutriments['energy_serving']) > 0;
            final servingSize = perServing
                ? saneFoodName(product['serving_size'], fallback: '1 serving')
                : '100g';

            final countriesTags = product['countries_tags'] is List ? product['countries_tags'] as List : null;
            final isIndian = countriesTags?.any((t) => t.toString().toLowerCase().contains('india')) ?? false;
            logger.d('Open Food Facts hit countries: $countriesTags (isIndian: $isIndian)');

            final foodItem = FoodItem(
              id: cleanBarcode,
              name: productName,
              confidenceScore: 1.0,
              servingDescription: servingSize,
              quantity: 1.0,
              unit: 'serving',
            );

            double getNutrientValue(String baseKey) =>
                saneAmount(nutriments['${baseKey}_${perServing ? 'serving' : '100g'}']);

            double getNutrientInGrams(String baseKey) {
              final val = getNutrientValue(baseKey);
              final unit = (nutriments['${baseKey}_unit']?.toString() ?? 'g').toLowerCase();
              if (unit == 'mg') return val / 1000.0;
              if (unit == 'mcg' || unit == 'µg') return val / 1000000.0;
              return val;
            }

            double getNutrientInMilligrams(String baseKey) {
              final val = getNutrientValue(baseKey);
              final unit = (nutriments['${baseKey}_unit']?.toString() ?? 'g').toLowerCase();
              if (unit == 'g') return val * 1000.0;
              if (unit == 'mcg' || unit == 'µg') return val / 1000.0;
              return val;
            }

            double calories = getNutrientValue('energy-kcal');
            if (calories == 0.0) {
              final energyKj = getNutrientValue('energy');
              final energyUnit = (nutriments['energy_unit']?.toString() ?? '').toLowerCase();
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

            offNutrition = sanitizeNutrition(NutritionInfo(
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
            ));

            if (productName != 'Unknown Product' && (calories > 0 || proteinG > 0 || carbsG > 0 || fatG > 0)) {
              offSuccess = true;
            }
          }
        }
      } catch (e) {
        logger.w('Open Food Facts lookup failed or timed out: $e');
        // Unreachable network: the edge function fallback would fail the same way.
        if (isOfflineError(e)) {
          connectivity.reportFailure();
          return const Left(NetworkFailure(_offlineMessage));
        }
      }

      if (offSuccess && offNutrition != null) {
        logger.i('Secondary Open Food Facts lookup succeeded for barcode "$cleanBarcode"');
        // Save to local cache
        await _cacheLocally(cleanBarcode, offNutrition.per.name, offNutrition.per.servingDescription, offNutrition);
        return Right(offNutrition);
      }

      // 3. Fallback: Query the Supabase Edge Function (checks proprietary DB first, then OFF global, then Gemini search grounding)
      logger.i('Tertiary lookup: Querying Edge Function for barcode: "$cleanBarcode"');
      if (supabaseClient.auth.currentSession?.accessToken == null) {
        logger.e('lookupBarcode fallback failed: No active session found.');
        return const Left(ServerFailure(_signInMessage));
      }
      final response = await supabaseClient.functions.invoke(
        'scan-food',
        body: {
          'barcode': cleanBarcode,
        },
      ).timeout(const Duration(seconds: 25));

      final decoded = _decodeMap(response.data);
      final rawNutriments = decoded['nutriments'];
      final productName = saneFoodName(decoded['productName']);
      if (response.status == 200 && productName.isNotEmpty && rawNutriments is Map) {
        final servingSize = saneFoodName(decoded['servingSize'], fallback: '100g');
        final nutriments = Map<String, dynamic>.from(rawNutriments);

        final foodItem = FoodItem(
          id: cleanBarcode,
          name: productName,
          confidenceScore: 1.0,
          servingDescription: servingSize,
          quantity: 1.0,
          unit: 'serving',
        );

        final nutritionInfo = sanitizeNutrition(NutritionInfo(
          calories: saneAmount(nutriments['calories']),
          proteinG: saneAmount(nutriments['protein']),
          carbsG: saneAmount(nutriments['carbs']),
          fatG: saneAmount(nutriments['fat']),
          fiberG: saneAmount(nutriments['fiber']),
          sugarG: saneAmount(nutriments['sugar']),
          sodiumMg: saneAmount(nutriments['sodium']),
          per: foodItem,
        ));

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
      if (isOfflineError(e)) {
        connectivity.reportFailure();
        return const Left(NetworkFailure(_offlineMessage));
      }
      return const Left(ServerFailure("Couldn't look up that barcode. Try again."));
    } on TimeoutException {
      logger.e('lookupBarcode timed out');
      return const Left(NetworkFailure('This is taking too long. Try again.'));
    } catch (e) {
      logger.e('Unexpected error in lookupBarcode: $e');
      if (isOfflineError(e)) {
        connectivity.reportFailure();
        return const Left(NetworkFailure(_offlineMessage));
      }
      return const Left(ServerFailure("Couldn't look up that barcode. Try again."));
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
      final cleanBarcode = normalizeProductBarcode(barcode);
      if (cleanBarcode == null) {
        return const Left(ValidationFailure("That isn't a product barcode."));
      }
      // Typed / OCR values are cleaned and clamped before they are stored
      // here or shared with the server.
      productName = saneFoodName(productName, fallback: 'Product');
      nutrition = sanitizeNutrition(nutrition);
      source = sanitizeText(source, maxLength: 20);

      // 1. Cache locally in Isar
      await _cacheLocally(
        cleanBarcode,
        productName,
        nutrition.per.servingDescription,
        nutrition,
      );

      // 2. Cache remotely in Supabase proprietary_products database. The
      // local copy above is what lookups use, so the remote write can wait
      // in the outbox when offline.
      final userId = supabaseClient.auth.currentUser?.id;
      if (userId == null) {
        logger.w('Not signed in; saved barcode "$cleanBarcode" locally only.');
        return const Right(null);
      }
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

      try {
        final sent = await pendingWrites.sendOrQueue(
          supabaseClient,
          PendingWrite.upsert(
            'proprietary_products',
            values: payload,
            userId: userId,
            // One queued write per barcode; a re-edit offline replaces it.
            key: 'proprietary_products:$cleanBarcode',
          ),
        );
        logger.i(sent
            ? 'Successfully saved product "$productName" to remote proprietary DB.'
            : 'Offline: queued product "$productName" for the remote proprietary DB.');
      } catch (e) {
        // Rejected by the server; the local copy still serves this device.
        logger.e('Remote save of barcode "$cleanBarcode" failed: $e');
      }

      // Products users enter stay in VitalUp: nothing is shared with Open
      // Food Facts (no user consent, and entries aren't per 100 g).

      return const Right(null);
    } catch (e) {
      logger.e('Error in saveProprietaryProduct: $e');
      return const Left(ServerFailure("Couldn't save this product. Try again."));
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

  @override
  Future<Either<Failure, List<FoodItem>>> searchByName(String query) async {
    query = sanitizeText(query, maxLength: InputLimits.search);
    if (normalizeFoodQuery(query).isEmpty) {
      return const Left(ServerFailure('No matches. Try another name.'));
    }
    try {
      final data = await _invokeCached(
        FoodCacheKeys.search(query),
        {'search_query': normalizeFoodQuery(query)},
        // An empty answer may be a provider hiccup; don't remember it.
        worthCaching: (data) => (data['items'] as List<dynamic>?)?.isNotEmpty ?? false,
      );
      // Malformed or nameless rows from the server are skipped.
      final rawItems = data['items'];
      final foodItems = <FoodItem>[
        if (rawItems is List)
          for (final dto in rawItems.whereType<Map<dynamic, dynamic>>())
            if (saneFoodName(dto['name']).isNotEmpty)
              FoodItem(
                id: dto['fdc_id']?.toString() ?? dto['id']?.toString() ?? '',
                name: saneFoodName(dto['name']),
                confidenceScore: 1.0,
                servingDescription: saneFoodName(dto['serving_description'], fallback: '100g'),
                quantity: 1.0,
                unit: 'serving',
              ),
      ];

      if (foodItems.isEmpty) {
        return const Left(ServerFailure('No matches. Try another name.'));
      }
      return Right(foodItems);
    } on _NoSession {
      logger.e('searchByName failed: No active session found.');
      return const Left(ServerFailure(_signInMessage));
    } on _BadStatus catch (e) {
      logger.e('searchByName failed: $e');
      return const Left(ServerFailure("Couldn't search right now. Try again."));
    } catch (e) {
      if (isOfflineError(e)) {
        // Offline and never searched before: answer from the seeded foods.
        final offline = await searchOfflineFoods(query);
        if (offline.isEmpty) return const Left(NetworkFailure(_offlineMessage));
        return Right([
          for (final f in offline)
            FoodItem(
              id: '$_offlineIdPrefix${f.name}',
              name: f.name,
              confidenceScore: 1.0,
              servingDescription: f.servingSize,
              quantity: 1.0,
              unit: 'serving',
            ),
        ]);
      }
      logger.e('Unexpected error in searchByName: $e');
      return const Left(ServerFailure("Couldn't search right now. Try again."));
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

/// The edge function answered with a non-200 status.
class _BadStatus implements Exception {
  final int status;
  const _BadStatus(this.status);

  @override
  String toString() => 'scan-food responded $status';
}

/// A request was needed but there is no signed-in session.
class _NoSession implements Exception {
  const _NoSession();
}

/// A response to return without caching (see `_invokeCached`).
class _Uncached implements Exception {
  final Map<String, dynamic> data;
  const _Uncached(this.data);
}
