import 'package:vital_up/core/network/api_result.dart';
import 'package:vital_up/core/network/dio_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/features/diet_plan/data/models/meal_plan_model.dart';
import 'package:vital_up/features/diet_plan/data/models/nutrition_target_model.dart';
import 'package:vital_up/features/diet_plan/domain/entities/nutrition_target.dart';

abstract class DietPlanRemoteDataSource {
  Future<ApiResult<MealPlanModel>> generateDietPlan({
    required NutritionTarget target,
    required Map<String, dynamic> preferences,
  });
}

class DietPlanRemoteDataSourceImpl implements DietPlanRemoteDataSource {
  final DioClient _dioClient; // Kept for DI compatibility

  DietPlanRemoteDataSourceImpl(this._dioClient);

  @override
  Future<ApiResult<MealPlanModel>> generateDietPlan({
    required NutritionTarget target,
    required Map<String, dynamic> preferences,
  }) async {
    try {
      final targetModel = NutritionTargetModel.fromEntity(target);
      
      final response = await Supabase.instance.client.functions.invoke(
        'generate-diet-plan',
        body: {
          'target': targetModel.toJson(),
          'preferences': preferences,
        },
      );

      if (response.status == 200) {
        final dateKey = DateTime.now().toIso8601String().split('T')[0];
        final model = MealPlanModel.fromJson(response.data as Map<String, dynamic>, dateKey);
        return ApiSuccess(model);
      } else {
        return ApiError(
          message: response.data?['error']?.toString() ?? 'Server error', 
          code: response.status ?? 500
        );
      }
    } on FunctionException catch (e) {
      final errorMsg = e.details?['error']?.toString() ?? e.reasonPhrase ?? 'Edge Function error';
      return ApiError(message: errorMsg, code: e.status ?? 500);
    } catch (e) {
      final err = ResponseHandler.fromException(e) as ApiError;
      return ApiError(message: err.message, code: err.code);
    }
  }
}
