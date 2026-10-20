import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_status.dart';
import 'package:vital_up/core/widgets/tracker/tracker_widgets.dart';
import 'package:vital_up/features/dashboard/domain/entities/diet_progress.dart';
import 'package:vital_up/features/dashboard/domain/entities/trend_series.dart';
import 'package:vital_up/features/diet_plan/domain/entities/meal_plan.dart';
import 'package:vital_up/features/food_scanner/domain/entities/meal_log_entry.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_bloc.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_event.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_state.dart';
import 'package:vital_up/core/utils/number_formats.dart';

const _metric = TrackerMetric.nutrition;

IconData mealTypeIcon(MealType type) => switch (type) {
  MealType.breakfast => Icons.free_breakfast_rounded,
  MealType.lunch => Icons.lunch_dining_rounded,
  MealType.dinner => Icons.dinner_dining_rounded,
  MealType.snack => Icons.bakery_dining_rounded,
};

String mealTypeLabel(MealType type) => switch (type) {
  MealType.breakfast => 'Breakfast',
  MealType.lunch => 'Lunch',
  MealType.dinner => 'Dinner',
  MealType.snack => 'Snack',
};

/// Macro targets in grams: from the plan, else split from the calorie goal
/// (30% protein, 50% carbs, 20% fat), else general defaults.
({double protein, double carbs, double fat}) macroTargets(
  MealPlan? plan,
  int? calorieGoal,
) => (
  protein:
      plan?.totalProtein.toDouble() ??
      (calorieGoal != null ? calorieGoal * 0.3 / 4 : 120),
  carbs:
      plan?.totalCarbs.toDouble() ??
      (calorieGoal != null ? calorieGoal * 0.5 / 4 : 250),
  fat:
      plan?.totalFat.toDouble() ??
      (calorieGoal != null ? calorieGoal * 0.2 / 9 : 65),
);

/// Home card: today's calories and macros against the plan (or calorie
/// goal) and which meals are logged. Needs a [MealLogBloc] above it.
class NutritionSummaryCard extends StatelessWidget {
  /// Opens the meal history.
  final VoidCallback? onViewAll;

  /// Opens the food scanner to log a meal.
  final VoidCallback? onScanMeal;

  final MealPlan? plan;

  /// Opens the nutrition detail page.
  final VoidCallback? onOpenProgress;

  /// Opens the active diet plan or generator.
  final VoidCallback? onOpenDietPlan;

  /// Creates a new diet plan.
  final VoidCallback? onCreatePlan;

  const NutritionSummaryCard({
    super.key,
    this.onViewAll,
    this.onScanMeal,
    this.plan,
    this.onOpenProgress,
    this.onCreatePlan,
    this.onOpenDietPlan,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MealLogBloc, MealLogState>(
      builder: (context, state) {
        if (state is MealLogLoaded) return _loaded(context, state);
        return TrackerCardPlaceholder(
          metric: _metric,
          onRetry: state is MealLogError
              ? () => context.read<MealLogBloc>().add(const LoadTodaysMeals())
              : null,
        );
      },
    );
  }

  Widget _loaded(BuildContext context, MealLogLoaded state) {
    final plan = this.plan;
    final goal =
        plan?.totalCalories.toDouble() ?? state.dailyCalorieGoal?.toDouble();
    final kcal = state.totalCalories;
    final targets = macroTargets(plan, state.dailyCalorieGoal);
    final left = goal == null ? null : goal - kcal;
    return TrackerCard(
      metric: _metric,
      status: TrackerStatus.of(
        value: state.entries.isEmpty ? null : kcal,
        goal: goal,
        direction: GoalDirection.near,
      ),
      onOpen: onOpenProgress,
      actions: [
        TrackerQuickAction(
          label: _metric.logLabel,
          icon: _metric.logIcon,
          color: _metric.color,
          filled: true,
          onTap: onScanMeal,
        ),
        TrackerQuickAction(
          label: plan != null ? 'Diet plan' : 'Get a plan',
          svgAsset: 'assets/icons/nav/vita.svg',
          color: _metric.color,
          onTap: plan != null
              ? (onOpenDietPlan ?? onOpenProgress)
              : onCreatePlan,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TrackerHeroLayout(
            ring: TrackerHeroRing(
              fraction: goal == null || goal <= 0 ? null : kcal / goal,
              color: _metric.color,
              value: formatCount(left == null ? kcal : left.abs()),
              caption: left == null
                  ? 'kcal eaten'
                  : left >= 0
                  ? 'kcal left'
                  : 'kcal over',
            ),
            details: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, (label, value, max, color)) in [
                  (
                    'Protein',
                    state.totalProteinG,
                    targets.protein,
                    AppColors.protein,
                  ),
                  ('Carbs', state.totalCarbsG, targets.carbs, AppColors.carbs),
                  ('Fat', state.totalFatG, targets.fat, AppColors.fat),
                ].indexed) ...[
                  if (i > 0) const SizedBox(height: AppDimens.space12),
                  MacroBar(
                    label: label,
                    value: value,
                    maxValue: max,
                    color: color,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppDimens.cardInnerGap),
          TrackerSummaryLine(
            parts: [
              // The ring already shows what's eaten when there's no goal.
              goal == null
                  ? 'No calorie goal'
                  : '${formatCount(kcal)} of ${formatCount(goal)} kcal',
              _mealsLogged(state),
            ],
          ),
        ],
      ),
    );
  }

  /// "2 of 4 meals", or against the plan's meals when there is one.
  String _mealsLogged(MealLogLoaded state) {
    final plan = this.plan;
    if (plan != null) {
      final meals = plannedMealStatuses(plan, state.entries);
      final done = meals.where((m) => m.logged).length;
      return '$done of ${meals.length} planned meals';
    }
    final done = state.loggedMealTypes.length;
    return '$done of ${MealType.values.length} meals';
  }
}

/// Labelled macro progress bar ("Protein ... 68 / 150g").
class MacroBar extends StatelessWidget {
  final String label;
  final double value;
  final double maxValue;
  final Color color;

  const MacroBar({
    super.key,
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TrackerBarRow(
      name: label,
      figure: '${value.round()} / ${maxValue.round()}g',
      fraction: maxValue > 0 ? value / maxValue : 0,
      color: color,
    );
  }
}
