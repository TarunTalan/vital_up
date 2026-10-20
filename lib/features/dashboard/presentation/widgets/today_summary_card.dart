import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/fit_text.dart';
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
import 'nutrition_summary_card.dart' show calorieGoalFor;
import 'package:vital_up/core/utils/number_formats.dart';

const _placeholder = '—';

/// Goal line while a figure is loading or couldn't load: blank rather than
/// claiming "Not logged" or "Set a goal" before we know.
const _unknown = '';
const _quickWaterMl = 250;

double? _calorieGoal(BuildContext context, MealLogLoaded meals) {
  final plan = context.watch<DietPlanCubit>().state;
  return calorieGoalFor(
    plan is DietPlanLoaded ? plan.mealPlan : null,
    meals.dailyCalorieGoal,
  );
}

/// Last night as the Sleep card shows it: a saved night, or the phone's
/// estimate still to review (not "Not logged" while the card below shows
/// a figure).
Duration? _lastNight(SleepState state) => switch (state) {
  SleepLoadedAuto(:final session) => session.duration,
  SleepLoadedManual(:final session) => session.duration,
  SleepNeedsConfirmation(:final estimate) => estimate.duration,
  _ => null,
};

/// Home hero: today's activity, calories, water and sleep against their
/// goals, in one row. Each figure opens its tracker via [onOpen].
///
/// Labels, values and goals each use one size across all four columns:
/// when one of them doesn't fit, every column shrinks by the same amount so
/// the row stays even, down to the [FitText] minimum. A figure that still
/// doesn't fit switches to a shorter form ("12.3K", "of 10K"); only when
/// even that would end in "..." does the card become a 2 x 2 grid with
/// twice the width per figure.
class TodaySummaryCard extends StatelessWidget {
  final ValueChanged<TrackerMetric> onOpen;

  const TodaySummaryCard({super.key, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final items = [
      _activityItem(context),
      _caloriesItem(context),
      _waterItem(context),
      _sleepItem(context),
    ];
    return AppCard(
      width: double.infinity,
      // Each figure has its own tap padding: together they make the card's
      // usual 16dp inset, so figures line up with the cards below.
      padding: const EdgeInsets.all(AppDimens.space16 - _SummaryItem.padding),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = AppDimens.space4;
          double column(int perRow) =>
              (constraints.maxWidth - gap * (perRow - 1)) / perRow -
              _SummaryItem.padding * 2;
          var perRow = items.length;
          var layout = _SummaryLayout.fitting(context, items, column(perRow));
          if (!layout.whole) {
            perRow = 2;
            layout = _SummaryLayout.fitting(context, items, column(perRow));
          }
          return Column(
            children: [
              for (var row = 0; row < items.length; row += perRow) ...[
                // With the figures' padding, rows sit 12dp apart like
                // the columns.
                if (row > 0) const SizedBox(height: gap),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = row; i < row + perRow; i++) ...[
                      if (i > row) const SizedBox(width: gap),
                      Expanded(
                        child: _SummaryItem(
                          data: items[i],
                          layout: layout,
                          index: i,
                          onTap: () => onOpen(items[i].metric),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  _SummaryData _activityItem(BuildContext context) {
    final state = context.watch<ActivityGoalsCubit>().state;
    final goal = state.headline;
    final metric = goal?.goal.metric;
    final isSteps = metric == null || metric == GoalMetric.steps;
    return (
      metric: TrackerMetric.activity,
      label: metric?.label ?? TrackerMetric.activity.label,
      values: goal == null
          ? const [_placeholder]
          : [
              metric!.format(goal.current),
              if (metric != GoalMetric.distance)
                formatCompactCount(goal.current),
            ],
      goals: goal == null
          ? [state.snapshot == null ? _unknown : TrackerStatus.noGoal.label]
          : [
              // A weekly goal says so: its figure is the week's total.
              if (goal.goal.period == GoalPeriod.weekly) ...[
                'of ${metric!.formatWithUnit(goal.goal.target)} this week',
                'of ${metric.formatShortWithUnit(goal.goal.target)} this week',
                'of ${metric.formatShortWithUnit(goal.goal.target)}',
              ] else ...[
                'of ${metric!.formatWithUnit(goal.goal.target)}',
                'of ${metric.formatShortWithUnit(goal.goal.target)}',
              ],
              if (metric != GoalMetric.distance)
                'of ${formatCompactCount(goal.goal.target)}',
            ],
      fraction: goal?.fraction,
      iconAsset: isSteps ? 'assets/icons/trackers/step.svg' : null,
    );
  }

  _SummaryData _caloriesItem(BuildContext context) {
    final state = context.watch<MealLogBloc>().state;
    final meals = state is MealLogLoaded ? state : null;
    final goal = meals == null ? null : _calorieGoal(context, meals);
    return (
      metric: TrackerMetric.nutrition,
      label: 'Calories',
      values: meals == null
          ? const [_placeholder]
          : [
              formatCount(meals.totalCalories),
              formatCompactCount(meals.totalCalories),
            ],
      goals: goal == null
          ? [meals == null ? _unknown : TrackerStatus.noGoal.label]
          : [
              'of ${formatCount(goal)} kcal',
              'of ${formatCount(goal)}',
              'of ${NumberFormat.compact().format(goal.round())}',
            ],
      fraction: meals == null || goal == null || goal <= 0
          ? null
          : meals.totalCalories / goal,
      iconAsset: null,
    );
  }

  _SummaryData _waterItem(BuildContext context) {
    final state = context.watch<WaterIntakeCubit>().state;
    final water = state is WaterIntakeLoaded ? state : null;
    return (
      metric: TrackerMetric.water,
      label: TrackerMetric.water.label,
      values: [
        water == null
            ? _placeholder
            : WaterTrendsPage.formatMl(water.currentIntakeMl.toDouble()),
      ],
      goals: [
        water == null
            ? _unknown
            : 'of ${WaterTrendsPage.formatMl(water.dailyGoalMl.toDouble())}',
      ],
      fraction: water == null || water.dailyGoalMl <= 0
          ? null
          : water.currentIntakeMl / water.dailyGoalMl,
      iconAsset: null,
    );
  }

  _SummaryData _sleepItem(BuildContext context) {
    final state = context.watch<SleepCubit>().state;
    final slept = _lastNight(state);
    // Still loading, or couldn't load: nothing to say about last night yet.
    final known =
        state is! SleepInitial &&
        state is! SleepLoading &&
        state is! SleepError;
    final goalMinutes = sl<SleepService>().getGoalMinutes();
    return (
      metric: TrackerMetric.sleep,
      label: TrackerMetric.sleep.label,
      values: [slept == null ? _placeholder : formatDashboardDuration(slept)],
      goals: slept == null
          ? [known ? TrackerStatus.notLogged.label : _unknown]
          : [
              'of ${formatDashboardDuration(Duration(minutes: goalMinutes))}',
              if (goalMinutes % 60 == 0) 'of ${goalMinutes ~/ 60}h',
            ],
      fraction: slept == null || goalMinutes <= 0
          ? null
          : slept.inMinutes / goalMinutes,
      iconAsset: null,
    );
  }
}

/// One summary column. [values] and [goals] list the same figure from
/// longest to shortest; the card shows the first one that fits.
typedef _SummaryData = ({
  TrackerMetric metric,
  String label,
  List<String> values,
  List<String> goals,
  double? fraction,
  String? iconAsset,
});

/// Text styles shared by every summary column, already sized for the
/// system text scale (render them with [TextScaler.noScaling]), and the
/// form of each figure that fits.
class _SummaryLayout {
  final TextStyle label;
  final TextStyle value;
  final TextStyle goal;
  final List<String> values;
  final List<String> goals;

  /// Every label and figure fits without an ellipsis.
  final bool whole;

  const _SummaryLayout(
    this.label,
    this.value,
    this.goal,
    this.values,
    this.goals,
    this.whole,
  );

  factory _SummaryLayout.fitting(
    BuildContext context,
    List<_SummaryData> items,
    double columnWidth,
  ) {
    final scaler = MediaQuery.textScalerOf(context);
    final grey = context.vColors.grayText;
    final caption = context.text.labelSmall!.copyWith(color: grey);
    final value = context.text.titleMedium!.copyWith(
      color: context.colors.onSurface,
      fontWeight: FontWeight.w600,
    );
    final labelWidth = columnWidth - AppDimens.iconXs - AppDimens.space4;
    final labels = _fit(caption, scaler, [
      for (final i in items) [i.label],
    ], labelWidth);
    final values = _fit(value, scaler, [
      for (final i in items) i.values,
    ], columnWidth);
    final goals = _fit(caption, scaler, [
      for (final i in items) i.goals,
    ], columnWidth);
    return _SummaryLayout(
      labels.style,
      values.style,
      goals.style,
      values.texts,
      goals.texts,
      labels.whole && values.whole && goals.whole,
    );
  }

  /// For each column, the longest of its [options] that fits [width] at
  /// the smallest allowed size, and one [style] size for all of them:
  /// shrunk just enough for the widest to fit, never below the minimum.
  static ({TextStyle style, List<String> texts, bool whole}) _fit(
    TextStyle style,
    TextScaler scaler,
    List<List<String>> options,
    double width,
  ) {
    final size = scaler.scale(style.fontSize!);
    final sized = style.copyWith(fontSize: size);
    final floor = FitText.minFactor(scaler, style.fontSize!);
    double measure(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: sized),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final w = painter.width;
      painter.dispose();
      return w;
    }

    final texts = [
      for (final o in options)
        o.firstWhere((t) => measure(t) * floor <= width, orElse: () => o.last),
    ];
    final widest = texts.map(measure).fold(0.0, math.max);
    if (width > 0 && widest <= width) {
      return (style: sized, texts: texts, whole: true);
    }
    // Round down so the widest text never ends up a fraction too wide.
    final factor = math.max(floor, (width / widest * 100).floor() / 100);
    return (
      style: sized.copyWith(fontSize: size * factor),
      texts: texts,
      whole: width > 0 && widest * factor <= width,
    );
  }
}

/// One column of the summary: label, value, "of goal" and a progress bar.
class _SummaryItem extends StatelessWidget {
  static const double padding = AppDimens.space4;

  final _SummaryData data;
  final _SummaryLayout layout;
  final int index;
  final VoidCallback onTap;

  const _SummaryItem({
    required this.data,
    required this.layout,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = data.fraction;
    return Semantics(
      button: true,
      label: '${data.label} ${data.values.first} ${data.goals.first}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        child: Padding(
          padding: const EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (data.iconAsset != null)
                    SvgPicture.asset(
                      data.iconAsset!,
                      width: AppDimens.iconXs,
                      height: AppDimens.iconXs,
                      colorFilter: ColorFilter.mode(
                        context.iconTint(data.metric.color),
                        BlendMode.srcIn,
                      ),
                    )
                  else
                    TrackerIcon(data.metric, size: AppDimens.iconXs),
                  const SizedBox(width: AppDimens.space4),
                  Expanded(child: _line(data.label, layout.label)),
                ],
              ),
              const SizedBox(height: AppDimens.space8),
              _line(layout.values[index], layout.value),
              _line(layout.goals[index], layout.goal),
              const SizedBox(height: AppDimens.space8),
              TweenAnimationBuilder<double>(
                tween: Tween(
                  begin: 0,
                  end: fraction != null && fraction.isFinite
                      ? fraction.clamp(0.0, 1.0)
                      : 0.0,
                ),
                duration: AppDurations.slow,
                curve: Curves.easeOutCubic,
                builder: (context, v, _) =>
                    AppProgressBar(value: v, color: data.metric.color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(String text, TextStyle style) => Text(
    text,
    maxLines: 1,
    softWrap: false,
    overflow: TextOverflow.ellipsis,
    textScaler: TextScaler.noScaling,
    style: style,
  );
}

/// The single most useful next step for today, or nothing when there
/// isn't one.
typedef _Insight = ({
  String message,
  TrackerMetric metric,
  String actionLabel,
  IconData actionIcon,
  String? actionAsset,
});

_Insight? _insightFor(BuildContext context, DateTime now) {
  final hour = now.hour;
  final pace = TrackerStatus.dayPace(now);

  final sleep = context.watch<SleepCubit>().state;
  if (hour < 12 && sleep is SleepNeedsConfirmation) {
    return (
      message:
          'Your phone noticed about '
          '${formatDashboardDuration(sleep.estimate.duration)} of sleep. '
          'Check it looks right.',
      metric: TrackerMetric.sleep,
      actionLabel: 'Review',
      actionIcon: Icons.edit_rounded,
      actionAsset: TrackerIcons.edit,
    );
  }
  if (hour >= 4 && hour < 12 && sleep is SleepInBed) {
    return (
      message: "Good morning. Save last night's sleep when you're up.",
      metric: TrackerMetric.sleep,
      actionLabel: TrackerMetric.sleep.logLabel,
      actionIcon: TrackerMetric.sleep.logIcon,
      actionAsset: TrackerMetric.sleep.logIconAsset,
    );
  }
  // Not before 4 am: at 1 am nobody has slept "last night" yet.
  if (hour >= 4 && hour < 12 && sleep is SleepNeedsManualEntry) {
    return (
      message: "Log last night's sleep to see how rested you are.",
      metric: TrackerMetric.sleep,
      actionLabel: TrackerMetric.sleep.logLabel,
      actionIcon: TrackerMetric.sleep.logIcon,
      actionAsset: TrackerMetric.sleep.logIconAsset,
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
  // From 7 am, when the drinking day starts (not "2.5 L short" at 1 am).
  if (hour >= 7 &&
      water is WaterIntakeLoaded &&
      (waterStatus == TrackerStatus.behind ||
          waterStatus == TrackerStatus.notLogged)) {
    final left = water.dailyGoalMl - water.currentIntakeMl;
    return (
      message:
          "You're ${WaterTrendsPage.formatMl(left.toDouble())} short of "
          'your water goal.',
      metric: TrackerMetric.water,
      actionLabel: '+$_quickWaterMl ml',
      actionIcon: Icons.add_rounded,
      actionAsset: TrackerIcons.add,
    );
  }

  final mood = context.watch<StressCheckInCubit>().state;
  if (hour >= 12 && mood.today == null) {
    return (
      message: 'Take a moment to check in on how you feel.',
      metric: TrackerMetric.mood,
      actionLabel: TrackerMetric.mood.logLabel,
      actionIcon: TrackerMetric.mood.icon,
      actionAsset: TrackerMetric.mood.logIconAsset,
    );
  }

  final goal = context.watch<ActivityGoalsCubit>().state.headline;
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
      actionAsset: TrackerMetric.activity.logIconAsset,
    );
  }

  final meals = context.watch<MealLogBloc>().state;
  if (hour >= 10 && meals is MealLogLoaded && meals.entries.isEmpty) {
    return (
      message: 'No meals logged yet today.',
      metric: TrackerMetric.nutrition,
      actionLabel: TrackerMetric.nutrition.logLabel,
      actionIcon: TrackerMetric.nutrition.logIcon,
      actionAsset: TrackerMetric.nutrition.logIconAsset,
    );
  }
  return null;
}

/// One-line nudge under the summary with a single action. Water is added
/// right here; every other action goes through [onLog]. The action sits
/// beside the message when both fit, else under it (narrow phones, large
/// text), so the message never gets squeezed into a sliver.
class DashboardInsightCard extends StatelessWidget {
  final ValueChanged<TrackerMetric> onLog;

  const DashboardInsightCard({super.key, required this.onLog});

  /// Narrowest the message may get beside the action before it moves down.
  static const double _minMessageWidth = 160;

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
                child: LayoutBuilder(
                  builder: (context, constraints) =>
                      _content(context, insight, constraints.maxWidth),
                ),
              ),
            ),
    );
  }

  Widget _content(BuildContext context, _Insight insight, double width) {
    const badge = AppDimens.iconBadgeSmall;
    const gap = AppDimens.space12;
    final action = TrackerQuickAction(
      label: insight.actionLabel,
      icon: insight.actionIcon,
      svgAsset: insight.actionAsset,
      color: insight.metric.color,
      filled: true,
      onTap: () => _act(context, insight.metric),
    );
    final message = Text(
      insight.message,
      style: context.text.bodyMedium?.copyWith(color: context.colors.onSurface),
    );
    // Never narrower than the label needs, so it shows whole.
    final actionWidth = math.max(
      AppDimens.quickActionWidth,
      TrackerQuickAction.widthFor(context, insight.actionLabel),
    );
    final inline =
        width - badge - gap * 2 - actionWidth >=
        context.textScaled(_minMessageWidth);
    final lead = TrackerBadge(insight.metric, size: badge);
    if (inline) {
      return Row(
        children: [
          lead,
          const SizedBox(width: gap),
          Expanded(child: message),
          const SizedBox(width: gap),
          SizedBox(width: actionWidth, child: action),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            lead,
            const SizedBox(width: gap),
            Expanded(child: message),
          ],
        ),
        const SizedBox(height: AppDimens.space12),
        // Lined up under the message, not the badge.
        Padding(
          padding: const EdgeInsets.only(left: badge + gap),
          child: action,
        ),
      ],
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
