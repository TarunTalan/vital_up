import 'package:isar_community/isar.dart';
import 'package:uuid/uuid.dart';
import 'package:vital_up/core/database/collections/meal_log_cache.dart';
import 'package:vital_up/core/database/isar_service.dart';
import 'package:vital_up/features/food_scan/data/datasources/meal_log_local_data_source.dart';
import 'package:vital_up/features/food_scan/domain/entities/food_item.dart';
import 'package:vital_up/features/food_scan/domain/entities/meal_log_entry.dart';
import 'package:vital_up/features/food_scan/domain/entities/nutrition_info.dart';

class MealLogLocalDataSourceImpl implements MealLogLocalDataSource {
  final IsarService isarService;
  final Uuid uuid;

  MealLogLocalDataSourceImpl({
    required this.isarService,
    required this.uuid,
  });

  @override
  Future<void> saveMealLog(MealLogEntry entry) async {
    final cache = _toCache(entry);
    await isarService.isar.writeTxn(() async {
      await isarService.isar.mealLogCaches.put(cache);
    });
  }

  @override
  Future<List<MealLogEntry>> getMealLogsForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final caches = await isarService.isar.mealLogCaches
        .where()
        .capturedAtBetween(startOfDay, endOfDay)
        .sortByCapturedAtDesc()
        .findAll();

    return caches.map(_toDomain).toList();
  }

  @override
  Future<List<MealLogEntry>> getAllMealLogs() async {
    final caches = await isarService.isar.mealLogCaches
        .where()
        .sortByCapturedAtDesc()
        .findAll();

    return caches.map(_toDomain).toList();
  }

  @override
  Future<void> deleteMealLog(String id) async {
    await isarService.isar.writeTxn(() async {
      await isarService.isar.mealLogCaches
          .where()
          .mealLogIdEqualTo(id)
          .deleteAll();
    });
  }

  MealLogCache _toCache(MealLogEntry entry) {
    return MealLogCache()
      ..mealLogId = entry.id.isEmpty ? uuid.v4() : entry.id
      ..capturedAt = entry.capturedAt
      ..imagePath = entry.imagePath
      ..itemIds = entry.items.map((item) => item.id).toList()
      ..itemNames = entry.items.map((item) => item.name).toList()
      ..itemConfidences = entry.items.map((item) => item.confidenceScore).toList()
      ..itemServingDescriptions = entry.items.map((item) => item.servingDescription).toList()
      ..itemQuantities = entry.items.map((item) => item.quantity).toList()
      ..itemUnits = entry.items.map((item) => item.unit).toList()
      ..nutritionCalories = entry.nutrition.map((nut) => nut.calories).toList()
      ..nutritionProteinG = entry.nutrition.map((nut) => nut.proteinG).toList()
      ..nutritionCarbsG = entry.nutrition.map((nut) => nut.carbsG).toList()
      ..nutritionFatG = entry.nutrition.map((nut) => nut.fatG).toList()
      ..nutritionFiberG = entry.nutrition.map((nut) => nut.fiberG).toList()
      ..nutritionSugarG = entry.nutrition.map((nut) => nut.sugarG).toList()
      ..nutritionSodiumMg = entry.nutrition.map((nut) => nut.sodiumMg).toList()
      ..totalCalories = entry.totalCalories
      ..mealType = entry.mealType.index
      ..userConfirmed = entry.userConfirmed
      ..createdAt = DateTime.now();
  }

  MealLogEntry _toDomain(MealLogCache cache) {
    final items = List.generate(
      cache.itemIds.length,
      (index) => FoodItem(
        id: cache.itemIds[index],
        name: cache.itemNames[index],
        confidenceScore: cache.itemConfidences[index],
        servingDescription: cache.itemServingDescriptions[index],
        quantity: cache.itemQuantities[index],
        unit: cache.itemUnits[index],
      ),
    );

    final nutrition = List.generate(
      cache.nutritionCalories.length,
      (index) => NutritionInfo(
        calories: cache.nutritionCalories[index],
        proteinG: cache.nutritionProteinG[index],
        carbsG: cache.nutritionCarbsG[index],
        fatG: cache.nutritionFatG[index],
        fiberG: cache.nutritionFiberG[index],
        sugarG: cache.nutritionSugarG[index],
        sodiumMg: cache.nutritionSodiumMg[index],
        per: items[index],
      ),
    );

    return MealLogEntry(
      id: cache.mealLogId,
      capturedAt: cache.capturedAt,
      imagePath: cache.imagePath,
      items: items,
      nutrition: nutrition,
      totalCalories: cache.totalCalories,
      mealType: MealType.values[cache.mealType],
      userConfirmed: cache.userConfirmed,
    );
  }
}
