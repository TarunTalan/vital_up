import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/database/collections/offline_food.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/features/food_scanner/domain/entities/food_item.dart';
import 'package:vital_up/features/food_scanner/domain/entities/nutrition_info.dart';
import 'package:vital_up/features/food_scanner/domain/entities/recognized_food.dart';
import 'package:vital_up/features/food_scanner/domain/repositories/food_recognition_repository.dart';
import 'package:vital_up/features/food_scanner/domain/repositories/nutrition_repository.dart';
import 'package:vital_up/features/food_scanner/domain/usecases/scan_food_image.dart';

FoodItem _item(String id, String name) => FoodItem(
      id: id,
      name: name,
      confidenceScore: 0.9,
      servingDescription: '150 g',
      quantity: 150,
      unit: 'g',
    );

NutritionInfo _nutrition(FoodItem item, double calories) => NutritionInfo(
      calories: calories,
      proteinG: 5,
      carbsG: 20,
      fatG: 4,
      fiberG: 3,
      sugarG: 1,
      sodiumMg: 300,
      per: item,
    );

class _FakeRecognition implements FoodRecognitionRepository {
  Either<Failure, List<RecognizedFood>> result = const Right([]);

  @override
  Future<Either<Failure, List<RecognizedFood>>> recognizeFood(File image) async => result;

  @override
  Future<Either<Failure, List<FoodItem>>> searchByName(String query) async => const Right([]);
}

class _FakeNutrition implements NutritionRepository {
  final lookups = <FoodItem>[];
  Either<Failure, NutritionInfo> Function(FoodItem item) respond =
      (item) => const Left(ServerFailure('down'));

  @override
  Future<Either<Failure, NutritionInfo>> getNutrition(FoodItem item) async {
    lookups.add(item);
    return respond(item);
  }

  @override
  Future<Either<Failure, NutritionInfo>> lookupBarcode(String barcode) => throw UnimplementedError();

  @override
  Future<Either<Failure, List<FoodItem>>> searchByName(String query) => throw UnimplementedError();

  @override
  Future<Either<Failure, void>> saveProprietaryProduct(
    String barcode,
    String productName,
    NutritionInfo nutrition,
    String source,
  ) =>
      throw UnimplementedError();

  @override
  Future<List<OfflineFood>> searchOfflineFoods(String query) => throw UnimplementedError();
}

void main() {
  late _FakeRecognition recognition;
  late _FakeNutrition nutrition;
  late ScanFoodImage scan;
  final image = File('unused.jpg');

  setUp(() {
    recognition = _FakeRecognition();
    nutrition = _FakeNutrition();
    scan = ScanFoodImage(foodRecognitionRepository: recognition, nutritionRepository: nutrition);
  });

  test('uses inline nutrition without extra lookups', () async {
    final dal = _item('a', 'Dal Tadka');
    final rice = _item('b', 'Jeera Rice');
    recognition.result = Right([
      RecognizedFood(item: dal, lookupKey: 'Dal Tadka', nutrition: _nutrition(dal, 165)),
      RecognizedFood(item: rice, lookupKey: 'Jeera Rice', nutrition: _nutrition(rice, 240)),
    ]);

    final result = await scan(image);

    expect(nutrition.lookups, isEmpty);
    final list = result.getOrElse(() => []);
    expect(list.map((n) => n.per.name), ['Dal Tadka', 'Jeera Rice']);
    expect(list.map((n) => n.calories), [165, 240]);
  });

  test('looks up missing nutrition by lookup key but keeps the item id', () async {
    final roti = _item('uuid-1', 'Roti');
    recognition.result = Right([RecognizedFood(item: roti, lookupKey: '12345')]);
    nutrition.respond = (item) => Right(_nutrition(item, 120));

    final list = (await scan(image)).getOrElse(() => []);

    expect(nutrition.lookups.single.id, '12345');
    expect(list.single.per.id, 'uuid-1');
    expect(list.single.calories, 120);
  });

  test('keeps an item with zeroed nutrition when its lookup fails', () async {
    final idli = _item('i', 'Idli');
    recognition.result = Right([RecognizedFood(item: idli, lookupKey: 'Idli')]);

    final list = (await scan(image)).getOrElse(() => []);

    expect(list.single.per.name, 'Idli');
    expect(list.single.calories, 0);
  });

  test('passes recognition failures through', () async {
    recognition.result = const Left(ScanQuotaExceededFailure());
    final result = await scan(image);
    expect(result, const Left<Failure, List<NutritionInfo>>(ScanQuotaExceededFailure()));
  });

  test('empty recognition is reported as no food detected', () async {
    recognition.result = const Right([]);
    final result = await scan(image);
    expect(result.swap().getOrElse(() => const ServerFailure()), isA<NoFoodDetectedFailure>());
  });
}
