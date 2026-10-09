import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/network/api_result.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import 'package:vital_up/features/diet_plan/domain/entities/meal_plan.dart';
import 'package:vital_up/features/diet_plan/domain/entities/nutrition_target.dart';
import 'package:vital_up/features/diet_plan/domain/usecases/generate_meal_plan.dart';
import 'package:vital_up/features/diet_plan/domain/usecases/get_active_meal_plan.dart';
import 'package:vital_up/features/diet_plan/domain/usecases/set_active_meal_plan.dart';
import 'diet_plan_state.dart';

class DietPlanCubit extends Cubit<DietPlanState> {
  final GenerateMealPlan _generateMealPlan;
  final GetActiveMealPlan _getActiveMealPlan;
  final SetActiveMealPlan _setActiveMealPlan;

  DietPlanCubit({
    required GenerateMealPlan generateMealPlan,
    required GetActiveMealPlan getActiveMealPlan,
    required SetActiveMealPlan setActiveMealPlan,
  })  : _generateMealPlan = generateMealPlan,
        _getActiveMealPlan = getActiveMealPlan,
        _setActiveMealPlan = setActiveMealPlan,
        super(DietPlanInitial());

  Future<void> loadActiveMealPlan() async {
    emit(DietPlanLoading());
    // A failed or slow local read falls back to "no plan" (generate CTA).
    final cached = await _getActiveMealPlan().orFallback(null, kLoadTimeout);
    if (isClosed) return;
    if (cached != null) {
      emit(DietPlanLoaded(cached));
    } else {
      emit(DietPlanInitial());
    }
  }

  Future<void> generatePlan({
    required NutritionTarget target,
    required Map<String, dynamic> preferences,
    String? instructions,
    MealPlan? basePlan,
  }) async {
    // One generation at a time: each one uses the daily AI quota.
    if (state is DietPlanLoading) return;
    emit(DietPlanLoading());
    final ApiResult<MealPlan> result;
    try {
      result = await _generateMealPlan(
        target: target,
        preferences: preferences,
        instructions: instructions,
        basePlan: basePlan,
      );
    } catch (e) {
      addError(e);
      if (!isClosed) emit(DietPlanError(userMessage(e, fallback: "Couldn't create your plan. Try again.")));
      return;
    }
    // The page may have been closed while the plan was generating.
    if (isClosed) return;

    if (result is ApiSuccess<MealPlan>) {
      emit(DietPlanLoaded(result.data));
    } else if (result is ApiError<MealPlan>) {
      emit(DietPlanError(result.message));
    }
  }

  /// Surfaces a failure that happened before generation (e.g. target maths).
  void showError(String message) {
    if (!isClosed) emit(DietPlanError(message));
  }

  /// Saves [plan] as the active plan. False when it couldn't be stored.
  Future<bool> saveActivePlan(
    MealPlan plan, {
    Map<String, dynamic> preferences = const {},
  }) async {
    try {
      await _setActiveMealPlan(plan, preferences: preferences);
      return true;
    } catch (e) {
      addError(e);
      return false;
    }
  }
}
