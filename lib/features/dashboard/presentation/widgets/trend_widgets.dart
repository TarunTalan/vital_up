import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/charts/trend_bar_chart.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/features/dashboard/domain/entities/trend_series.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/trend_cubit.dart';
import 'package:vital_up/features/home_widget/home_widget_service.dart';

/// 7D / 30D switch on trend detail pages.
class TrendRangeToggle extends StatelessWidget {
  final TrendRange value;
  final ValueChanged<TrendRange> onChanged;

  const TrendRangeToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<TrendRange>(
      showSelectedIcon: false,
      segments: [
        for (final r in TrendRange.values)
          ButtonSegment(value: r, label: Text(r.label)),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

/// Average / best / goal-met readout under a trend chart.
class TrendStatsRow extends StatelessWidget {
  final TrendSeries series;
  final String Function(double value) format;

  const TrendStatsRow({super.key, required this.series, required this.format});

  @override
  Widget build(BuildContext context) {
    final avg = series.average;
    final best = series.best;
    return Row(
      children: [
        Expanded(child: _Stat('Average', avg == null ? '—' : format(avg))),
        Expanded(child: _Stat('Best', best == null ? '—' : format(best))),
        Expanded(
          child: _Stat(
            'Goal met',
            series.goal == null
                ? '—'
                : '${series.daysMetGoal}/${series.points.length} days',
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.text.bodySmall?.copyWith(color: context.vColors.grayText),
        ),
        const SizedBox(height: AppDimens.space4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: context.text.titleMedium?.copyWith(
              color: context.colors.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

/// 7-day mini chart on a dashboard card, fed by a [TrendCubit].
class MiniTrend<L> extends StatelessWidget {
  final Color color;
  final String Function(double value)? valueFormatter;
  final Color Function(double value)? colorOf;

  const MiniTrend({
    super.key,
    required this.color,
    this.valueFormatter,
    this.colorOf,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TrendCubit<L>, TrendState<L>>(
      builder: (context, state) {
        final data = state.data;
        if (data == null) {
          return const SizedBox(height: AppDimens.miniChartHeight);
        }
        return TrendBarChart(
          series: data.series,
          color: color,
          compact: true,
          valueFormatter: valueFormatter,
          colorOf: colorOf,
        );
      },
    );
  }
}

/// Shared layout of the trend detail pages: range toggle, chart card with
/// stats, an optional goal section, then the logs list.
class TrendDetailScaffold<L> extends StatelessWidget {
  final String title;
  final Color color;
  final String Function(double value) format;
  final String Function(double value)? axisFormat;
  final Color Function(double value)? colorOf;

  /// Shown between the chart and the logs, e.g. a goal stepper.
  final Widget Function(BuildContext context, TrendData<L> data)? header;
  final String logsTitle;
  final Widget Function(BuildContext context, L log) logBuilder;
  final String emptyLogs;
  final Widget? bottomBar;
  final Future<void> Function()? onRefresh;

  const TrendDetailScaffold({
    super.key,
    required this.title,
    required this.color,
    required this.format,
    required this.logBuilder,
    this.axisFormat,
    this.colorOf,
    this.header,
    this.logsTitle = 'Logs',
    this.emptyLogs = 'Nothing logged in this period yet.',
    this.bottomBar,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TrendCubit<L>>();
    return AppScaffold(
      header: AppPageHeader(title: title),
      bottomBar: bottomBar,
      onRefresh: onRefresh ??
          () async {
            await cubit.load();
            try {
              await sl<HomeWidgetService>().refresh();
            } catch (_) {}
          },
      body: BlocBuilder<TrendCubit<L>, TrendState<L>>(
        builder: (context, state) {
          final data = state.data;
          final cubit = context.read<TrendCubit<L>>();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TrendRangeToggle(value: state.range, onChanged: cubit.load),
              ),
              const SizedBox(height: AppDimens.cardGap),
              AppCard(
                width: double.infinity,
                child: data == null
                    ? SizedBox(
                        height: AppDimens.trendChartHeight,
                        child: state.error != null
                            ? LoadErrorView(onRetry: cubit.load)
                            : const Center(child: CircularProgressIndicator()),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TrendBarChart(
                            series: data.series,
                            color: color,
                            valueFormatter: format,
                            axisFormatter: axisFormat,
                            colorOf: colorOf,
                          ),
                          const SizedBox(height: AppDimens.cardInnerGap),
                          TrendStatsRow(series: data.series, format: format),
                        ],
                      ),
              ),
              if (data != null && header != null) ...[
                const SizedBox(height: AppDimens.cardGap),
                header!(context, data),
              ],
              const SizedBox(height: AppDimens.sectionGap),
              Text(logsTitle, style: context.text.headlineSmall),
              const SizedBox(height: AppDimens.cardGap),
              if (data != null && data.logs.isEmpty)
                AppInfoNote(message: emptyLogs)
              else if (data != null)
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

/// Goal row with − / + steppers, used on the trend pages.
class GoalStepperCard extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  const GoalStepperCard({
    super.key,
    required this.label,
    required this.value,
    this.onDecrease,
    this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      width: double.infinity,
      padding: AppDimens.cardPaddingCompact,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: context.text.bodySmall
                      ?.copyWith(color: context.vColors.grayText),
                ),
                const SizedBox(height: AppDimens.space4),
                Text(value, style: context.text.titleMedium),
              ],
            ),
          ),
          IconButton.outlined(
            tooltip: 'Decrease',
            onPressed: onDecrease,
            icon: const Icon(Icons.remove_rounded),
          ),
          const SizedBox(width: AppDimens.space8),
          IconButton.outlined(
            tooltip: 'Increase',
            onPressed: onIncrease,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

/// Plain log row: leading icon, title/subtitle, trailing value.
class TrendLogTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final String trailing;

  const TrendLogTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.trailing,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      width: double.infinity,
      sheen: false,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.space16,
        vertical: AppDimens.space12,
      ),
      child: Row(
        children: [
          AppIconBadge(
            color: color,
            icon: Icon(icon, size: AppDimens.iconMd, color: color),
          ),
          const SizedBox(width: AppDimens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleSmall),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: context.text.bodySmall
                        ?.copyWith(color: context.vColors.grayText),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppDimens.space8),
          Text(trailing, style: context.text.titleSmall),
        ],
      ),
    );
  }
}

/// "View trends ›" link used as a dashboard card header trailing.
class CardLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const CardLink({super.key, required this.onTap, this.label = 'Trends'});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.space8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const Icon(Icons.chevron_right_rounded, size: AppDimens.iconMd),
        ],
      ),
    );
  }
}
