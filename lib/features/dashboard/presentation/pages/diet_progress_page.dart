import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/features/dashboard/data/services/trends_service.dart';
import 'package:vital_up/features/dashboard/domain/entities/diet_progress.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/trend_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/trend_widgets.dart';
import 'package:vital_up/features/diet_plan/presentation/cubit/diet_plan_cubit.dart';
import 'package:vital_up/features/diet_plan/presentation/cubit/diet_plan_state.dart';
import 'package:vital_up/features/food_scanner/domain/entities/meal_log_entry.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_bloc.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_event.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_state.dart';

/// Diet plan progress: calories per day vs the plan, today's planned meals
/// against what was logged, and the meal log.
class DietProgressPage extends StatelessWidget {
  const DietProgressPage({super.key});

  static String formatKcal(double v) => '${v.round()} kcal';

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<DietPlanCubit>()..loadActiveMealPlan()),
        BlocProvider(
          create: (_) => sl<MealLogBloc>()..add(const LoadTodaysMeals()),
        ),
        BlocProvider(
          create: (_) =>
              TrendCubit<MealLogEntry>(sl<TrendsService>().calories)..load(),
        ),
      ],
      child: TrendDetailScaffold<MealLogEntry>(
        title: 'Diet Plan Progress',
        color: AppColors.primary,
        format: formatKcal,
        logsTitle: 'Meals logged',
        emptyLogs: 'No meals logged in this period yet.',
        bottomBar: Builder(
          builder: (context) => Row(
            children: [
              Expanded(
                child: AppSecondaryButton(
                  label: 'View full plan',
                  onTap: () => context.pushNamed(
                    'diet-plan-result',
                    extra: {'mode': 'cached'},
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.cardGap),
              Expanded(
                child: AppPrimaryButton(
                  label: 'Create new plan',
                  onTap: () => context.pushNamed('diet-plan-prefs'),
                ),
              ),
            ],
          ),
        ),
        header: (context, _) => const _TodayVsPlan(),
        logBuilder: (context, meal) => TrendLogTile(
          icon: Icons.restaurant_rounded,
          color: AppColors.primary,
          title: meal.items.isEmpty
              ? _mealTypeLabel(meal.mealType)
              : meal.items.map((i) => i.name).join(', '),
          subtitle:
              '${_mealTypeLabel(meal.mealType)} · ${DateFormat('EEE d MMM, h:mm a').format(meal.capturedAt)}',
          trailing: formatKcal(meal.totalCalories),
        ),
      ),
    );
  }
}

String _mealTypeLabel(MealType type) => switch (type) {
      MealType.breakfast => 'Breakfast',
      MealType.lunch => 'Lunch',
      MealType.dinner => 'Dinner',
      MealType.snack => 'Snack',
    };

/// Today's planned meals with a logged / not yet tick each.
class _TodayVsPlan extends StatelessWidget {
  const _TodayVsPlan();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DietPlanCubit, DietPlanState>(
      builder: (context, planState) {
        return BlocBuilder<MealLogBloc, MealLogState>(
          builder: (context, logState) {
            if (planState is! DietPlanLoaded || logState is! MealLogLoaded) {
              return const SizedBox.shrink();
            }
            final plan = planState.mealPlan;
            final statuses = plannedMealStatuses(plan, logState.entries);
            final done = statuses.where((s) => s.logged).length;
            final v = context.vColors;
            return AppCard(
              width: double.infinity,
              padding: AppDimens.cardPaddingCompact,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(child: AppCaption("Today's plan")),
                      Text(
                        '$done of ${statuses.length} meals',
                        style: context.text.labelSmall
                            ?.copyWith(color: v.grayText),
                      ),
                      const SizedBox(width: AppDimens.space8),
                      CardLink(
                        label: 'Edit',
                        onTap: () async {
                          final plan = context.read<DietPlanCubit>();
                          final calories =
                              context.read<TrendCubit<MealLogEntry>>();
                          final saved =
                              await context.pushNamed<bool>('diet-plan-edit');
                          if (saved == true) {
                            plan.loadActiveMealPlan();
                            calories.load();
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.space8),
                  Text(
                    '${logState.totalCalories.round()} / ${plan.totalCalories} kcal eaten',
                    style: context.text.titleMedium,
                  ),
                  const SizedBox(height: AppDimens.space12),
                  for (final s in statuses)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppDimens.space8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            s.logged
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: AppDimens.iconMd,
                            color: s.logged ? v.success : v.grayText,
                          ),
                          const SizedBox(width: AppDimens.space8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.meal.name, style: context.text.titleSmall),
                                Text(
                                  s.meal.items.join(', '),
                                  style: context.text.bodySmall
                                      ?.copyWith(color: v.grayText),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppDimens.space8),
                          Text(
                            '${s.meal.calories} kcal',
                            style: context.text.bodySmall,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
