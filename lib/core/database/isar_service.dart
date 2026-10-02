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

    isar = await Isar.open(schemas, directory: dir.path);

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

      final List<OfflineFood> foods = list.map((item) {
        final Map<String, dynamic> map = item as Map<String, dynamic>;
        return OfflineFood()
          ..name = map['name'] as String
          ..servingSize = map['servingSize'] as String? ?? '100g'
          ..calories = (map['calories'] as num?)?.toDouble() ?? 0.0
          ..proteinG = (map['protein'] as num?)?.toDouble() ?? 0.0
          ..carbsG = (map['carbs'] as num?)?.toDouble() ?? 0.0
          ..fatG = (map['fat'] as num?)?.toDouble() ?? 0.0
          ..fiberG = (map['fiber'] as num?)?.toDouble() ?? 0.0
          ..sugarG = (map['sugar'] as num?)?.toDouble() ?? 0.0
          ..sodiumMg = (map['sodium'] as num?)?.toDouble() ?? 0.0;
      }).toList();

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
          final name = item['product_name'] as String?;
          if (name == null || name.isEmpty) continue;

          // Skip if already in the offline database
          if (existingNames.contains(name.toLowerCase())) {
            continue;
          }

          final food = OfflineFood()
            ..name = name
            ..servingSize = item['serving_size'] as String? ?? '100g'
            ..calories = (item['calories'] as num?)?.toDouble() ?? 0.0
            ..proteinG = (item['protein_g'] as num?)?.toDouble() ?? 0.0
            ..carbsG = (item['carbs_g'] as num?)?.toDouble() ?? 0.0
            ..fatG = (item['fat_g'] as num?)?.toDouble() ?? 0.0
            ..fiberG = (item['fiber_g'] as num?)?.toDouble() ?? 0.0
            ..sugarG = (item['sugar_g'] as num?)?.toDouble() ?? 0.0
            ..sodiumMg = (item['sodium_mg'] as num?)?.toDouble() ?? 0.0;

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
}
