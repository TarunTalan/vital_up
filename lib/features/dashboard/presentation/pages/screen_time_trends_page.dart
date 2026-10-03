import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_widgets.dart';
import 'package:vital_up/features/dashboard/data/services/screen_time_service.dart';
import 'package:vital_up/features/dashboard/domain/entities/app_usage_info.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/screen_time_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/trend_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/dashboard_card_header.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/screen_time_card.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/tracker_detail_scaffold.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/tracker_goal_editors.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/tracker_insights.dart';

/// Screen time: today vs the daily limit, daily trend, the apps behind it
/// and each day's total. Read from the device, so there's no log button.
class ScreenTimeTrendsPage extends StatelessWidget {
  const ScreenTimeTrendsPage({super.key});

  static String formatMinutes(double minutes) =>
      formatDashboardDuration(Duration(minutes: minutes.round()));

  @override
  Widget build(BuildContext context) {
    const metric = TrackerMetric.screenTime;
    final service = sl<ScreenTimeService>();
    return BlocProvider(
      create: (_) => TrendCubit<DailyScreenTime>(service.trend)..load(),
      child: Builder(
        builder: (context) {
          final cubit = context.read<TrendCubit<DailyScreenTime>>();
          return TrackerDetailScaffold<DailyScreenTime>(
            metric: metric,
            noun: 'screen time',
            format: formatMinutes,
            axisFormat: (m) => '${(m / 60).round()}h',
            headerAction: AppHeaderAction(
              tooltip: 'Usage access settings',
              icon: const Icon(Icons.settings_rounded),
              onTap: context.read<ScreenTimeCubit>().openSettings,
            ),
            goalLabel: (data) => data.series.goal == null
                ? null
                : 'Daily limit · ${formatMinutes(data.series.goal!)}',
            onEditGoal: () async {
              if (await editScreenTimeGoal(context)) {
                cubit.load();
                if (context.mounted) {
                  context.read<ScreenTimeCubit>().loadStats();
                }
              }
            },
            insights: (data) => _topAppInsight(data.logs),
            sections: (context, data) => [
              AppCard(
                width: double.infinity,
                padding: AppDimens.cardPaddingCompact,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AppCaption('Top apps today'),
                    const SizedBox(height: AppDimens.space12),
                    TopAppsList(
                      apps: (data.logs.firstOrNull?.topApps ?? const [])
                          .take(6)
                          .toList(),
                    ),
                  ],
                ),
              ),
              const _BreakTipCard(),
            ],
            logsTitle: 'Daily totals',
            logBuilder: (context, day) => TrackerLogTile(
              id: day.date.millisecondsSinceEpoch,
              icon: metric.icon,
              color: day.duration.inMinutes > service.getDailyLimitMinutes()
                  ? context.colors.error
                  : metric.color,
              title: DateFormat('EEE d MMM').format(day.date),
              subtitle: day.topApps.isEmpty
                  ? 'No usage recorded'
                  : 'Most used: ${day.topApps.first.appName}',
              trailing: formatDashboardDuration(day.duration),
            ),
          );
        },
      ),
    );
  }

  /// The app that takes up the most of the period.
  static List<TrackerInsight> _topAppInsight(List<DailyScreenTime> days) {
    final totals = <String, Duration>{};
    var all = Duration.zero;
    for (final d in days) {
      all += d.duration;
      for (final app in d.topApps) {
        totals[app.appName] =
            (totals[app.appName] ?? Duration.zero) + app.usageDuration;
      }
    }
    if (totals.isEmpty || all.inMinutes == 0) return const [];
    final top = totals.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final share = (top.value.inMinutes / all.inMinutes * 100).round();
    return [
      TrackerInsight(
        Icons.apps_rounded,
        '${top.key} takes $share% of your screen time '
        '(${formatDashboardDuration(top.value)} in this period).',
      ),
    ];
  }
}

class _BreakTipCard extends StatelessWidget {
  const _BreakTipCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      width: double.infinity,
      padding: AppDimens.cardPaddingCompact,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIconBadge(
            color: AppColors.trackMood,
            icon: const Icon(Icons.self_improvement_rounded),
          ),
          const SizedBox(width: AppDimens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Vita tip', style: context.text.titleSmall),
                const SizedBox(height: AppDimens.space4),
                Text(
                  'Take a 5-minute eye break for every 45 minutes of '
                  'continuous phone use to reduce fatigue and help you fall '
                  'asleep faster.',
                  style: context.text.bodySmall?.copyWith(
                    color: context.vColors.grayText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
