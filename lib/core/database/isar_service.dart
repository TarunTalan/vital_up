import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/database/collections/user_profile_cache.dart';
import 'package:vital_up/core/database/collections/step_log_cache.dart';
import 'package:vital_up/core/database/collections/heart_rate_log_cache.dart';
import 'package:vital_up/core/database/collections/sleep_log_cache.dart';
import 'package:vital_up/core/database/collections/water_log_cache.dart';
import 'package:vital_up/features/diet_plan/data/models/meal_plan_model.dart';
import 'package:vital_up/core/database/collections/favorite_audio.dart';
import 'package:vital_up/core/database/collections/downloaded_track.dart';
import 'package:vital_up/core/database/collections/meal_log_cache.dart';
import 'package:vital_up/core/database/collections/barcode_cache.dart';
import 'package:vital_up/core/database/collections/offline_food.dart';
import 'package:vital_up/core/database/collections/weight_log_cache.dart';
import 'package:vital_up/core/utils/input_rules.dart';

class IsarService {
  late final Isar isar;

  /// Every collection; background isolates must open Isar with the same list.
  static const schemas = [
    UserProfileCacheSchema,
    StepLogCacheSchema,
    HeartRateLogCacheSchema,
    SleepLogCacheSchema,
    WaterLogCacheSchema,
    MealPlanModelSchema,
    FavoriteAudioSchema,
    DownloadedTrackSchema,
    MealLogCacheSchema,
    BarcodeCacheSchema,
    OfflineFoodSchema,
    WeightLogCacheSchema,
  ];

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();

    // Reuse an already-open instance (hot restart, a second init call).
    isar = Isar.getInstance() ?? await Isar.open(schemas, directory: dir.path);

    await _seedOfflineFoods();
  }

  /// Deletes everything personal: logs, profile, meal plans, saved audio.
  /// Shared reference data (offline foods, barcode lookups) is kept.
  Future<void> clearUserData() => isar.writeTxn(() async {
    await isar.userProfileCaches.clear();
    await isar.stepLogCaches.clear();
    await isar.heartRateLogCaches.clear();
    await isar.sleepLogCaches.clear();
    await isar.waterLogCaches.clear();
    await isar.mealPlanModels.clear();
    await isar.favoriteAudios.clear();
    await isar.downloadedTracks.clear();
    await isar.mealLogCaches.clear();
    await isar.weightLogCaches.clear();
  });

  Future<void> _seedOfflineFoods() async {
    try {
      final count = await isar.offlineFoods.count();
      if (count > 0) {
        return; // already seeded
      }

      final jsonString = await rootBundle.loadString(
        'assets/data/popular_indian_foods.json',
      );
      final List<dynamic> list = jsonDecode(jsonString) as List<dynamic>;

      final List<OfflineFood> foods = [
        for (final item in list)
          if (item is Map)
            ?_food(
              name: item['name'],
              servingSize: item['servingSize'],
              calories: item['calories'],
              protein: item['protein'],
              carbs: item['carbs'],
              fat: item['fat'],
              fiber: item['fiber'],
              sugar: item['sugar'],
              sodium: item['sodium'],
            ),
      ];

      await isar.writeTxn(() async {
        await isar.offlineFoods.putAll(foods);
      });

      debugPrint(
        'Seeded ${foods.length} popular Indian food items into Isar offline database.',
      );
    } catch (e) {
      debugPrint('Error seeding offline foods: $e');
    }
  }

  static const _keyFoodsSyncedAt = 'offline_foods_synced_at';

  /// Shared reference data changes slowly; refresh it at most daily.
  static const _foodsRefreshEvery = Duration(days: 1);

  Future<void> syncOfflineFoodsBackground(
    SupabaseClient supabase,
    SharedPreferences prefs,
  ) async {
    final last = prefs.getInt(_keyFoodsSyncedAt);
    if (last != null &&
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(last)) <
            _foodsRefreshEvery) {
      return;
    }
    // Run asynchronously to not block UI/app startup
    Future.microtask(() async {
      try {
        debugPrint('IsarService: Starting background offline food sync...');

        // Fetch top 100 recently updated/added proprietary products
        final response = await supabase
            .from('proprietary_products')
            .select()
            .order('updated_at', ascending: false)
            .limit(100);

        final List<dynamic> products = response;
        await prefs.setInt(
          _keyFoodsSyncedAt,
          DateTime.now().millisecondsSinceEpoch,
        );
        if (products.isEmpty) {
          return;
        }

        // Get existing names to avoid duplicating (names only, not rows).
        final existingNames = (await isar.offlineFoods
                .where()
                .nameProperty()
                .findAll())
            .map((n) => n.toLowerCase())
            .toSet();

        final List<OfflineFood> newFoods = [];
        for (final item in products) {
          if (item is! Map) continue;
          final food = _food(
            name: item['product_name'],
            servingSize: item['serving_size'],
            calories: item['calories'],
            protein: item['protein_g'],
            carbs: item['carbs_g'],
            fat: item['fat_g'],
            fiber: item['fiber_g'],
            sugar: item['sugar_g'],
            sodium: item['sodium_mg'],
          );
          // Skip bad rows and ones already in the offline database.
          if (food == null || !existingNames.add(food.name.toLowerCase())) {
            continue;
          }
          newFoods.add(food);
        }

        if (newFoods.isNotEmpty) {
          await isar.writeTxn(() async {
            await isar.offlineFoods.putAll(newFoods);
          });
          debugPrint(
            'IsarService: Background sync completed. Added ${newFoods.length} new items from remote DB.',
          );
        } else {
          debugPrint(
            'IsarService: Background sync completed. No new items to add.',
          );
        }
      } catch (e) {
        // Silently catch and log to prevent crashes if connection fails
        debugPrint('IsarService: Background sync failed: $e');
      }
    });
  }

  /// A food from loosely typed JSON, or null when it has no usable name.
  /// Text is cleaned and capped; nutrients must be finite and non-negative.
  static OfflineFood? _food({
    required Object? name,
    required Object? servingSize,
    required Object? calories,
    required Object? protein,
    required Object? carbs,
    required Object? fat,
    required Object? fiber,
    required Object? sugar,
    required Object? sodium,
  }) {
    final cleanName = name is String
        ? sanitizeText(name, maxLength: InputLimits.shortText)
        : '';
    if (cleanName.isEmpty) return null;
    final serving = servingSize is String
        ? sanitizeText(servingSize, maxLength: InputLimits.shortText)
        : '';
    return OfflineFood()
      ..name = cleanName
      ..servingSize = serving.isEmpty ? '100g' : serving
      ..calories = _amount(calories)
      ..proteinG = _amount(protein)
      ..carbsG = _amount(carbs)
      ..fatG = _amount(fat)
      ..fiberG = _amount(fiber)
      ..sugarG = _amount(sugar)
      ..sodiumMg = _amount(sodium);
  }

  static double _amount(Object? value) {
    final v = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    if (v == null || !v.isFinite || v < 0) return 0;
    return v > 100000 ? 100000 : v;
  }
}
