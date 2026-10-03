import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_widgets.dart';
import 'package:vital_up/features/dashboard/data/services/trends_service.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/trend_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/nutrition_summary_card.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/tracker_detail_scaffold.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/tracker_goal_editors.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/tracker_insights.dart';
import 'package:vital_up/features/diet_plan/presentation/cubit/diet_plan_cubit.dart';
import 'package:vital_up/features/diet_plan/presentation/cubit/diet_plan_state.dart';
import 'package:vital_up/features/food_scanner/domain/entities/meal_log_entry.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_bloc.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_event.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_state.dart';
import 'package:vital_up/features/home_widget/home_widget_service.dart';

/// Nutrition: today's calories vs the plan, the daily trend, today's
/// macros and every meal logged.
class DietProgressPage extends StatelessWidget {
  const DietProgressPage({super.key});

  static String formatKcal(double v) =>
      '${NumberFormat.decimalPattern().format(v.round())} kcal';

  @override
  Widget build(BuildContext context) {
    const metric = TrackerMetric.nutrition;
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
      child: Builder(
        builder: (context) {
          final trend = context.read<TrendCubit<MealLogEntry>>();
          final meals = context.read<MealLogBloc>();
          final plan = context.read<DietPlanCubit>();
          Future<void> reload() async {
            meals.add(const LoadTodaysMeals());
            plan.loadActiveMealPlan();
            await trend.load();
            try {
              await sl<HomeWidgetService>().refresh();
            } catch (_) {}
          }

          return TrackerDetailScaffold<MealLogEntry>(
            metric: metric,
            noun: 'your meals',
            format: formatKcal,
            axisFormat: (v) => NumberFormat.compact().format(v.round()),
            goalLabel: (data) => data.series.goal == null
                ? null
                : 'Daily target · ${formatKcal(data.series.goal!)}',
            onEditGoal: () async {
              if (await editNutritionGoal(context)) reload();
            },
            insights: (data) => _mealInsights(data.logs),
            sections: (context, data) => [const _MacrosCard()],
            logsTitle: 'Meals',
            emptyLogs: 'No meals logged in this period yet.',
            logsActionLabel: 'All meals',
            onLogsAction: () => context.pushNamed('meal-log-history'),
            onRefresh: reload,
            onLog: () async {
              await context.pushNamed('food-scan');
              reload();
            },
            logBuilder: (context, meal) => TrackerLogTile(
              id: meal.id,
              icon: mealTypeIcon(meal.mealType),
              color: metric.color,
              title: meal.items.isEmpty
                  ? mealTypeLabel(meal.mealType)
                  : meal.items.map((i) => i.name).join(', '),
              subtitle:
                  '${mealTypeLabel(meal.mealType)} · '
                  '${DateFormat('EEE d MMM, h:mm a').format(meal.capturedAt)}',
              trailing: formatKcal(meal.totalCalories),
            ),
          );
        },
      ),
    );
  }

  /// The meal type that carries the most calories on average.
  static List<TrackerInsight> _mealInsights(List<MealLogEntry> logs) {
    if (logs.length < 3) return const [];
    final total = logs.fold<double>(0, (s, m) => s + m.totalCalories);
    if (total <= 0) return const [];
    final byType = <MealType, double>{};
    for (final m in logs) {
      byType[m.mealType] = (byType[m.mealType] ?? 0) + m.totalCalories;
    }
    final top = byType.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return [
      TrackerInsight(
        mealTypeIcon(top.key),
        '${mealTypeLabel(top.key)} brings ${(top.value / total * 100).round()}% '
        'of your calories in this period.',
      ),
    ];
  }
}

/// Today's macros vs targets, plus fibre, sugar and saturated fat.
class _MacrosCard extends StatelessWidget {
  const _MacrosCard();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DietPlanCubit, DietPlanState>(
      builder: (context, planState) {
        final plan = planState is DietPlanLoaded ? planState.mealPlan : null;
        return BlocBuilder<MealLogBloc, MealLogState>(
          builder: (context, state) {
            if (state is! MealLogLoaded) return const SizedBox.shrink();
            final targets = macroTargets(plan, state.dailyCalorieGoal);
            var fiber = 0.0, sugar = 0.0, satFat = 0.0;
            for (final m in state.entries) {
              for (final n in m.nutrition) {
                fiber += n.fiberG;
                sugar += n.sugarG;
                satFat += n.saturatedFatG;
              }
            }
            return AppCard(
              width: double.infinity,
              padding: AppDimens.cardPaddingCompact,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppCaption("Today's macros"),
                  const SizedBox(height: AppDimens.space12),
                  MacroBar(
                    label: 'Protein',
                    value: state.totalProteinG,
                    maxValue: targets.protein,
                    color: AppColors.protein,
                  ),
                  const SizedBox(height: AppDimens.space12),
                  MacroBar(
                    label: 'Carbs',
                    value: state.totalCarbsG,
                    maxValue: targets.carbs,
                    color: AppColors.carbs,
                  ),
                  const SizedBox(height: AppDimens.space12),
                  MacroBar(
                    label: 'Fat',
                    value: state.totalFatG,
                    maxValue: targets.fat,
                    color: AppColors.fat,
                  ),
                  const SizedBox(height: AppDimens.cardInnerGap),
                  TrackerFigureRow(
                    figures: [
                      TrackerFigure(
                        label: 'Fibre',
                        value: '${fiber.toStringAsFixed(1)}g',
                        icon: Icons.grass_rounded,
                      ),
                      TrackerFigure(
                        label: 'Sugar',
                        value: '${sugar.toStringAsFixed(1)}g',
                        icon: Icons.icecream_rounded,
                      ),
                      TrackerFigure(
                        label: 'Sat. fat',
                        value: '${satFat.toStringAsFixed(1)}g',
                        icon: Icons.opacity_rounded,
                      ),
                    ],
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
