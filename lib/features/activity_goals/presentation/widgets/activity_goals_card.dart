import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_status.dart';
import 'package:vital_up/core/widgets/tracker/tracker_widgets.dart';
import 'package:vital_up/features/activity_goals/presentation/cubit/activity_goals_cubit.dart';
import 'package:vital_up/features/activity_goals/presentation/widgets/goal_widgets.dart';

const _metric = TrackerMetric.activity;

/// Home card: up to three activity goals with progress, and a one-tap
/// workout start.
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
          return TrackerCardPlaceholder(
            metric: _metric,
            onRetry: state.failed
                ? context.read<ActivityGoalsCubit>().load
                : null,
          );
        }
        final goals = state.goals;
        final done = goals.where((g) => g.fraction >= 1).length;
        return TrackerCard(
          metric: _metric,
          status: goals.isEmpty
              ? TrackerStatus.noGoal
              : done == goals.length
              ? TrackerStatus.done
              : TrackerStatus.of(
                  value: goals.first.current,
                  goal: goals.first.goal.target,
                  paceFraction: TrackerStatus.dayPace(),
                ),
          statusLabel: goals.length > 1 && done < goals.length
              ? '$done/${goals.length} done'
              : null,
          onOpen: () => _push(context, _metric.route),
          actions: [
            TrackerQuickAction(
              label: _metric.logLabel,
              icon: _metric.logIcon,
              color: _metric.color,
              filled: true,
              onTap: () => _push(context, 'activity-tracking'),
            ),
            if (goals.isEmpty)
              TrackerQuickAction(
                label: 'Set a goal',
                icon: Icons.flag_rounded,
                color: _metric.color,
                onTap: () => _push(context, _metric.route),
              ),
          ],
          child: goals.isEmpty
              ? Text(
                  'Set a daily or weekly target for steps, distance, '
                  'calories, active minutes or workouts.',
                  style: context.text.bodyMedium?.copyWith(
                    color: context.vColors.grayText,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final g in goals.take(_maxRows)) ...[
                      GoalProgressRow(
                        goal: g.goal,
                        current: g.current,
                        fraction: g.fraction,
                      ),
                      if (g != goals.take(_maxRows).last)
                        const SizedBox(height: AppDimens.space12),
                    ],
                  ],
                ),
        );
      },
    );
  }
}
