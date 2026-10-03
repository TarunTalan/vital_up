import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/charts/trend_bar_chart.dart';
import 'package:vital_up/features/activity_goals/domain/entities/activity_goal.dart';
import 'package:vital_up/features/activity_goals/presentation/cubit/activity_goals_cubit.dart';
import 'package:vital_up/features/activity_goals/presentation/widgets/goal_widgets.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/dashboard_card_header.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/trend_widgets.dart';

/// All activity goals with progress, the selected goal's trend, and the
/// workouts logged in the period.
class ActivityGoalsPage extends StatelessWidget {
  const ActivityGoalsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ActivityGoalsCubit>()..load(),
      child: const _ActivityGoalsView(),
    );
  }
}

class _ActivityGoalsView extends StatelessWidget {
  const _ActivityGoalsView();

  Future<void> _openEditor(BuildContext context, {ActivityGoal? goal}) async {
    final cubit = context.read<ActivityGoalsCubit>();
    final saved = await showAppBottomSheet<ActivityGoal>(
      context: context,
      builder: (_) => GoalEditorSheet(
        initial: goal,
        taken: {for (final g in cubit.state.goals) g.goal.id},
        onDelete: goal == null ? null : () => cubit.delete(goal),
      ),
    );
    if (saved != null) await cubit.save(saved);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActivityGoalsCubit, ActivityGoalsState>(
      builder: (context, state) {
        final cubit = context.read<ActivityGoalsCubit>();
        final snapshot = state.snapshot;
        final selected = state.selected;
        return AppScaffold(
          header: const AppPageHeader(title: 'Activity Goals'),
          onRefresh: () => cubit.load(),
          bottomBar: AppPrimaryButton(
            label: 'Add goal',
            enabled: state.goals.length <
                GoalMetric.values.length * GoalPeriod.values.length,
            onTap: () => _openEditor(context),
          ),
          body: snapshot == null
              ? Padding(
                  padding: const EdgeInsets.only(top: AppDimens.space48),
                  child: state.failed
                      ? LoadErrorView(onRetry: cubit.load)
                      : const Center(child: CircularProgressIndicator()),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!snapshot.stepsFromHealth)
                      const Padding(
                        padding: EdgeInsets.only(bottom: AppDimens.cardGap),
                        child: AppInfoNote(
                          message: 'Steps come from workouts tracked in '
                              'VitalUp. Connect Health in Vita to count all '
                              'your daily steps.',
                        ),
                      ),
                    if (state.goals.isEmpty)
                      const AppInfoNote(
                        message: 'No goals yet — add one to start tracking.',
                      ),
                    for (final g in state.goals) ...[
                      GoalProgressRow(
                        goal: g.goal,
                        current: g.current,
                        fraction: g.fraction,
                        selected: g.goal.id == selected?.goal.id,
                        onTap: () {
                          if (g.goal.id == selected?.goal.id) {
                            _openEditor(context, goal: g.goal);
                          } else {
                            cubit.select(g.goal);
                          }
                        },
                      ),
                      const SizedBox(height: AppDimens.space8),
                    ],
                    if (state.goals.isNotEmpty)
                      Text(
                        'Tap a goal to chart it, tap again to edit.',
                        style: context.text.bodySmall
                            ?.copyWith(color: context.vColors.grayText),
                      ),
                    if (selected != null) ...[
                      const SizedBox(height: AppDimens.sectionGap),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              selected.goal.metric.label,
                              style: context.text.headlineSmall,
                            ),
                          ),
                          TrendRangeToggle(
                            value: state.range,
                            onChanged: cubit.load,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimens.cardGap),
                      AppCard(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TrendBarChart(
                              series: selected.series,
                              color: selected.goal.metric.color,
                              valueFormatter: selected.goal.metric.format,
                            ),
                            const SizedBox(height: AppDimens.cardInnerGap),
                            TrendStatsRow(
                              series: selected.series,
                              format: selected.goal.metric.format,
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: AppDimens.sectionGap),
                    Text('Workouts', style: context.text.headlineSmall),
                    const SizedBox(height: AppDimens.cardGap),
                    if (snapshot.sessions.isEmpty)
                      const AppInfoNote(
                        message: 'No workouts tracked in this period yet.',
                      ),
                    for (final s in snapshot.sessions) ...[
                      TrendLogTile(
                        icon: Icons.directions_run_rounded,
                        color: AppColors.activityWorkouts,
                        title: s.activityType.label,
                        subtitle:
                            '${DateFormat('EEE d MMM, h:mm a').format(s.startTime)} · '
                            '${formatDashboardDuration(Duration(seconds: s.totalDurationSeconds))}',
                        trailing:
                            '${(s.totalDistanceMeters / 1000).toStringAsFixed(1)} km',
                      ),
                      const SizedBox(height: AppDimens.space8),
                    ],
                  ],
                ),
        );
      },
    );
  }
}
