import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:vital_up/core/utils/input_rules.dart';
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
        return const ApiError(message: 'Please sign in to create a plan.', code: 401);
      }
      // An access token that expired while the app sat in the background is
      // rejected by the function; refresh it first.
      if (Supabase.instance.client.auth.currentSession?.isExpired ?? false) {
        try {
          await Supabase.instance.client.auth.refreshSession();
        } catch (e) {
          debugPrint('generate-diet-plan: session refresh failed: $e');
          return ApiError(
            message: userMessage(e, fallback: 'Please sign in again.'),
            code: 401,
          );
        }
      }

      // Typed / chat text reaches the AI only cleaned and length-limited.
      final cleanInstructions = sanitizeOptional(
        instructions,
        maxLength: InputLimits.chatMessage,
        multiline: true,
      );
      final cleanPreferences = <String, dynamic>{
        for (final entry in preferences.entries)
          entry.key: entry.value is String
              ? sanitizeText(entry.value as String, maxLength: InputLimits.note)
              : entry.value,
      };

      final targetModel = NutritionTargetModel.fromEntity(target);
      // functions.invoke attaches the signed-in user's access token itself.
      final response = await Supabase.instance.client.functions.invoke(
        'generate-diet-plan',
        body: {
          'target': targetModel.toJson(),
          'preferences': cleanPreferences,
          'instructions': ?cleanInstructions,
          if (cleanInstructions != null && basePlan != null)
            'basePlan': {
              'meals': [
                for (final m in basePlan.meals)
                  {'name': m.name, 'items': m.items, 'calories': m.calories},
              ],
            },
        },
      ).timeout(_timeout);

      final data = response.data is String ? jsonDecode(response.data as String) : response.data;
      if (data is! Map) {
        debugPrint('generate-diet-plan: unexpected response ${data.runtimeType}');
        return const ApiError(message: _badPlanMessage, code: 502);
      }
      final dateKey = DateTime.now().toIso8601String().split('T')[0];
      final plan = MealPlanModel.fromJson(Map<String, dynamic>.from(data), dateKey);
      // An empty or meal-less answer is a failed generation, not a plan.
      if ((plan.meals ?? const []).isEmpty || (plan.totalCalories ?? 0) <= 0) {
        debugPrint('generate-diet-plan: empty plan in response');
        return const ApiError(message: _badPlanMessage, code: 502);
      }
      return ApiSuccess(plan);
    } on FunctionException catch (e) {
      debugPrint('generate-diet-plan failed: status=${e.status} details=${e.details}');
      return ApiError(message: _messageForStatus(e.status), code: e.status);
    } on TimeoutException {
      return const ApiError(
        message: 'This is taking too long. Try again.',
        code: 408,
      );
    } catch (e) {
      // Never show exception text (FormatException etc.) to the user.
      debugPrint('Unexpected error [generateDietPlan]: $e');
      return ApiError(message: userMessage(e, fallback: _badPlanMessage), code: -1);
    }
  }

  static const _badPlanMessage = "Couldn't create your plan. Try again.";

  String _messageForStatus(int status) {
    switch (status) {
      case 401:
      case 403:
        return 'Please sign in again.';
      case 429:
        return 'No plans left today. Try again tomorrow.';
      case 422:
        return "Couldn't fit a plan to your choices. Try again.";
      default:
        return _badPlanMessage;
    }
  }
}
