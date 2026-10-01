import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/charts/trend_bar_chart.dart';
import 'package:vital_up/features/activity_goals/presentation/cubit/activity_goals_cubit.dart';
import 'package:vital_up/features/activity_goals/presentation/widgets/goal_widgets.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/dashboard_card_header.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/trend_widgets.dart';

/// Home card: up to three goals with progress, the first goal's 7-day
/// chart, and quick links to manage goals or start a workout.
class ActivityGoalsCard extends StatelessWidget {
  const ActivityGoalsCard({super.key});

  static const _maxRows = 3;

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
          return AppCard(
            width: double.infinity,
            child: state.failed
                ? DashboardCardError(
                    title: 'Activity Goals',
                    iconAsset: 'assets/icons/barbell.svg',
                    onRetry: context.read<ActivityGoalsCubit>().load,
                  )
                : const DashboardCardLoading(),
          );
        }
        final goals = state.goals;
        final first = goals.firstOrNull;
        return AppCard(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DashboardCardHeader(
                title: 'Activity Goals',
                iconAsset: 'assets/icons/barbell.svg',
                trailing: CardLink(
                  label: 'Manage',
                  onTap: () => _push(context, 'activity-goals'),
                ),
              ),
              const SizedBox(height: AppDimens.cardInnerGap),
              if (goals.isEmpty)
                Text(
                  'Set a daily or weekly target for steps, distance, '
                  'calories, active minutes or workouts.',
                  style: context.text.bodyMedium
                      ?.copyWith(color: context.vColors.grayText),
                )
              else
                for (final g in goals.take(_maxRows)) ...[
                  GoalProgressRow(
                    goal: g.goal,
                    current: g.current,
                    fraction: g.fraction,
                  ),
                  const SizedBox(height: AppDimens.space12),
                ],
              if (first != null) ...[
                Text(
                  '${first.goal.metric.label} · last 7 days',
                  style: context.text.labelSmall
                      ?.copyWith(color: context.vColors.grayText),
                ),
                const SizedBox(height: AppDimens.space8),
                TrendBarChart(
                  series: first.series,
                  color: first.goal.metric.color,
                  compact: true,
                  valueFormatter: first.goal.metric.format,
                ),
              ],
              const SizedBox(height: AppDimens.cardInnerGap),
              Row(
                children: [
                  if (goals.isEmpty) ...[
                    Expanded(
                      child: AppSecondaryButton(
                        label: 'Set a goal',
                        onTap: () => _push(context, 'activity-goals'),
                      ),
                    ),
                    const SizedBox(width: AppDimens.space12),
                  ],
                  Expanded(
                    child: AppPrimaryButton(
                      label: 'Start workout',
                      onTap: () => _push(context, 'activity-tracking'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
