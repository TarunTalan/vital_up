import 'dart:convert';

import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/database/isar_service.dart';
import 'package:vital_up/core/network/api_result.dart';
import 'package:vital_up/features/diet_plan/data/datasources/diet_plan_remote_datasource.dart';
import 'package:vital_up/features/diet_plan/data/models/meal_plan_model.dart';
import 'package:vital_up/features/diet_plan/domain/entities/meal_plan.dart';
import 'package:vital_up/features/diet_plan/domain/entities/nutrition_target.dart';
import 'package:vital_up/features/diet_plan/domain/repositories/diet_plan_repository.dart';

class DietPlanRepositoryImpl implements DietPlanRepository {
  final DietPlanRemoteDataSource remoteDataSource;
  final IsarService isarService;
  final SharedPreferences prefs;

  /// Isar dateKey of the plan in use, and its prefs key (also backed up,
  /// see DietPlanBackupSource).
  static const activePlanKey = 'active_plan';
  static const preferencesKey = 'active_plan_preferences';

  DietPlanRepositoryImpl({
    required this.remoteDataSource,
    required this.isarService,
    required this.prefs,
  });

  @override
  Future<ApiResult<MealPlan>> generateMealPlan({
    required NutritionTarget target,
    required Map<String, dynamic> preferences,
    String? instructions,
    MealPlan? basePlan,
  }) async {
    final result = await remoteDataSource.generateDietPlan(
      target: target,
      preferences: preferences,
      instructions: instructions,
      basePlan: basePlan,
    );

    if (result is ApiSuccess<MealPlanModel>) {
      return ApiSuccess(result.data.toEntity());
    } else if (result is ApiError<MealPlanModel>) {
      return ApiError(message: result.message, code: result.code);
    }
    return const ApiError(message: 'Unknown error', code: -1);
  }

  @override
  Future<MealPlan?> getActiveMealPlan() async {
    final isar = isarService.isar;
    final cached = await isar.mealPlanModels.where().dateKeyEqualTo(activePlanKey).findFirst();
    return cached?.toEntity();
  }

  @override
  Future<void> setActiveMealPlan(
    MealPlan plan, {
    Map<String, dynamic> preferences = const {},
  }) async {
    final isar = isarService.isar;
    final model = MealPlanModel.fromEntity(plan, activePlanKey);
    await isar.writeTxn(() async {
      await isar.mealPlanModels.put(model);
    });
    await prefs.setString(preferencesKey, jsonEncode(preferences));
  }

  @override
  Future<Map<String, dynamic>> getActivePlanPreferences() async {
    final raw = prefs.getString(preferencesKey);
    if (raw == null) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }
}
