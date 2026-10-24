import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/fit_text.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_status.dart';
import 'package:vital_up/core/widgets/tracker/tracker_widgets.dart';
import 'package:vital_up/features/activity_goals/domain/entities/activity_goal.dart';
import 'package:vital_up/features/activity_goals/presentation/cubit/activity_goals_cubit.dart';
import 'package:vital_up/features/activity_goals/presentation/widgets/goal_widgets.dart';

const _metric = TrackerMetric.activity;

/// Home card: a ring with today's overall progress (one goal: its
/// percentage; several: how many are met, the ring averaging them), the
/// headline goal's figure (today's steps if set) beside it, up to two more
/// goals as lines, and a one-tap workout start. A met workout goal never
/// leaves the ring at 0% just because no steps were counted.
class ActivityGoalsCard extends StatelessWidget {
  const ActivityGoalsCard({super.key});

  /// Goals shown besides the headline one; the rest are a tap away.
  static const _maxOthers = 2;

  Future<void> _push(BuildContext context, String route) async {
    final cubit = context.read<ActivityGoalsCubit>();
    await context.pushNamed(route);
    cubit.load();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActivityGoalsCubit, ActivityGoalsState>(
      builder: (context, state) {
        if (state.snapshot == null) {
          return TrackerCardPlaceholder(
            metric: _metric,
            onRetry: state.failed
                ? context.read<ActivityGoalsCubit>().load
                : null,
          );
        }
        final goals = state.goals;
        final headline = state.headline;
        final done = goals.where((g) => g.achieved).length;
        return TrackerCard(
          metric: _metric,
          status: headline == null
              ? TrackerStatus.noGoal
              : done == goals.length
              ? TrackerStatus.done
              // Like the ring: several goals count together, so a met
              // workout goal isn't "Not logged" while steps are at 0.
              : goals.length > 1
              ? TrackerStatus.of(
                  value: goals.fold<double>(0, (sum, g) => sum + g.fraction),
                  goal: goals.length.toDouble(),
                  paceFraction:
                      goals.fold<double>(0, (sum, g) => sum + _pace(g)) /
                      goals.length,
                )
              : TrackerStatus.of(
                  value: headline.current,
                  goal: headline.goal.target,
                  paceFraction: _pace(headline),
                ),
          onOpen: () => _push(context, _metric.route),
          actions: [
            TrackerQuickAction(
              label: _metric.logLabel,
              icon: _metric.logIcon,
              color: _metric.color,
              filled: true,
              onTap: () => _push(context, 'activity-tracking'),
            ),
            if (headline == null)
              TrackerQuickAction(
                label: 'Set a goal',
                icon: Icons.flag_rounded,
                svgAsset: TrackerIcons.goal,
                color: _metric.color,
                onTap: () => _push(context, _metric.route),
              ),
          ],
          child: headline == null
              ? Text(
                  'Set a step or workout goal to see your progress here.',
                  style: context.text.bodyMedium?.copyWith(
                    color: context.vColors.grayText,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Headline(headline, goals: goals),
                    for (final g
                        in goals
                            .where((g) => g != headline)
                            .take(_maxOthers)) ...[
                      const SizedBox(height: AppDimens.space12),
                      _GoalLine(g),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

/// Where [goal] should be by now: through the waking day for a daily
/// goal, through the week (Monday to Sunday) for a weekly one, so Monday
/// evening isn't "Behind" on a week's target.
double _pace(GoalProgress goal) => goal.goal.period == GoalPeriod.weekly
    ? TrackerStatus.weekPace()
    : TrackerStatus.dayPace();

/// "Steps", or "Steps · this week" for a weekly goal.
String _goalName(ActivityGoal goal) => goal.period == GoalPeriod.daily
    ? goal.metric.label
    : '${goal.metric.label} · ${goal.period.windowLabel.toLowerCase()}';

/// The headline goal: a ring with the percentage, and beside it the
/// metric, the figure so far and the target.
class _Headline extends StatelessWidget {
  final GoalProgress progress;

  /// Every goal: the ring sums them up when there are several.
  final List<GoalProgress> goals;

  const _Headline(this.progress, {required this.goals});

  @override
  Widget build(BuildContext context) {
    final goal = progress.goal;
    final metric = goal.metric;
    final grey = context.vColors.grayText;
    return TrackerHeroLayout(
      ring: _ring(),
      details: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GoalMetricIcon(metric, size: AppDimens.iconXs),
              const SizedBox(width: AppDimens.space6),
              Expanded(
                child: FitText(
                  _goalName(goal),
                  style: context.text.bodySmall?.copyWith(color: grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.space4),
          FitText(
            metric.format(progress.current),
            style: AppTextStyles.metric.copyWith(
              color: context.colors.onSurface,
            ),
          ),
          FitText(
            'of ${metric.formatWithUnit(goal.target)}',
            style: context.text.bodyMedium?.copyWith(color: grey),
          ),
        ],
      ),
    );
  }
}

extension on _Headline {
  TrackerHeroRing _ring() {
    final color = progress.goal.metric.color;
    if (goals.length > 1) {
      final met = goals.where((g) => g.achieved).length;
      final average =
          goals.fold(0.0, (sum, g) => sum + g.fraction) / goals.length;
      return TrackerHeroRing(
        fraction: average,
        color: color,
        value: '$met of ${goals.length}',
        caption: 'goals met',
      );
    }
    final goal = progress.goal;
    // Rounded down, so "100%" only shows with the goal met.
    final percent = goal.target > 0
        ? (progress.current / goal.target * 100).floor()
        : 0;
    return TrackerHeroRing(
      fraction: progress.fraction,
      color: color,
      value: '$percent%',
      caption: progress.achieved ? 'goal met' : 'of goal',
    );
  }
}

/// A secondary goal: its icon badge and a [TrackerBarRow].
class _GoalLine extends StatelessWidget {
  final GoalProgress progress;

  const _GoalLine(this.progress);

  @override
  Widget build(BuildContext context) {
    final goal = progress.goal;
    final metric = goal.metric;
    return Row(
      children: [
        AppIconBadge(
          color: metric.color,
          size: AppDimens.iconBadgeSmall,
          icon: GoalMetricIcon(
            metric,
            size: AppDimens.iconXs,
            color: AppIconBadge.glyphColor(context, metric.color),
          ),
        ),
        const SizedBox(width: AppDimens.space12),
        Expanded(
          child: TrackerBarRow(
            name: _goalName(goal),
            figure:
                '${metric.format(progress.current)} / '
                '${metric.formatWithUnit(goal.target)}',
            fraction: progress.fraction,
            color: metric.color,
            done: progress.achieved,
          ),
        ),
      ],
    );
  }
}
