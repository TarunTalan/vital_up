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
) {
  // A plan or goal of 0 (missing from the server, an emptied plan) counts
  // as none, so bars never read "68 / 0g".
  double? positive(num? v) => v != null && v > 0 ? v.toDouble() : null;
  final goal = positive(calorieGoal);
  return (
    protein:
        positive(plan?.totalProtein) ?? (goal != null ? goal * 0.3 / 4 : 120),
    carbs: positive(plan?.totalCarbs) ?? (goal != null ? goal * 0.5 / 4 : 250),
    fat: positive(plan?.totalFat) ?? (goal != null ? goal * 0.2 / 9 : 65),
  );
}

/// Today's calorie goal: the plan's total, else the profile's daily goal;
/// null when neither is above 0 ("of 0 kcal" is no goal).
double? calorieGoalFor(MealPlan? plan, int? dailyCalorieGoal) {
  final planned = plan?.totalCalories;
  if (planned != null && planned > 0) return planned.toDouble();
  return dailyCalorieGoal != null && dailyCalorieGoal > 0
      ? dailyCalorieGoal.toDouble()
      : null;
}

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
    final goal = calorieGoalFor(plan, state.dailyCalorieGoal);
    final kcal = state.totalCalories;
    final targets = macroTargets(plan, state.dailyCalorieGoal);
    // Rounded first, so a few tenths over never reads "0 kcal over".
    final left = goal == null ? null : (goal - kcal).roundToDouble();
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
          svgAsset: _metric.logIconAsset,
          color: _metric.color,
          filled: true,
          onTap: onScanMeal,
        ),
        TrackerQuickAction(
          label: plan != null ? 'Diet plan' : 'Get a plan',
          svgAsset: TrackerIcons.plan,
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
    final planned = plan == null
        ? const <PlannedMealStatus>[]
        : plannedMealStatuses(plan, state.entries);
    // A plan without meals counts meals like no plan ("0 of 0" says nothing).
    if (planned.isNotEmpty) {
      final done = planned.where((m) => m.logged).length;
      return '$done of ${planned.length} planned meals';
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
