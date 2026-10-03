import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/dashboard/domain/entities/trend_series.dart';

/// Daily bar chart for dashboard trends.
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final points = series.points;
    final dense = points.length > 14;

    final maxY = series.maxValue <= 0 ? 1.0 : series.maxValue;
    final height = compact ? AppDimens.miniChartHeight : AppDimens.trendChartHeight;
    final maxBarHeight = height - (compact ? 0 : 24.0); // leave room for text labels
    final minBarHeight = maxBarHeight * 0.15; // minimum height for 0 values

    return SizedBox(
      height: height,
      child: Row(
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
              
          final text = dense
              ? DateFormat('d').format(point.day)
              : DateFormat('E').format(point.day).substring(0, 1);
              
          // Only show labels for some days if dense (every 5th day from the end)
          final showLabel = !dense || (points.length - 1 - index) % 5 == 0;
          
          final tooltipMessage = point.value != null
              ? '${DateFormat('EEE d MMM').format(point.day)}: ${_format(point.value!)}'
              : '${DateFormat('EEE d MMM').format(point.day)}: No data';

          Widget barWidget = AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            width: double.infinity,
            height: barHeight,
            margin: EdgeInsets.symmetric(horizontal: compact ? 1.0 : (dense ? 2.0 : 4.0)),
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
                barWidget,
                if (!compact) ...[
                  const SizedBox(height: AppDimens.space8),
                  SizedBox(
                    height: 16,
                    child: showLabel ? FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        text,
                        style: context.text.bodySmall?.copyWith(
                          color: isToday ? context.colors.onSurface : v.grayText,
                          fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 11,
                        ),
                      ),
                    ) : null,
                  ),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }
}
