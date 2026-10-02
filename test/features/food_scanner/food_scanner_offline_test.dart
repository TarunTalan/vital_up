import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/cache/cache_store.dart';
import 'package:vital_up/core/database/isar_service.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/core/network/connectivity_service.dart';
import 'package:vital_up/core/sync/pending_writes.dart';
import 'package:vital_up/features/food_scanner/data/repositories/food_recognition_repository_impl.dart';
import 'package:vital_up/features/food_scanner/data/repositories/nutrition_repository_impl.dart';
import 'package:vital_up/features/food_scanner/data/utils/food_cache_keys.dart';
import 'package:vital_up/features/food_scanner/domain/entities/food_item.dart';
import 'package:vital_up/features/food_scanner/domain/entities/nutrition_info.dart';

/// No network interface: repositories must answer without a request.
class _Offline extends ConnectivityService {
  @override
  bool get hasNetwork => false;

  @override
  bool get isOnline => false;
}

FoodItem _item({String id = '123', String name = 'Dal Tadka', double quantity = 1, String unit = 'serving'}) =>
    FoodItem(
      id: id,
      name: name,
      confidenceScore: 1,
      servingDescription: '$quantity $unit',
      quantity: quantity,
      unit: unit,
    );

void main() {
  late Directory dir;
  late CacheStore cache;
  late SupabaseClient client;
  final logger = Logger(level: Level.off);
  final offline = _Offline();

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('food_scanner_test');
    cache = CacheStore(offline, directory: dir);
    // Signed out, pointing nowhere: any request attempt fails the test.
    client = SupabaseClient('http://127.0.0.1:9', 'anon');
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await client.dispose();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Future<NutritionRepositoryImpl> nutritionRepo() async => NutritionRepositoryImpl(
        dio: Dio(),
        logger: logger,
        supabaseClient: client,
        // Never opened: offline-food lookups fail and return no matches.
        isarService: IsarService(),
        cacheStore: cache,
        connectivity: offline,
        pendingWrites: PendingWrites(await SharedPreferences.getInstance(), offline),
      );

  group('keys', () {
    test('queries normalize before keying', () {
      expect(normalizeFoodQuery('  Dal   TADKA '), 'dal tadka');
      expect(FoodCacheKeys.search('Dal  Tadka'), FoodCacheKeys.search(' dal tadka'));
      expect(FoodCacheKeys.search('dal'), isNot(FoodCacheKeys.search('dal tadka')));
    });

    test('content hash is stable and content-sensitive', () {
      expect(hashBytes([1, 2, 3]), hashBytes([1, 2, 3]));
      expect(hashBytes([1, 2, 3]), isNot(hashBytes([1, 2, 4])));
      expect(hashBytes(const []), 'cbf29ce484222325');
      expect(hashBytes([1, 2, 3]).length, 16);
    });
  });

  group('servingScale', () {
    test('grams scale by weight, counts by servings', () {
      expect(NutritionRepositoryImpl.servingScale('1 bowl (150g)', _item(quantity: 300, unit: 'g')), 2);
      expect(NutritionRepositoryImpl.servingScale('2 pieces (60g)', _item(quantity: 4, unit: 'piece')), 2);
      expect(NutritionRepositoryImpl.servingScale('1 serving', _item(quantity: 3)), 3);
      // Grams requested but the serving has no weight: leave as is.
      expect(NutritionRepositoryImpl.servingScale('1 serving', _item(quantity: 200, unit: 'g')), 1);
    });
  });

  group('NutritionRepositoryImpl offline', () {
    test('getNutrition serves a cached lookup without a request', () async {
      final item = _item();
      await cache.write(
        FoodCacheKeys.nutrition(item.id, item.name, item.servingDescription),
        {'calories': 165, 'protein_g': 9, 'carbs_g': 20, 'fat_g': 6},
      );

      final result = await (await nutritionRepo()).getNutrition(item);

      final info = result.getOrElse(() => throw StateError('expected Right, got $result'));
      expect(info.calories, 165);
      expect(info.per, item);
    });

    test('getNutrition without cache or offline match is a NetworkFailure', () async {
      final result = await (await nutritionRepo()).getNutrition(_item());
      expect(result.swap().getOrElse(() => const ServerFailure()), isA<NetworkFailure>());
    });

    test('searchByName reuses a cached search for an equivalent query', () async {
      await cache.write(FoodCacheKeys.search('dal tadka'), {
        'items': [
          {'fdc_id': 42, 'name': 'Dal Tadka', 'serving_description': '1 bowl'},
        ],
      });

      final result = await (await nutritionRepo()).searchByName('  Dal  Tadka ');

      final items = result.getOrElse(() => throw StateError('expected Right, got $result'));
      expect(items.single.id, '42');
      expect(items.single.servingDescription, '1 bowl');
    });

    test('searchByName offline with nothing cached fails fast', () async {
      final result = await (await nutritionRepo()).searchByName('paneer');
      expect(result.swap().getOrElse(() => const ServerFailure()), isA<NetworkFailure>());
    });

    test('saveProprietaryProduct succeeds offline (local copy, remote deferred)', () async {
      final result = await (await nutritionRepo()).saveProprietaryProduct(
        '8901234567890',
        'Bhujia',
        NutritionInfo(
          calories: 550,
          proteinG: 12,
          carbsG: 40,
          fatG: 38,
          fiberG: 4,
          sugarG: 3,
          sodiumMg: 900,
          per: _item(id: '8901234567890', name: 'Bhujia'),
        ),
        'manual',
      );
      expect(result.isRight(), isTrue);
    });

    test('lookupBarcode offline without a local hit is a NetworkFailure', () async {
      final result = await (await nutritionRepo()).lookupBarcode('8901234567890');
      expect(result.swap().getOrElse(() => const ServerFailure()), isA<NetworkFailure>());
    });
  });

  group('FoodRecognitionRepositoryImpl', () {
    late File image;

    setUp(() {
      image = File('${dir.path}/meal.jpg')..writeAsBytesSync(List.generate(2048, (i) => i % 251));
    });

    FoodRecognitionRepositoryImpl repo() => FoodRecognitionRepositoryImpl(
          logger: logger,
          supabaseClient: client,
          cacheStore: cache,
          connectivity: offline,
        );

    test('a photo scanned before is answered from cache, even from a new path', () async {
      await cache.write(FoodCacheKeys.recognition(hashBytes(image.readAsBytesSync())), [
        {'name': 'Jeera Rice', 'confidence': 0.9, 'serving_description': '1 cup', 'quantity': 1, 'unit': 'cup'},
      ]);
      final copy = image.copySync('${dir.path}/picked_again.jpg');

      final result = await repo().recognizeFood(copy);

      final foods = result.getOrElse(() => throw StateError('expected Right, got $result'));
      expect(foods.single.item.name, 'Jeera Rice');
    });

    test('a new photo offline is a NetworkFailure', () async {
      final result = await repo().recognizeFood(image);
      expect(result.swap().getOrElse(() => const ServerFailure()), isA<NetworkFailure>());
    });
  });
}
