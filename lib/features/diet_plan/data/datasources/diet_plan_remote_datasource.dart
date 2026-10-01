import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:vital_up/core/network/api_result.dart';
import 'package:vital_up/core/network/dio_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/features/diet_plan/data/models/meal_plan_model.dart';
import 'package:vital_up/features/diet_plan/data/models/nutrition_target_model.dart';
import 'package:vital_up/features/diet_plan/domain/entities/meal_plan.dart';
import 'package:vital_up/features/diet_plan/domain/entities/nutrition_target.dart';

abstract class DietPlanRemoteDataSource {
  /// With [instructions], the function tweaks [basePlan] instead of
  /// generating a fresh plan.
  Future<ApiResult<MealPlanModel>> generateDietPlan({
    required NutritionTarget target,
    required Map<String, dynamic> preferences,
    String? instructions,
    MealPlan? basePlan,
  });
}

class DietPlanRemoteDataSourceImpl implements DietPlanRemoteDataSource {
  // ignore: unused_field
  final DioClient _dioClient; // Kept for DI compatibility

  DietPlanRemoteDataSourceImpl(this._dioClient);

  /// The edge function retries internally (two attempts, each with a
  /// provider fallback), so allow for the worst case before giving up.
  static const Duration _timeout = Duration(seconds: 75);

  @override
  Future<ApiResult<MealPlanModel>> generateDietPlan({
    required NutritionTarget target,
    required Map<String, dynamic> preferences,
    String? instructions,
    MealPlan? basePlan,
  }) async {
    try {
      if (Supabase.instance.client.auth.currentSession == null) {
        return const ApiError(message: 'Please sign in to generate a diet plan.', code: 401);
      }
      // An access token that expired while the app sat in the background is
      // rejected by the function; refresh it first.
      if (Supabase.instance.client.auth.currentSession?.isExpired ?? false) {
        await Supabase.instance.client.auth.refreshSession();
      }

      final targetModel = NutritionTargetModel.fromEntity(target);
      // functions.invoke attaches the signed-in user's access token itself.
      final response = await Supabase.instance.client.functions.invoke(
        'generate-diet-plan',
        body: {
          'target': targetModel.toJson(),
          'preferences': preferences,
          'instructions': ?instructions,
          if (instructions != null && basePlan != null)
            'basePlan': {
              'meals': [
                for (final m in basePlan.meals)
                  {'name': m.name, 'items': m.items, 'calories': m.calories},
              ],
            },
        },
      ).timeout(_timeout);

      final data = response.data is String ? jsonDecode(response.data as String) : response.data;
      final dateKey = DateTime.now().toIso8601String().split('T')[0];
      return ApiSuccess(MealPlanModel.fromJson(data as Map<String, dynamic>, dateKey));
    } on FunctionException catch (e) {
      debugPrint('generate-diet-plan failed: status=${e.status} details=${e.details}');
      return ApiError(message: _messageForStatus(e.status), code: e.status);
    } on TimeoutException {
      return const ApiError(
        message: 'Generating your plan is taking too long. Please try again.',
        code: 408,
      );
    } catch (e) {
      debugPrint('Unexpected error [generateDietPlan]: $e');
      final err = ResponseHandler.fromException(e) as ApiError;
      return ApiError(message: err.message, code: err.code);
    }
  }

  String _messageForStatus(int status) {
    switch (status) {
      case 401:
        return 'Your session has expired. Please sign in again.';
      case 429:
        return "You've reached today's diet plan limit. Please try again tomorrow.";
      case 422:
        return 'We couldn\'t build a plan that fits your preferences. Please try again.';
      default:
        return 'Unable to generate diet plan. Please try again later.';
    }
  }
}
