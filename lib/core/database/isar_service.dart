import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vital_up/core/database/collections/user_profile_cache.dart';
import 'package:vital_up/core/database/collections/step_log_cache.dart';
import 'package:vital_up/core/database/collections/heart_rate_log_cache.dart';
import 'package:vital_up/core/database/collections/sleep_log_cache.dart';
import 'package:vital_up/core/database/collections/water_log_cache.dart';
import 'package:vital_up/core/database/collections/meal_log_cache.dart';

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
        MealLogCacheSchema,
      ],
      directory: dir.path,
    );
  }
}

