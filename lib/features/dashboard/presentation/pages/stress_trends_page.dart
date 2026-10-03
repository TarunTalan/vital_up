import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/date_range_utils.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_status.dart';
import 'package:vital_up/core/widgets/tracker/tracker_widgets.dart';
import 'package:vital_up/features/dashboard/data/services/trends_service.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/trend_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/mood_widgets.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/tracker_detail_scaffold.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/tracker_insights.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/tracker_log_sheets.dart';
import 'package:vital_up/features/vita/domain/entities/vita_insights.dart';

/// Mood & stress: today's check-in, the daily level, what's behind it and
/// every check-in. The goal is simply to check in each day.
class StressTrendsPage extends StatelessWidget {
  const StressTrendsPage({super.key});

  static String formatLevel(double level) =>
      StressCheckIn.labels[(level.round() - 1).clamp(0, 4)];

  @override
  Widget build(BuildContext context) {
    const metric = TrackerMetric.mood;
    return BlocProvider(
      create: (_) =>
          TrendCubit<StressCheckIn>(sl<TrendsService>().stress)..load(),
      child: Builder(
        builder: (context) {
          final cubit = context.read<TrendCubit<StressCheckIn>>();
          StressCheckIn? todayOf(List<StressCheckIn> logs) =>
              logs.where((c) => isSameDay(c.date, DateTime.now())).firstOrNull;

          return TrackerDetailScaffold<StressCheckIn>(
            metric: metric,
            noun: 'your mood',
            format: formatLevel,
            axisFormat: (v) => v == v.roundToDouble() && v >= 1 && v <= 5
                ? '${v.toInt()}'
                : '',
            colorOf: stressColor,
            headerAction: AppHeaderAction(
              tooltip: 'Stress guide',
              icon: const Icon(Icons.spa_rounded),
              onTap: () => context.pushNamed('vita-stress'),
            ),
            today: (data) {
              final today = todayOf(data.logs);
              final loggedDays = data.series.loggedDays;
              return TrackerToday(
                value: today?.label ?? 'Not yet',
                caption: today == null
                    ? 'Check in to see your trend'
                    : today.tags.isEmpty
                    ? 'Checked in today'
                    : today.tags.map((t) => t.label).join(', '),
                fraction: loggedDays / data.series.points.length,
                ringLabel: '$loggedDays/${data.series.points.length}',
                status: today == null
                    ? TrackerStatus.notLogged
                    : TrackerStatus.done,
                statusLabel: today == null ? null : 'Checked in',
              );
            },
            goalLabel: (_) => 'Goal · check in once a day',
            insights: (data) => _tagInsights(data.logs),
            sections: (context, data) => [_TagSummary(checkIns: data.logs)],
            logsTitle: 'Check-ins',
            emptyLogs: 'No check-ins yet. Tap Check in to log how you feel.',
            onLog: () async {
              if (await showMoodLogSheet(
                context,
                initial: todayOf(cubit.state.data?.logs ?? const []),
              )) {
                cubit.load();
              }
            },
            logBuilder: (context, c) => TrackerLogTile(
              id: c.date.millisecondsSinceEpoch,
              icon: moodIcon(c.level),
              color: stressColor(c.level),
              title: c.label,
              subtitle: [
                DateFormat('EEE d MMM').format(c.date),
                if (c.tags.isNotEmpty) c.tags.map((t) => t.label).join(', '),
              ].join(' · '),
            ),
          );
        },
      ),
    );
  }

  static List<TrackerInsight> _tagInsights(List<StressCheckIn> checkIns) {
    final stressed = checkIns.where((c) => c.level >= 4).toList();
    if (stressed.length < 2) return const [];
    final counts = <StressTag, int>{};
    for (final c in stressed) {
      for (final t in c.tags) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return const [];
    final top = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return [
      TrackerInsight(
        top.key.icon,
        '${top.key.label} came up on ${top.value} of your '
        '${stressed.length} stressful days.',
      ),
    ];
  }
}

/// Most frequent check-in tags in the selected range.
class _TagSummary extends StatelessWidget {
  final List<StressCheckIn> checkIns;

  const _TagSummary({required this.checkIns});

  @override
  Widget build(BuildContext context) {
    final counts = <StressTag, int>{};
    for (final c in checkIns) {
      for (final t in c.tags) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    final top = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return AppCard(
      width: double.infinity,
      padding: AppDimens.cardPaddingCompact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppCaption("What's been on your mind"),
          const SizedBox(height: AppDimens.space12),
          if (top.isEmpty)
            Text(
              'Add tags when you check in to spot patterns.',
              style: context.text.bodyMedium?.copyWith(
                color: context.vColors.grayText,
              ),
            )
          else
            Wrap(
              spacing: AppDimens.space8,
              runSpacing: AppDimens.space8,
              children: [
                for (final e in top) StressTagChip(e.key, suffix: '${e.value}'),
              ],
            ),
        ],
      ),
    );
  }
}
