import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
import 'package:vital_up/core/widgets/tracker/tracker_status.dart';
import 'package:vital_up/core/widgets/tracker/tracker_widgets.dart';
import 'package:vital_up/features/dashboard/domain/entities/trend_series.dart';
import 'package:vital_up/features/dashboard/domain/tracker_input_rules.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/trend_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/tracker_insights.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/trend_widgets.dart';
import 'package:vital_up/features/home_widget/home_widget_service.dart';

/// Swipe-to-delete for a detail page's history: removes [log] at once,
/// deletes it, reloads, and says so if it couldn't be deleted.
Future<void> deleteTrackerLog<L>(
  BuildContext context,
  TrendCubit<L> cubit,
  L log,
  Future<void> Function() delete,
) async {
  final ok = await cubit.deleteLog(log, delete);
  if (!ok && context.mounted) {
    showErrorSnackBar(context, "Couldn't delete that entry. Try again.");
  }
}

/// Today's readout on a detail page hero.
class TrackerToday {
  final String value;

  /// Line under the value, e.g. "of 2.5 L" or "11:00 PM – 7:00 AM".
  final String? caption;
  final double? fraction;
  final TrackerStatus status;
  final String? statusLabel;
  final Color? statusColor;

  /// Text in the ring; defaults to the percentage.
  final String? ringLabel;

  const TrackerToday({
    required this.value,
    required this.status,
    this.caption,
    this.fraction,
    this.statusLabel,
    this.statusColor,
    this.ringLabel,
  });
}

/// The one detail-page layout every tracker uses (Figma track/detail):
///
/// 1. Today — value, status and a ring against the goal, with the goal
///    and its Edit action underneath.
/// 2. Trend — 7D / 30D chart with a dashed goal line and stats.
/// 3. Insights — plain-language patterns.
/// 4. Metric-specific [sections] (macros, tags, top apps…).
/// 5. History — every entry in the range, swipe to delete.
///
/// The pinned bottom button is always the metric's log action.
/// Needs a [TrendCubit<L>] above it.
class TrackerDetailScaffold<L> extends StatelessWidget {
  final TrackerMetric metric;
  final String? title;
  final String Function(double value) format;
  final String Function(double value)? axisFormat;
  final Color Function(double value)? colorOf;

  /// Today's hero; defaults to the series' last point against its goal.
  final TrackerToday Function(TrendData<L> data)? today;
  final String heroLabel;

  /// "Daily goal · 2.5 L"; null shows "No goal set".
  final String? Function(TrendData<L> data)? goalLabel;
  final VoidCallback? onEditGoal;

  /// Noun for empty insights ("water", "your sleep").
  final String noun;

  /// Metric-specific insights shown before the generic ones.
  final List<TrackerInsight> Function(TrendData<L> data)? insights;

  /// Extra cards between Insights and History.
  final List<Widget> Function(BuildContext context, TrendData<L> data)?
  sections;

  final String logsTitle;
  final String emptyLogs;
  final Widget Function(BuildContext context, L log) logBuilder;
  final String? logsActionLabel;
  final VoidCallback? onLogsAction;

  /// Primary bottom action; defaults to the metric's log label.
  final VoidCallback? onLog;
  final String? logLabel;
  final Widget? headerAction;
  final Future<void> Function()? onRefresh;

  const TrackerDetailScaffold({
    super.key,
    required this.metric,
    required this.format,
    required this.logBuilder,
    required this.noun,
    this.title,
    this.axisFormat,
    this.colorOf,
    this.today,
    this.heroLabel = 'Today',
    this.goalLabel,
    this.onEditGoal,
    this.insights,
    this.sections,
    this.logsTitle = 'History',
    this.emptyLogs = 'Nothing logged in this period yet.',
    this.logsActionLabel,
    this.onLogsAction,
    this.onLog,
    this.logLabel,
    this.headerAction,
    this.onRefresh,
  });

  TrackerToday _defaultToday(TrendData<L> data) {
    final series = data.series;
    final value = series.today;
    final goal = series.goal;
    return TrackerToday(
      value: value == null ? '—' : format(value),
      caption: goal == null ? null : 'of ${format(goal)}',
      fraction: safeFraction(value, goal),
      status: TrackerStatus.of(
        value: value,
        goal: goal,
        direction: series.direction,
        paceFraction: series.direction == GoalDirection.up
            ? TrackerStatus.dayPace()
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TrendCubit<L>>();
    return AppScaffold(
      header: AppPageHeader(title: title ?? metric.label, action: headerAction),
      bottomBar: onLog == null
          ? null
          : AppPrimaryButton(
              label: logLabel ?? metric.logLabel,
              leadingIcon: Icon(metric.logIcon),
              onTap: onLog!,
            ),
      onRefresh:
          onRefresh ??
          () async {
            await cubit.load();
            try {
              await sl<HomeWidgetService>().refresh();
            } catch (_) {}
          },
      body: BlocBuilder<TrendCubit<L>, TrendState<L>>(
        builder: (context, state) {
          final data = state.data;
          if (data == null) {
            return SizedBox(
              height: AppDimens.trendChartHeight * 2,
              child: state.error != null
                  ? LoadErrorView(onRetry: cubit.load)
                  : TrackerLoading(color: metric.color),
            );
          }
          final now = (today ?? _defaultToday)(data);
          final extraInsights = insights?.call(data) ?? const [];
          final allInsights = [
            ...extraInsights,
            ...seriesInsights(data.series, format: format, noun: noun),
          ].take(4).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeroCard(
                metric: metric,
                label: heroLabel,
                today: now,
                goal: goalLabel?.call(data),
                onEditGoal: onEditGoal,
              ),
              const SizedBox(height: AppDimens.cardGap),
              _TrendCard(
                metric: metric,
                state: state,
                data: data,
                format: format,
                axisFormat: axisFormat,
                colorOf: colorOf,
                onRange: cubit.load,
              ),
              const SizedBox(height: AppDimens.cardGap),
              TrackerInsightsCard(insights: allInsights),
              for (final section in sections?.call(context, data) ?? []) ...[
                const SizedBox(height: AppDimens.cardGap),
                section,
              ],
              const SizedBox(height: AppDimens.sectionGap),
              TrackerSectionTitle(
                logsTitle,
                actionLabel: logsActionLabel,
                onAction: onLogsAction,
              ),
              const SizedBox(height: AppDimens.cardGap),
              if (data.logs.isEmpty)
                AppInfoNote(message: emptyLogs)
              else
                for (final log in data.logs) ...[
                  logBuilder(context, log),
                  const SizedBox(height: AppDimens.space8),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final TrackerMetric metric;
  final String label;
  final TrackerToday today;
  final String? goal;
  final VoidCallback? onEditGoal;

  const _HeroCard({
    required this.metric,
    required this.label,
    required this.today,
    required this.goal,
    required this.onEditGoal,
  });

  @override
  Widget build(BuildContext context) {
    final grey = context.vColors.grayText;
    final raw = today.fraction;
    // NaN / infinity would throw when rounded for the ring label.
    final fraction = raw != null && raw.isFinite ? raw : null;
    return AppCard(
      width: double.infinity,
      padding: AppDimens.cardPaddingCompact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppCaption(label),
                    const SizedBox(height: AppDimens.space8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        today.value,
                        maxLines: 1,
                        style: AppTextStyles.metricLarge.copyWith(
                          color: context.colors.onSurface,
                        ),
                      ),
                    ),
                    if (today.caption != null) ...[
                      const SizedBox(height: AppDimens.space4),
                      Text(
                        today.caption!,
                        style: context.text.bodyMedium?.copyWith(color: grey),
                      ),
                    ],
                    const SizedBox(height: AppDimens.space12),
                    TrackerStatusChip(
                      today.status,
                      label: today.statusLabel,
                      color: today.statusColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimens.space16),
              TrackerRing(
                fraction: fraction,
                color: today.statusColor ?? metric.color,
                center: today.ringLabel != null || fraction != null
                    ? Text(
                        today.ringLabel ?? '${(fraction! * 100).round()}%',
                        style: context.text.titleMedium?.copyWith(
                          color: context.colors.onSurface,
                        ),
                      )
                    : TrackerIcon(metric, size: AppDimens.iconXl),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.cardInnerGap),
          Divider(height: AppDimens.borderThin, color: context.vColors.divider),
          const SizedBox(height: AppDimens.space4),
          Row(
            children: [
              Icon(
                Icons.flag_rounded,
                size: AppDimens.iconSm,
                color: metric.color,
              ),
              const SizedBox(width: AppDimens.space8),
              Expanded(
                child: Text(
                  goal ?? 'No goal set',
                  style: context.text.bodyMedium?.copyWith(
                    color: goal == null ? grey : context.colors.onSurface,
                  ),
                ),
              ),
              if (onEditGoal != null)
                TextButton.icon(
                  onPressed: onEditGoal,
                  icon: goal == null
                      ? const Icon(Icons.add_rounded, size: AppDimens.iconSm)
                      : SvgPicture.asset(
                          'assets/icons/edit.svg',
                          width: AppDimens.iconSm,
                          height: AppDimens.iconSm,
                          colorFilter: ColorFilter.mode(
                            Theme.of(context).colorScheme.primary,
                            BlendMode.srcIn,
                          ),
                        ),
                  label: Text(goal == null ? 'Set goal' : 'Edit'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendCard<L> extends StatelessWidget {
  final TrackerMetric metric;
  final TrendState<L> state;
  final TrendData<L> data;
  final String Function(double value) format;
  final String Function(double value)? axisFormat;
  final Color Function(double value)? colorOf;
  final ValueChanged<TrendRange> onRange;

  const _TrendCard({
    required this.metric,
    required this.state,
    required this.data,
    required this.format,
    required this.axisFormat,
    required this.colorOf,
    required this.onRange,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      width: double.infinity,
      padding: AppDimens.cardPaddingCompact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: AppCaption(
                  state.range == TrendRange.week
                      ? '7-day trend'
                      : '30-day trend',
                ),
              ),
              TrendRangeToggle(value: state.range, onChanged: onRange),
            ],
          ),
          const SizedBox(height: AppDimens.cardInnerGap),
          TrendBarChart(
            series: data.series,
            color: metric.color,
            valueFormatter: format,
            axisFormatter: axisFormat,
            colorOf: colorOf,
          ),
          const SizedBox(height: AppDimens.cardInnerGap),
          TrendStatsRow(series: data.series, format: format),
        ],
      ),
    );
  }
}
