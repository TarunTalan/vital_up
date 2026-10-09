import 'package:isar_community/isar.dart';
import 'package:uuid/uuid.dart';
import 'package:vital_up/core/database/collections/meal_log_cache.dart';
import 'package:vital_up/core/database/isar_service.dart';
import 'package:vital_up/core/sync/sync_hooks.dart';
import 'package:vital_up/features/food_scanner/data/datasources/meal_log_local_data_source.dart';
import 'package:vital_up/features/food_scanner/domain/entities/food_item.dart';
import 'package:vital_up/features/food_scanner/domain/entities/meal_log_entry.dart';
import 'package:vital_up/features/food_scanner/domain/entities/nutrition_info.dart';
import 'package:vital_up/features/food_scanner/domain/nutrition_sanity.dart';
import 'package:vital_up/core/events/habit_events.dart';

class MealLogLocalDataSourceImpl implements MealLogLocalDataSource {
  final IsarService isarService;
  final Uuid uuid;
  final SyncHooks? sync;
  final HabitEvents? events;

  MealLogLocalDataSourceImpl({
    required this.isarService,
    required this.uuid,
    this.sync,
    this.events,
  });

  @override
  Future<void> saveMealLog(MealLogEntry entry) async {
    final cache = _toCache(entry);
    await isarService.isar.writeTxn(() async {
      await isarService.isar.mealLogCaches.put(cache);
    });
    sync?.schedule();
    if (_isToday(entry.capturedAt)) {
      events?.logged(HabitLogged(Habit.meal, mealType: entry.mealType.index));
    }
  }

  static bool _isToday(DateTime t) {
    final now = DateTime.now();
    return t.year == now.year && t.month == now.month && t.day == now.day;
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
    final wasSynced = await isarService.isar.mealLogCaches
        .where()
        .mealLogIdEqualTo(id)
        .filter()
        .isSyncedEqualTo(true)
        .isNotEmpty();
    await isarService.isar.writeTxn(() async {
      await isarService.isar.mealLogCaches
          .where()
          .mealLogIdEqualTo(id)
          .deleteAll();
    });
    if (wasSynced) await sync?.recordDelete('meal_logs', id);
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

  /// Rows synced from another device or an older app version can have
  /// parallel lists of different lengths, an unknown meal type or non-finite
  /// numbers; read them defensively instead of throwing a RangeError.
  MealLogEntry _toDomain(MealLogCache cache) {
    T at<T>(List<T> list, int i, T fallback) => i < list.length ? list[i] : fallback;

    final items = List.generate(
      cache.itemIds.length,
      (index) => FoodItem(
        id: cache.itemIds[index],
        name: at(cache.itemNames, index, 'Food'),
        confidenceScore: at(cache.itemConfidences, index, 1.0),
        servingDescription: at(cache.itemServingDescriptions, index, ''),
        quantity: saneQuantity(at(cache.itemQuantities, index, 1.0)),
        unit: at(cache.itemUnits, index, 'serving'),
      ),
    );

    // One nutrition row per item; a row without an item is dropped.
    final nutritionCount = cache.nutritionCalories.length < items.length ? cache.nutritionCalories.length : items.length;
    final nutrition = List.generate(
      nutritionCount,
      (index) => sanitizeNutrition(NutritionInfo(
        calories: cache.nutritionCalories[index],
        proteinG: at(cache.nutritionProteinG, index, 0.0),
        carbsG: at(cache.nutritionCarbsG, index, 0.0),
        fatG: at(cache.nutritionFatG, index, 0.0),
        fiberG: at(cache.nutritionFiberG, index, 0.0),
        sugarG: at(cache.nutritionSugarG, index, 0.0),
        sodiumMg: at(cache.nutritionSodiumMg, index, 0.0),
        per: items[index],
      )),
    );

    final mealType = cache.mealType >= 0 && cache.mealType < MealType.values.length
        ? MealType.values[cache.mealType]
        : MealType.snack;

    return MealLogEntry(
      id: cache.mealLogId,
      capturedAt: cache.capturedAt,
      imagePath: cache.imagePath,
      items: items,
      nutrition: nutrition,
      totalCalories: saneAmount(cache.totalCalories, max: NutritionLimits.caloriesMax * 10),
      mealType: mealType,
      userConfirmed: cache.userConfirmed,
    );
  }
}
