import 'package:isar_community/isar.dart';
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

  DietPlanRepositoryImpl({
    required this.remoteDataSource,
    required this.isarService,
  });

  @override
  Future<ApiResult<MealPlan>> generateMealPlan({
    required NutritionTarget target,
    required Map<String, dynamic> preferences,
  }) async {
    final result = await remoteDataSource.generateDietPlan(
      target: target,
      preferences: preferences,
    );

    if (result is ApiSuccess<MealPlanModel>) {
      final isar = isarService.isar;
      await isar.writeTxn(() async {
        await isar.mealPlanModels.put(result.data);
      });
      return ApiSuccess(result.data.toEntity());
    } else if (result is ApiError<MealPlanModel>) {
      return ApiError(message: result.message, code: result.code);
    }
    return const ApiError(message: 'Unknown error', code: -1);
  }

  @override
  Future<MealPlan?> getCachedMealPlan(String dateKey) async {
    final isar = isarService.isar;
    final cached = await isar.mealPlanModels.where().dateKeyEqualTo(dateKey).findFirst();
    return cached?.toEntity();
  }
}
