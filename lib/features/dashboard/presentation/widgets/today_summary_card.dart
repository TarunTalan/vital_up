import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_status.dart';
import 'package:vital_up/core/widgets/tracker/tracker_widgets.dart';
import 'package:vital_up/features/activity_goals/domain/entities/activity_goal.dart';
import 'package:vital_up/features/activity_goals/presentation/cubit/activity_goals_cubit.dart';
import 'package:vital_up/features/activity_goals/presentation/widgets/goal_widgets.dart';
import 'package:vital_up/features/dashboard/data/services/sleep_service.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/sleep_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/sleep_state.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/stress_checkin_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/water_intake_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/water_intake_state.dart';
import 'package:vital_up/features/dashboard/presentation/pages/water_trends_page.dart';
import 'package:vital_up/features/diet_plan/presentation/cubit/diet_plan_cubit.dart';
import 'package:vital_up/features/diet_plan/presentation/cubit/diet_plan_state.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_bloc.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_state.dart';
import 'dashboard_card_header.dart';

const _placeholder = '—';
const _quickWaterMl = 250;

/// The activity goal shown in the summary: today's steps if set, else the
/// first goal.
GoalProgress? _headlineGoal(ActivityGoalsState state) {
  final goals = state.goals;
  return goals
          .where(
            (g) =>
                g.goal.metric == GoalMetric.steps &&
                g.goal.period == GoalPeriod.daily,
          )
          .firstOrNull ??
      goals.firstOrNull;
}

double? _calorieGoal(BuildContext context, MealLogLoaded meals) {
  final plan = context.watch<DietPlanCubit>().state;
  return plan is DietPlanLoaded
      ? plan.mealPlan.totalCalories.toDouble()
      : meals.dailyCalorieGoal?.toDouble();
}

Duration? _lastNight(SleepState state) => switch (state) {
  SleepLoadedAuto(:final session) => session.duration,
  SleepLoadedManual(:final session) => session.duration,
  _ => null,
};

/// Home hero: today's activity, calories, water and sleep against their
/// goals, in one row. Each figure opens its tracker via [onOpen].
class TodaySummaryCard extends StatelessWidget {
  final ValueChanged<TrackerMetric> onOpen;

  const TodaySummaryCard({super.key, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      _ActivityItem(onOpen: onOpen),
      _CaloriesItem(onOpen: onOpen),
      _WaterItem(onOpen: onOpen),
      _SleepItem(onOpen: onOpen),
    ];
    return AppCard(
      width: double.infinity,
      padding: AppDimens.cardPaddingCompact,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: AppDimens.space4),
            Expanded(child: items[i]),
          ],
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final ValueChanged<TrackerMetric> onOpen;
  const _ActivityItem({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final goal = _headlineGoal(context.watch<ActivityGoalsCubit>().state);
    final metric = goal?.goal.metric;
    return _SummaryItem(
      metric: TrackerMetric.activity,
      label: metric?.label ?? TrackerMetric.activity.label,
      value: goal == null ? _placeholder : metric!.format(goal.current),
      goal: goal == null
          ? TrackerStatus.noGoal.label
          : 'of ${metric!.formatWithUnit(goal.goal.target)}',
      fraction: goal?.fraction,
      onTap: () => onOpen(TrackerMetric.activity),
    );
  }
}

class _CaloriesItem extends StatelessWidget {
  final ValueChanged<TrackerMetric> onOpen;
  const _CaloriesItem({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MealLogBloc>().state;
    final meals = state is MealLogLoaded ? state : null;
    final goal = meals == null ? null : _calorieGoal(context, meals);
    final number = NumberFormat.decimalPattern();
    return _SummaryItem(
      metric: TrackerMetric.nutrition,
      label: 'Calories',
      value: meals == null
          ? _placeholder
          : number.format(meals.totalCalories.round()),
      goal: goal == null
          ? TrackerStatus.noGoal.label
          : 'of ${number.format(goal.round())} kcal',
      fraction: meals == null || goal == null || goal <= 0
          ? null
          : meals.totalCalories / goal,
      onTap: () => onOpen(TrackerMetric.nutrition),
    );
  }
}

class _WaterItem extends StatelessWidget {
  final ValueChanged<TrackerMetric> onOpen;
  const _WaterItem({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WaterIntakeCubit>().state;
    final water = state is WaterIntakeLoaded ? state : null;
    return _SummaryItem(
      metric: TrackerMetric.water,
      label: TrackerMetric.water.label,
      value: water == null
          ? _placeholder
          : WaterTrendsPage.formatMl(water.currentIntakeMl.toDouble()),
      goal: water == null
          ? TrackerStatus.notLogged.label
          : 'of ${WaterTrendsPage.formatMl(water.dailyGoalMl.toDouble())}',
      fraction: water == null || water.dailyGoalMl <= 0
          ? null
          : water.currentIntakeMl / water.dailyGoalMl,
      onTap: () => onOpen(TrackerMetric.water),
    );
  }
}

class _SleepItem extends StatelessWidget {
  final ValueChanged<TrackerMetric> onOpen;
  const _SleepItem({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final slept = _lastNight(context.watch<SleepCubit>().state);
    final goalMinutes = sl<SleepService>().getGoalMinutes();
    return _SummaryItem(
      metric: TrackerMetric.sleep,
      label: TrackerMetric.sleep.label,
      value: slept == null ? _placeholder : formatDashboardDuration(slept),
      goal: slept == null
          ? TrackerStatus.notLogged.label
          : 'of ${formatDashboardDuration(Duration(minutes: goalMinutes))}',
      fraction: slept == null || goalMinutes <= 0
          ? null
          : slept.inMinutes / goalMinutes,
      onTap: () => onOpen(TrackerMetric.sleep),
    );
  }
}

/// One column of the summary: label, value, "of goal" and a progress bar.
class _SummaryItem extends StatelessWidget {
  final TrackerMetric metric;
  final String label;
  final String value;
  final String goal;
  final double? fraction;
  final VoidCallback onTap;

  const _SummaryItem({
    required this.metric,
    required this.label,
    required this.value,
    required this.goal,
    required this.fraction,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final grey = context.vColors.grayText;
    return Semantics(
      button: true,
      label: '$label $value $goal',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  TrackerIcon(metric, size: AppDimens.iconXs),
                  const SizedBox(width: AppDimens.space4),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall?.copyWith(color: grey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.space8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: context.text.titleMedium?.copyWith(
                    color: context.colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                goal,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall?.copyWith(color: grey),
              ),
              const SizedBox(height: AppDimens.space8),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: (fraction ?? 0).clamp(0.0, 1.0)),
                duration: AppDurations.slow,
                curve: Curves.easeOutCubic,
                builder: (context, v, _) =>
                    AppProgressBar(value: v, color: metric.color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The single most useful next step for today, or nothing when there
/// isn't one.
typedef _Insight = ({
  String message,
  TrackerMetric metric,
  String actionLabel,
  IconData actionIcon,
});

_Insight? _insightFor(BuildContext context, DateTime now) {
  final hour = now.hour;
  final pace = TrackerStatus.dayPace(now);

  final sleep = context.watch<SleepCubit>().state;
  if (hour < 12 && sleep is SleepNeedsManualEntry) {
    return (
      message: "Log last night's sleep to see how rested you are.",
      metric: TrackerMetric.sleep,
      actionLabel: TrackerMetric.sleep.logLabel,
      actionIcon: TrackerMetric.sleep.logIcon,
    );
  }

  final water = context.watch<WaterIntakeCubit>().state;
  final waterStatus = water is WaterIntakeLoaded
      ? TrackerStatus.of(
          value: water.currentIntakeMl.toDouble(),
          goal: water.dailyGoalMl.toDouble(),
          paceFraction: pace,
        )
      : null;
  if (water is WaterIntakeLoaded &&
      (waterStatus == TrackerStatus.behind ||
          waterStatus == TrackerStatus.notLogged)) {
    final left = water.dailyGoalMl - water.currentIntakeMl;
    return (
      message:
          "You're ${WaterTrendsPage.formatMl(left.toDouble())} short of "
          'your water goal.',
      metric: TrackerMetric.water,
      actionLabel: '+$_quickWaterMl ml',
      actionIcon: TrackerMetric.water.icon,
    );
  }

  final mood = context.watch<StressCheckInCubit>().state;
  if (hour >= 12 && mood.today == null) {
    return (
      message: 'Take a moment to check in on how you feel.',
      metric: TrackerMetric.mood,
      actionLabel: TrackerMetric.mood.logLabel,
      actionIcon: TrackerMetric.mood.icon,
    );
  }

  final goal = _headlineGoal(context.watch<ActivityGoalsCubit>().state);
  if (hour >= 14 &&
      goal != null &&
      goal.goal.period == GoalPeriod.daily &&
      TrackerStatus.of(
            value: goal.current,
            goal: goal.goal.target,
            paceFraction: pace,
          ) ==
          TrackerStatus.behind) {
    final metric = goal.goal.metric;
    return (
      message:
          '${metric.formatWithUnit(goal.goal.target - goal.current)} to go '
          'on your ${metric.label.toLowerCase()} goal.',
      metric: TrackerMetric.activity,
      actionLabel: TrackerMetric.activity.logLabel,
      actionIcon: TrackerMetric.activity.logIcon,
    );
  }

  final meals = context.watch<MealLogBloc>().state;
  if (hour >= 10 && meals is MealLogLoaded && meals.entries.isEmpty) {
    return (
      message: 'No meals logged yet today.',
      metric: TrackerMetric.nutrition,
      actionLabel: TrackerMetric.nutrition.logLabel,
      actionIcon: TrackerMetric.nutrition.logIcon,
    );
  }
  return null;
}

/// One-line nudge under the summary with a single action. Water is added
/// right here; every other action goes through [onLog].
class DashboardInsightCard extends StatelessWidget {
  final ValueChanged<TrackerMetric> onLog;

  const DashboardInsightCard({super.key, required this.onLog});

  @override
  Widget build(BuildContext context) {
    final insight = _insightFor(context, DateTime.now());
    return AnimatedSize(
      duration: AppDurations.medium,
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: insight == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: AppDimens.cardGap),
              child: AppCard(
                width: double.infinity,
                highlighted: true,
                padding: AppDimens.cardPaddingCompact,
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: AppDimens.iconMd,
                      color: context.colors.primary,
                    ),
                    const SizedBox(width: AppDimens.space12),
                    Expanded(
                      child: Text(
                        insight.message,
                        style: context.text.bodyMedium?.copyWith(
                          color: context.colors.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimens.space12),
                    SizedBox(
                      width: AppDimens.quickActionWidth,
                      child: TrackerQuickAction(
                        label: insight.actionLabel,
                        icon: insight.actionIcon,
                        color: insight.metric.color,
                        filled: true,
                        onTap: () => _act(context, insight.metric),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  void _act(BuildContext context, TrackerMetric metric) {
    if (metric == TrackerMetric.water) {
      HapticFeedback.mediumImpact();
      context.read<WaterIntakeCubit>().addWater(_quickWaterMl);
    } else {
      onLog(metric);
    }
  }
}
