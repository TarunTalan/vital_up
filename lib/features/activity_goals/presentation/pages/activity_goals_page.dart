import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/charts/trend_bar_chart.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_widgets.dart';
import 'package:vital_up/features/activity_goals/domain/entities/activity_goal.dart';
import 'package:vital_up/features/activity_goals/presentation/cubit/activity_goals_cubit.dart';
import 'package:vital_up/features/activity_goals/presentation/widgets/goal_widgets.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/dashboard_card_header.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/tracker_insights.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/trend_widgets.dart';

const _metric = TrackerMetric.activity;

/// Activity: every goal with today's progress, the selected goal's trend
/// and insights, and the workouts in the period — the same order as the
/// other tracker pages, with several goals instead of one.
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
        onDelete: goal == null
            ? null
            : () async {
                if (!await cubit.delete(goal) && context.mounted) {
                  showErrorSnackBar(context, "Couldn't delete this goal. Try again.");
                }
              },
      ),
    );
    if (saved != null && !await cubit.save(saved) && context.mounted) {
      showErrorSnackBar(context, "Couldn't save this goal. Try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActivityGoalsCubit, ActivityGoalsState>(
      builder: (context, state) {
        final cubit = context.read<ActivityGoalsCubit>();
        final snapshot = state.snapshot;
        final selected = state.selected;
        final canAdd =
            state.goals.length <
            GoalMetric.values.length * GoalPeriod.values.length;
        return AppScaffold(
          header: AppPageHeader(
            title: _metric.label,
            action: AppHeaderAction(
              tooltip: 'Workout history',
              icon: const Icon(Icons.history_rounded),
              onTap: () => context.pushNamed('activity-history'),
            ),
          ),
          onRefresh: () => cubit.load(),
          bottomBar: AppPrimaryButton(
            label: _metric.logLabel,
            leadingIcon: Icon(_metric.logIcon),
            onTap: () async {
              await context.pushNamed('activity-tracking');
              cubit.load();
            },
          ),
          body: snapshot == null
              ? SizedBox(
                  height: AppDimens.trendChartHeight * 2,
                  child: state.failed
                      ? LoadErrorView(onRetry: cubit.load)
                      : TrackerLoading(color: _metric.color),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!snapshot.stepsFromHealth)
                      const Padding(
                        padding: EdgeInsets.only(bottom: AppDimens.cardGap),
                        child: AppInfoNote(
                          message:
                              'Steps come from workouts tracked in '
                              'VitalUp. Connect Health in Vita to count all '
                              'your daily steps.',
                        ),
                      ),
                    TrackerSectionTitle(
                      'Goals',
                      actionLabel: canAdd ? 'Add goal' : null,
                      onAction: () => _openEditor(context),
                    ),
                    const SizedBox(height: AppDimens.cardGap),
                    if (state.goals.isEmpty)
                      AppCard(
                        width: double.infinity,
                        padding: AppDimens.cardPaddingCompact,
                        onTap: () => _openEditor(context),
                        child: TrackerPrompt(
                          icon: Icons.flag_rounded,
                          title: 'Set your first goal',
                          message:
                              'Pick steps, distance, calories, active '
                              'minutes or workouts — daily or weekly.',
                          color: _metric.color,
                        ),
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
                        style: context.text.bodySmall?.copyWith(
                          color: context.vColors.grayText,
                        ),
                      ),
                    if (selected != null) ...[
                      const SizedBox(height: AppDimens.cardGap),
                      AppCard(
                        width: double.infinity,
                        padding: AppDimens.cardPaddingCompact,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: AppCaption(
                                    '${selected.goal.metric.label} trend',
                                  ),
                                ),
                                TrendRangeToggle(
                                  value: state.range,
                                  onChanged: cubit.load,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppDimens.cardInnerGap),
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
                      const SizedBox(height: AppDimens.cardGap),
                      TrackerInsightsCard(
                        insights: seriesInsights(
                          selected.series,
                          format: selected.goal.metric.formatWithUnit,
                          noun: 'your activity',
                        ),
                      ),
                    ],
                    const SizedBox(height: AppDimens.sectionGap),
                    TrackerSectionTitle(
                      'Workouts',
                      actionLabel: 'All',
                      onAction: () => context.pushNamed('activity-history'),
                    ),
                    const SizedBox(height: AppDimens.cardGap),
                    if (snapshot.sessions.isEmpty)
                      const AppInfoNote(
                        message: 'No workouts tracked in this period yet.',
                      ),
                    for (final s in snapshot.sessions) ...[
                      TrackerLogTile(
                        id: s.startTime.millisecondsSinceEpoch,
                        icon: _metric.icon,
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
