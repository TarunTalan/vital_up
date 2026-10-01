import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/dashboard/domain/entities/trend_series.dart';

/// Daily bar chart for dashboard trends.
///
/// `compact` is the 7-day strip on home cards: no axes or touch, weekday
/// initials under each bar, past days faded and today fully opaque.
/// Otherwise it's the detail-page chart: value axis, tooltips and a dashed
/// goal line.
class TrendBarChart extends StatelessWidget {
  final TrendSeries series;
  final Color color;
  final bool compact;

  /// Formats axis labels and tooltips (defaults to whole numbers).
  final String Function(double value)? valueFormatter;

  /// Value-axis labels when they differ from tooltips (e.g. emoji).
  final String Function(double value)? axisFormatter;

  /// Per-bar colour override, e.g. stress bars coloured by level.
  final Color Function(double value)? colorOf;

  const TrendBarChart({
    super.key,
    required this.series,
    required this.color,
    this.compact = false,
    this.valueFormatter,
    this.axisFormatter,
    this.colorOf,
  });

  String _format(double v) =>
      valueFormatter?.call(v) ?? NumberFormat.compact().format(v.round());

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final points = series.points;
    final dense = points.length > 14;
    final maxY = series.maxValue <= 0 ? 1.0 : series.maxValue * 1.15;
    final barWidth = compact
        ? AppDimens.chartBarWidthMini
        : dense
            ? AppDimens.chartBarWidthDense
            : AppDimens.chartBarWidth;
    final labelStyle = context.text.labelSmall?.copyWith(color: v.grayText);
    final goal = series.goal;
    // Custom axis labels sit on whole values (e.g. stress levels 1–5).
    final interval = axisFormatter != null ? 1.0 : maxY / 4;

    return SizedBox(
      height: compact ? AppDimens.miniChartHeight : AppDimens.trendChartHeight,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          minY: 0,
          alignment: BarChartAlignment.spaceAround,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: !compact,
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (_) => FlLine(
              color: v.divider,
              strokeWidth: AppDimens.hairline,
            ),
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              if (goal != null && goal > 0)
                HorizontalLine(
                  y: goal,
                  color: color,
                  strokeWidth: AppDimens.borderThin,
                  dashArray: const [
                    AppDimens.chartGoalDash,
                    AppDimens.chartGoalDash,
                  ],
                ),
            ],
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: !compact,
                reservedSize: AppDimens.chartAxisReserved,
                interval: interval,
                getTitlesWidget: (value, meta) {
                  if (value == meta.max) return const SizedBox.shrink();
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      axisFormatter?.call(value) ?? _format(value),
                      style: labelStyle,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: AppDimens.chartLabelReserved,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= points.length) {
                    return const SizedBox.shrink();
                  }
                  final isLast = i == points.length - 1;
                  // 30 days: label every 5th day, counted back from today.
                  if (dense && (points.length - 1 - i) % 5 != 0) {
                    return const SizedBox.shrink();
                  }
                  final day = points[i].day;
                  final text = dense
                      ? DateFormat('d').format(day)
                      : DateFormat('E').format(day).substring(0, 1);
                  return SideTitleWidget(
                    meta: meta,
                    space: AppDimens.space4,
                    child: Text(
                      text,
                      style: isLast
                          ? labelStyle?.copyWith(
                              color: context.colors.onSurface,
                              fontWeight: FontWeight.w600,
                            )
                          : labelStyle,
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            enabled: !compact,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => v.surfaceElevated!,
              getTooltipItem: (group, _, rod, _) {
                final point = points[group.x];
                if (point.value == null) return null;
                return BarTooltipItem(
                  '${DateFormat('EEE d MMM').format(point.day)}\n',
                  context.text.labelSmall!.copyWith(color: v.grayText),
                  children: [
                    TextSpan(
                      text: _format(point.value!),
                      style: context.text.titleSmall?.copyWith(
                        color: context.colors.onSurface,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          barGroups: [
            for (var i = 0; i < points.length; i++)
              _group(i, points[i], barWidth, maxY, v.track!,
                  isToday: i == points.length - 1),
          ],
        ),
        duration: AppDurations.medium,
      ),
    );
  }

  BarChartGroupData _group(
    int x,
    DailyPoint point,
    double width,
    double maxY,
    Color track, {
    required bool isToday,
  }) {
    final value = point.value ?? 0;
    final base = colorOf != null && point.value != null
        ? colorOf!(value)
        : color;
    final faded = compact && !isToday;
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: value,
          width: width,
          color: faded
              ? base.withValues(alpha: AppDimens.chartInactiveAlpha)
              : base,
          borderRadius: BorderRadius.circular(AppDimens.radiusXs),
          backDrawRodData: BackgroundBarChartRodData(
            show: compact,
            toY: maxY,
            color: track,
          ),
        ),
      ],
    );
  }
}
