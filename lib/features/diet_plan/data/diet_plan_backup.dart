import 'dart:convert';

import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/database/isar_service.dart';
import 'package:vital_up/core/sync/backup_sync.dart';
import 'package:vital_up/features/diet_plan/data/models/meal_plan_model.dart';
import 'package:vital_up/features/diet_plan/data/repositories/diet_plan_repository_impl.dart';

/// Backs up the active diet plan (Isar) and the preferences it was made
/// with, so a new phone doesn't have to regenerate it.
class DietPlanBackupSource implements BackupSource {
  final IsarService _isar;
  final SharedPreferences _prefs;

  DietPlanBackupSource(this._isar, this._prefs);

  @override
  String get kind => 'diet_plan';

  @override
  Future<Object?> export(String userId) async {
    final plan = await _isar.isar.mealPlanModels
        .where()
        .dateKeyEqualTo(DietPlanRepositoryImpl.activePlanKey)
        .findFirst();
    final prefs = _prefs.getString(DietPlanRepositoryImpl.preferencesKey);
    return {
      'plan': plan?.toJson(),
      'preferences': prefs == null ? null : jsonDecode(prefs),
    };
  }

  @override
  Future<void> restore(String userId, Object? data) async {
    if (data is! Map) return;
    final plan = data['plan'];
    final isar = _isar.isar;
    await isar.writeTxn(() async {
      if (plan is Map) {
        // dateKey is a unique replacing index: this overwrites the old plan.
        await isar.mealPlanModels.put(
          MealPlanModel.fromJson(
            Map<String, dynamic>.from(plan),
            DietPlanRepositoryImpl.activePlanKey,
          ),
        );
      } else {
        await isar.mealPlanModels
            .where()
            .dateKeyEqualTo(DietPlanRepositoryImpl.activePlanKey)
            .deleteAll();
      }
    });
    final preferences = data['preferences'];
    if (preferences == null) {
      await _prefs.remove(DietPlanRepositoryImpl.preferencesKey);
    } else {
      await _prefs.setString(
        DietPlanRepositoryImpl.preferencesKey,
        jsonEncode(preferences),
      );
    }
  }
}
