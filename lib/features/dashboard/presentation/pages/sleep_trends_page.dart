import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_status.dart';
import 'package:vital_up/core/widgets/tracker/tracker_widgets.dart';
import 'package:vital_up/features/dashboard/data/services/sleep_service.dart';
import 'package:vital_up/features/dashboard/data/services/trends_service.dart';
import 'package:vital_up/features/dashboard/domain/entities/sleep_session_info.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/trend_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/dashboard_card_header.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/sleep_card.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/tracker_detail_scaffold.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/tracker_goal_editors.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/tracker_insights.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/tracker_log_sheets.dart';
import 'package:vital_up/features/home_widget/home_widget_service.dart';

/// Sleep: last night vs the nightly goal, the nightly trend, recovery
/// figures and every night logged or synced.
class SleepTrendsPage extends StatelessWidget {
  const SleepTrendsPage({super.key});

  static String formatHours(double hours) =>
      formatDashboardDuration(Duration(minutes: (hours * 60).round()));

  @override
  Widget build(BuildContext context) {
    const metric = TrackerMetric.sleep;
    final time = DateFormat.jm();
    return BlocProvider(
      create: (_) =>
          TrendCubit<SleepSessionInfo>(sl<TrendsService>().sleep)..load(),
      child: Builder(
        builder: (context) {
          final cubit = context.read<TrendCubit<SleepSessionInfo>>();
          return TrackerDetailScaffold<SleepSessionInfo>(
            metric: metric,
            noun: 'your sleep',
            format: formatHours,
            heroLabel: 'Last night',
            today: (data) {
              final night = data.logs.firstOrNull;
              final goal = data.series.goal;
              final hours = night == null
                  ? null
                  : night.duration.inMinutes / 60;
              return TrackerToday(
                value: night == null
                    ? '—'
                    : formatDashboardDuration(night.duration),
                caption: night == null
                    ? 'Log last night to see your trend'
                    : '${time.format(night.bedTime)} – '
                          '${time.format(night.wakeTime)}',
                fraction: hours == null || goal == null ? null : hours / goal,
                // The night is over, so judge it against the whole goal.
                status: TrackerStatus.of(value: hours, goal: goal, paceFraction: 1),
                ringLabel: night == null ? null : '${night.sleepScore}',
                statusColor: night == null
                    ? null
                    : sleepScoreColor(night.sleepScore),
                statusLabel: night == null
                    ? null
                    : 'Score ${night.sleepScore} · ${night.scoreCategory}',
              );
            },
            goalLabel: (data) => data.series.goal == null
                ? null
                : 'Nightly goal · ${formatHours(data.series.goal!)}',
            onEditGoal: () async {
              if (await editSleepGoal(context)) cubit.load();
            },
            insights: (data) => _bedtimeInsights(data.logs),
            sections: (context, data) => [
              if (data.logs.firstOrNull?.hasStages ?? false)
                AppCard(
                  width: double.infinity,
                  padding: AppDimens.cardPaddingCompact,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AppCaption('Last night’s stages'),
                      const SizedBox(height: AppDimens.space12),
                      SleepStagesBar(session: data.logs.first),
                    ],
                  ),
                ),
              const _RecoveryCard(),
            ],
            logsTitle: 'Nights',
            onLog: () async {
              if (await showSleepLogSheet(context)) {
                await cubit.load();
                try {
                  await sl<HomeWidgetService>().refresh();
                } catch (_) {}
              }
            },
            logBuilder: (context, night) => TrackerLogTile(
              id: night.bedTime.millisecondsSinceEpoch,
              icon: night.source == SleepDataSource.healthStore
                  ? Icons.watch_rounded
                  : metric.icon,
              color: sleepScoreColor(night.sleepScore),
              title: DateFormat('EEE d MMM').format(night.wakeTime),
              subtitle:
                  '${time.format(night.bedTime)} – '
                  '${time.format(night.wakeTime)} · '
                  'Score ${night.sleepScore} (${night.scoreCategory})',
              trailing: formatDashboardDuration(night.duration),
            ),
          );
        },
      ),
    );
  }

  /// Typical bedtime and how much it moves around.
  static List<TrackerInsight> _bedtimeInsights(List<SleepSessionInfo> logs) {
    if (logs.length < 3) return const [];
    // Minutes from noon, so 11 pm and 1 am sit close together.
    int fromNoon(DateTime t) => (t.hour * 60 + t.minute - 12 * 60) % (24 * 60);
    final minutes = [for (final n in logs) fromNoon(n.bedTime)];
    final avg = minutes.reduce((a, b) => a + b) / minutes.length;
    final spread =
        minutes.map((m) => (m - avg).abs()).reduce((a, b) => a + b) /
        minutes.length;
    final typical = DateTime(
      2000,
      1,
      1,
      12,
    ).add(Duration(minutes: avg.round()));
    return [
      TrackerInsight(
        Icons.nightlight_round,
        'You usually go to bed around ${DateFormat.jm().format(typical)}'
        '${spread > 45 ? ', but it varies by about ${spread.round()} min. '
                  'A steadier bedtime improves deep sleep.' : ' — nice and consistent.'}',
      ),
    ];
  }
}

/// Weekly recovery figures: average score, consistency and sleep debt.
class _RecoveryCard extends StatelessWidget {
  const _RecoveryCard();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SleepStats>(
      future: sl<SleepService>().getWeeklyStats(),
      builder: (context, snap) {
        final stats = snap.data;
        if (stats == null || stats.nightsLogged == 0) {
          return const SizedBox.shrink();
        }
        return AppCard(
          width: double.infinity,
          padding: AppDimens.cardPaddingCompact,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppCaption('This week'),
              const SizedBox(height: AppDimens.space12),
              TrackerFigureRow(
                figures: [
                  TrackerFigure(
                    label: 'Avg score',
                    value: '${stats.averageScore}',
                    icon: Icons.star_rounded,
                    color: sleepScoreColor(stats.averageScore),
                  ),
                  TrackerFigure(
                    label: 'Consistency',
                    value: '${stats.consistencyScore}%',
                    icon: Icons.schedule_rounded,
                  ),
                  TrackerFigure(
                    label: 'Sleep debt',
                    value: formatDashboardDuration(stats.totalSleepDebt),
                    icon: Icons.battery_alert_rounded,
                    color: stats.totalSleepDebt.inMinutes > 90
                        ? context.vColors.warning
                        : null,
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
