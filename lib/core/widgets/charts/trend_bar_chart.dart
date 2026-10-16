import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/dashboard/domain/entities/trend_series.dart';

/// Daily bar chart for dashboard trends.
///
/// The full chart labels each logged bar: its share of the goal ("80%") when the
/// series has one, drawn with a dashed goal line, else the value itself.
/// Long daily series (over 14 days) label every 5th bar. The [compact] mini chart has
/// neither.
///
/// Refactored to exactly match the custom AnimatedContainer chart design
/// from the original Sleep Trends page (Figma-accurate).
class TrendBarChart extends StatelessWidget {
  final TrendSeries series;
  final Color color;
  final bool compact;
  final String Function(double value)? valueFormatter;
  final String Function(double value)? axisFormatter;
  final Color Function(double value)? colorOf;

  /// Bars are weeks ([TrendSeries.weekly]): labelled with their dates,
  /// with the week's daily average in the tooltip.
  final bool weekly;

  /// Bars are calendar months ([TrendSeries.monthly]): labelled "Oct" over
  /// the year, with the month's average in the tooltip.
  final bool monthly;

  const TrendBarChart({
    super.key,
    required this.series,
    required this.color,
    this.compact = false,
    this.valueFormatter,
    this.axisFormatter,
    this.colorOf,
    this.weekly = false,
    this.monthly = false,
  });

  String _format(double v) =>
      valueFormatter?.call(v) ?? NumberFormat.compact().format(v.round());

  /// "80%" of the goal, or the value when there is no goal.
  String _barLabel(double v, double? goal) =>
      goal != null && goal > 0 ? '${(v / goal * 100).round()}%' : _format(v);

  /// Date labels under the bars: "Mon" / "13 Oct" for days, "10 Oct –" /
  /// "16 Oct" for weeks, "Oct" / "2026" for months. Sized for two lines on every
  /// range so switching doesn't resize the bars.
  static const double _dayLabelHeight = 28;

  /// Gap + date label under the bars.
  static const double _dayLabelSpace = AppDimens.space8 + _dayLabelHeight;

  /// Date label for one bar.
  String _dayLabel(DateTime day, bool dense) {
    if (monthly) {
      return '${DateFormat('MMM').format(day)}\n${DateFormat('y').format(day)}';
    }
    if (weekly) {
      final end = DateTime(day.year, day.month, day.day + 6);
      final f = DateFormat('d MMM');
      return '${f.format(day)} –\n${f.format(end)}';
    }
    if (dense) return DateFormat('d').format(day);
    return '${DateFormat('E').format(day)}\n${DateFormat('d MMM').format(day)}';
  }

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final points = series.points;
    final dense = points.length > 14;

    final goal = series.goal;
    final hasGoal = !compact && goal != null && goal > 0;
    // maxValue already includes the goal, so the goal line always fits.
    final maxY = series.maxValue <= 0 ? 1.0 : series.maxValue;
    final height = compact
        ? AppDimens.miniChartHeight
        : AppDimens.trendChartHeight;
    // Room for the day labels below and the bar labels above.
    final maxBarHeight =
        height - (compact ? 0 : _dayLabelSpace + AppDimens.chartLabelReserved);
    final minBarHeight = maxBarHeight * 0.15; // minimum height for 0 values
    final goalLineBottom = hasGoal
        ? _dayLabelSpace +
              minBarHeight +
              (maxBarHeight - minBarHeight) * (goal / maxY).clamp(0.0, 1.0)
        : 0.0;

    final bars = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(points.length, (index) {
        final point = points[index];
        final isToday = index == points.length - 1;

        final value = point.value ?? 0.0;
        final fraction = (value / maxY).clamp(0.0, 1.0);
        final barHeight = value > 0
            ? (minBarHeight + (maxBarHeight - minBarHeight) * fraction)
            : (minBarHeight * 0.6);

        final baseColor = colorOf?.call(value) ?? color;

        // Figma colors: Gray for previous days, vibrant color for active/today
        final barColor = isToday
            ? baseColor
            : (isDark ? const Color(0xFF334155) : const Color(0xFFC4CBD1));

        final text = _dayLabel(point.day, dense);

        // Only show labels for some days if dense (every 5th day from the end)
        final showLabel = !dense || (points.length - 1 - index) % 5 == 0;
        // Days with nothing logged (null, or 0 for water) get no label.
        final barLabel = !compact && showLabel && (point.value ?? 0) > 0
            ? _barLabel(point.value!, goal)
            : null;

        final when = monthly
            ? DateFormat('MMMM y').format(point.day)
            : weekly
            ? '${DateFormat('d MMM').format(point.day)} – '
                  '${DateFormat('d MMM').format(DateTime(point.day.year, point.day.month, point.day.day + 6))}'
            : DateFormat('EEE d MMM').format(point.day);
        final tooltipMessage = point.value != null
            ? '$when: ${_format(point.value!)}'
                  '${monthly ? ' average' : weekly ? ' a day' : ''}'
            : '$when: No data';

        Widget barWidget = AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          height: barHeight,
          margin: EdgeInsets.symmetric(
            horizontal: compact ? 1.0 : (dense ? 2.0 : 4.0),
          ),
          decoration: BoxDecoration(
            color: compact && !isToday
                ? baseColor.withValues(alpha: AppDimens.chartInactiveAlpha)
                : barColor,
            // Flat bottom corners, rounded top
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(6),
            ),
            boxShadow: isToday && !compact
                ? [
                    BoxShadow(
                      color: baseColor.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
        );

        if (!compact) {
          barWidget = Tooltip(
            message: tooltipMessage,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
              },
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
              child: barWidget,
            ),
          );
        }

        return Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (barLabel != null)
                SizedBox(
                  height: AppDimens.chartLabelReserved,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      barLabel,
                      maxLines: 1,
                      style: context.text.labelSmall?.copyWith(
                        color: isToday ? context.colors.onSurface : v.grayText,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              barWidget,
              if (!compact) ...[
                const SizedBox(height: AppDimens.space8),
                SizedBox(
                  height: _dayLabelHeight,
                  child: showLabel
                      ? FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.topCenter,
                          child: Text(
                            text,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: context.text.bodySmall?.copyWith(
                              color: isToday
                                  ? context.colors.onSurface
                                  : v.grayText,
                              fontWeight: isToday
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 11,
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ],
          ),
        );
      }),
    );

    return SizedBox(
      height: height,
      child: hasGoal
          ? Stack(
              children: [
                Positioned.fill(child: bars),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: goalLineBottom,
                  child: IgnorePointer(
                    child: CustomPaint(
                      size: const Size.fromHeight(AppDimens.borderThin),
                      painter: _DashedLinePainter(
                        (v.grayText ?? color).withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : bars,
    );
  }
}

/// Horizontal dashed goal line.
class _DashedLinePainter extends CustomPainter {
  final Color color;

  const _DashedLinePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = AppDimens.borderThin;
    const dash = AppDimens.chartGoalDash * 1.0;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += dash * 2) {
      canvas.drawLine(Offset(x, y), Offset(x + dash, y), paint);
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) => old.color != color;
}
