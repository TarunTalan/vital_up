import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/app_card.dart';
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

  /// Starts the diet plan flow (shown when there's no plan).
  final VoidCallback? onCreatePlan;

  const NutritionSummaryCard({
    super.key,
    this.onViewAll,
    this.onScanMeal,
    this.plan,
    this.onOpenProgress,
    this.onCreatePlan,
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
      title: plan != null ? 'Diet plan' : null,
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
        if (plan == null && onCreatePlan != null)
          TrackerQuickAction(
            label: 'Get a plan',
            icon: Icons.auto_awesome_rounded,
            color: _metric.color,
            onTap: onCreatePlan,
          )
        else
          TrackerQuickAction(
            label: 'History',
            icon: Icons.history_rounded,
            color: _metric.color,
            onTap: onViewAll,
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              TrackerRing(
                size: context.w(AppDimens.calorieRing),
                fraction: goal == null || goal <= 0 ? null : kcal / goal,
                color: _metric.color,
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${kcal.round()}',
                      style: context.text.titleSmall?.copyWith(
                        color: context.colors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'kcal',
                      style: context.text.labelSmall?.copyWith(
                        color: context.vColors.grayText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimens.space20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MacroBar(
                      label: 'Protein',
                      value: state.totalProteinG,
                      maxValue: targets.protein,
                      color: AppColors.protein,
                    ),
                    const SizedBox(height: AppDimens.space8),
                    MacroBar(
                      label: 'Carbs',
                      value: state.totalCarbsG,
                      maxValue: targets.carbs,
                      color: AppColors.carbs,
                    ),
                    const SizedBox(height: AppDimens.space8),
                    MacroBar(
                      label: 'Fat',
                      value: state.totalFatG,
                      maxValue: targets.fat,
                      color: AppColors.fat,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.space8),
          Text(
            left == null
                ? 'Set a calorie goal to track against it.'
                : left >= 0
                ? '${left.round()} kcal left of ${goal!.round()}'
                : '${(-left).round()} kcal over your ${goal!.round()} goal',
            style: context.text.bodySmall?.copyWith(
              color: context.vColors.grayText,
            ),
          ),
          const SizedBox(height: AppDimens.cardInnerGap),
          if (plan != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in plannedMealStatuses(plan, state.entries))
                  Expanded(
                    child: _MealSlot(
                      mealType: s.type ?? MealType.snack,
                      label: s.meal.name,
                      caption: '${s.meal.calories} kcal',
                      logged: s.logged,
                      onTap: s.logged ? null : onScanMeal,
                    ),
                  ),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final type in MealType.values)
                  Expanded(
                    child: _MealSlot(
                      mealType: type,
                      logged: state.loggedMealTypes.contains(type),
                      onTap: state.loggedMealTypes.contains(type)
                          ? null
                          : onScanMeal,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Labelled macro progress bar ("Protein 64g").
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
    final progress = maxValue > 0 ? (value / maxValue).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall?.copyWith(
                  color: context.vColors.grayText,
                ),
              ),
            ),
            Text(
              '${value.round()} / ${maxValue.round()}g',
              style: context.text.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.colors.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.space4),
        AppProgressBar(
          value: progress,
          color: color,
          trackColor: color.withValues(alpha: AppDimens.tintAlpha),
          height: AppDimens.space6,
        ),
      ],
    );
  }
}

/// One meal slot: icon, name, optional kcal, logged tick or add.
class _MealSlot extends StatelessWidget {
  final MealType mealType;
  final bool logged;
  final VoidCallback? onTap;
  final String? label;
  final String? caption;

  const _MealSlot({
    required this.mealType,
    required this.logged,
    this.onTap,
    this.label,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _metric.color;
    final v = context.vColors;
    final name = label ?? mealTypeLabel(mealType);
    return Semantics(
      button: onTap != null,
      label: '$name, ${logged ? 'logged' : 'not logged'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppDimens.space4),
          child: Column(
            children: [
              AnimatedContainer(
                duration: AppDurations.fast,
                width: AppDimens.iconBadge,
                height: AppDimens.iconBadge,
                decoration: BoxDecoration(
                  color: logged ? v.primaryTint : v.glassFill,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: logged ? accent : v.glassBorder!,
                    width: AppDimens.borderThin,
                  ),
                ),
                child: Icon(
                  logged ? Icons.check_rounded : mealTypeIcon(mealType),
                  size: AppDimens.iconMd,
                  color: logged ? accent : v.grayText,
                ),
              ),
              const SizedBox(height: AppDimens.space4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  name,
                  maxLines: 1,
                  style: context.text.labelSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: logged ? accent : v.grayText,
                  ),
                ),
              ),
              if (caption != null)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    caption!,
                    maxLines: 1,
                    style: context.text.labelSmall?.copyWith(color: v.grayText),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
