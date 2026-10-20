import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/number_formats.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_sheet.dart';
import 'package:vital_up/core/widgets/tracker/tracker_widgets.dart';
import 'package:vital_up/features/diet_plan/domain/entities/meal_plan.dart';
import 'package:vital_up/features/diet_plan/presentation/cubit/diet_plan_cubit.dart';

/// "2 other options ›" under a meal: opens [showMealAlternativesSheet].
/// Nothing is shown when the meal has no alternatives (older plans).
class MealAlternativesLink extends StatelessWidget {
  final Meal meal;
  final VoidCallback onTap;

  const MealAlternativesLink({
    super.key,
    required this.meal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final count = meal.alternatives.length;
    if (count == 0) return const SizedBox.shrink();
    final accent = context.vColors.accentText;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: accent,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.space8,
            vertical: AppDimens.space4,
          ),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.swap_horiz_rounded, size: AppDimens.iconSm),
            const SizedBox(width: AppDimens.space4),
            Flexible(
              child: Text(
                '$count other option${count == 1 ? '' : 's'}',
                style: context.text.labelLarge?.copyWith(color: accent),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: AppDimens.iconMd),
          ],
        ),
      ),
    );
  }
}

/// The meal's dish and its alternatives; pops the chosen alternative's
/// index, or null when the user keeps the dish.
Future<int?> showMealAlternativesSheet(BuildContext context, Meal meal) {
  return showAppBottomSheet<int>(
    context: context,
    builder: (_) => _AlternativesSheet(meal: meal),
  );
}

/// Opens the sheet for meal [mealIndex] of the plan in [cubit] and swaps
/// the chosen dish in. With [save] (the active plan) the change is stored
/// at once.
Future<void> pickMealAlternative(
  BuildContext context,
  DietPlanCubit cubit,
  MealPlan plan,
  int mealIndex, {
  required bool save,
}) async {
  final meal = plan.meals[mealIndex];
  final option = await showMealAlternativesSheet(context, meal);
  if (option == null || !context.mounted) return;
  final done = await cubit.chooseAlternative(mealIndex, option, save: save);
  if (!context.mounted) return;
  if (done) {
    showSuccessSnackBar(context, '${meal.name} updated.');
  } else {
    showErrorSnackBar(context, "Couldn't change ${meal.name}. Try again.");
  }
}

class _AlternativesSheet extends StatelessWidget {
  final Meal meal;

  const _AlternativesSheet({required this.meal});

  @override
  Widget build(BuildContext context) {
    final current = meal.dish;
    return TrackerSheet(
      metric: TrackerMetric.nutrition,
      title: 'Other options',
      subtitle: meal.name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _OptionCard(option: current, current: current, isCurrent: true),
          for (var i = 0; i < meal.alternatives.length; i++) ...[
            const SizedBox(height: AppDimens.cardGap),
            _OptionCard(
              option: meal.alternatives[i],
              current: current,
              onUse: () => Navigator.pop(context, i),
            ),
          ],
        ],
      ),
    );
  }
}

/// One dish: its foods, then kcal, protein and how it compares with the
/// current dish. The current one is highlighted and has no button.
class _OptionCard extends StatelessWidget {
  final MealOption option;
  final MealOption current;
  final bool isCurrent;
  final VoidCallback? onUse;

  const _OptionCard({
    required this.option,
    required this.current,
    this.isCurrent = false,
    this.onUse,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = context.colors.onSurface;
    final change = option.calories - current.calories;
    final onUse = this.onUse;
    return AppCard(
      highlighted: isCurrent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isCurrent) ...[
            Text(
              'In your plan',
              style: context.text.bodySmall?.copyWith(
                color: context.vColors.grayText,
              ),
            ),
            const SizedBox(height: AppDimens.space4),
          ],
          for (final item in option.items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimens.space4),
              child: Text(
                item,
                style: context.text.bodyMedium?.copyWith(color: onSurface),
              ),
            ),
          const SizedBox(height: AppDimens.space4),
          TrackerSummaryLine(
            parts: [
              '${formatCount(option.calories)} kcal',
              '${option.protein} g protein',
              if (!isCurrent)
                change == 0
                    ? 'Same calories'
                    : '${formatCount(change.abs())} kcal '
                          '${change > 0 ? 'more' : 'less'}',
            ],
          ),
          if (onUse != null) ...[
            const SizedBox(height: AppDimens.space12),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: AppSecondaryButton(
                label: 'Use',
                expand: false,
                onTap: onUse,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
