import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
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

class IsarService {
  late final Isar isar;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    
    isar = await Isar.open(
      [
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
      ],
      directory: dir.path,
    );

    await _seedOfflineFoods();
  }

  Future<void> _seedOfflineFoods() async {
    try {
      final count = await isar.offlineFoods.count();
      if (count > 0) {
        return; // already seeded
      }

      final jsonString = await rootBundle.loadString('assets/data/popular_indian_foods.json');
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

      print('Seeded ${foods.length} popular Indian food items into Isar offline database.');
    } catch (e) {
      print('Error seeding offline foods: $e');
    }
  }

  Future<void> syncOfflineFoodsBackground(SupabaseClient supabase) async {
    // Run asynchronously to not block UI/app startup
    Future.microtask(() async {
      try {
        print('IsarService: Starting background offline food sync...');

        // Fetch top 100 recently updated/added proprietary products
        final response = await supabase
            .from('proprietary_products')
            .select()
            .order('updated_at', ascending: false)
            .limit(100);

        if (response == null || response is! List) {
          print('IsarService: No proprietary products found to sync.');
          return;
        }

        final List<dynamic> products = response;
        if (products.isEmpty) {
          return;
        }

        // Get existing names to avoid duplicating
        final existingFoods = await isar.offlineFoods.where().findAll();
        final existingNames = existingFoods.map((f) => f.name.toLowerCase()).toSet();

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
          print('IsarService: Background sync completed. Added ${newFoods.length} new items from remote DB.');
        } else {
          print('IsarService: Background sync completed. No new items to add.');
        }
      } catch (e) {
        // Silently catch and log to prevent crashes if connection fails
        print('IsarService: Background sync failed: $e');
      }
    });
  }
}

