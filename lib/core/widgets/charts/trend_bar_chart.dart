import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/dashboard/domain/entities/trend_series.dart';

/// Daily bar chart for dashboard trends.
///
/// The full chart is calm by design: one bar is selected (today by
/// default) and drawn in colour with its value above it; the others are
/// grey. Tapping a bar selects it, tapping it again (or today) goes back to
/// today. A series with a goal gets a dashed goal line across the bars,
/// named in a legend under the dates ("Goal 10K"), so the bars keep the
/// full width and the label never covers a bar. Dates
/// under the bars use one form that fits every bar. Long daily series (over
/// 14 days) date every 5th bar. The [compact] mini chart has no labels and
/// no taps.
class TrendBarChart extends StatefulWidget {
  final TrendSeries series;
  final Color color;
  final bool compact;
  final String Function(double value)? valueFormatter;
  final String Function(double value)? axisFormatter;
  final Color Function(double value)? colorOf;

  /// Bars are weeks ([TrendSeries.weekly]): labelled with their dates,
  /// with the week's daily average as the value.
  final bool weekly;

  /// Bars are calendar months ([TrendSeries.monthly]): labelled "Oct" over
  /// the year, with the month's average as the value.
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

  @override
  State<TrendBarChart> createState() => _TrendBarChartState();
}

class _TrendBarChartState extends State<TrendBarChart> {
  /// Selected bar; null means today (the last bar).
  int? _selected;

  /// Height of the bars area of the full chart; the labels above and
  /// below get their own room, which grows with the text size.
  static const double _barsHeight = AppDimens.trendChartHeight - 56;

  @override
  void didUpdateWidget(TrendBarChart old) {
    super.didUpdateWidget(old);
    // A new range or new data starts again from today.
    if (old.series != widget.series) _selected = null;
  }

  String _format(double v) =>
      widget.valueFormatter?.call(v) ??
      NumberFormat.compact().format(v.round());

  /// Date label forms for one bar, longest first: "Mon" / "13 Oct", then
  /// "Mon" / "13", then "M" / "13" for days; "10 Oct –" / "16 Oct", then
  /// "10" / "Oct" for weeks; "Oct" / "2026" for months. The chart uses the
  /// first form that fits every bar, so all labels match.
  List<String> _dayLabels(DateTime day, bool dense) {
    if (widget.monthly) {
      final month = DateFormat('MMM').format(day);
      return ['$month\n${DateFormat('y').format(day)}', month];
    }
    if (widget.weekly) {
      final end = DateTime(day.year, day.month, day.day + 6);
      final f = DateFormat('d MMM');
      return [
        '${f.format(day)} –\n${f.format(end)}',
        '${DateFormat('d').format(day)}\n${DateFormat('MMM').format(day)}',
      ];
    }
    if (dense) return [DateFormat('d').format(day)];
    final date = DateFormat('d').format(day);
    return [
      '${DateFormat('E').format(day)}\n${DateFormat('d MMM').format(day)}',
      '${DateFormat('E').format(day)}\n$date',
      '${DateFormat('EEEEE').format(day)}\n$date',
    ];
  }

  /// Full date of a bar for screen readers.
  String _when(DateTime day) {
    if (widget.monthly) return DateFormat('MMMM y').format(day);
    if (widget.weekly) {
      final end = DateTime(day.year, day.month, day.day + 6);
      return '${DateFormat('d MMM').format(day)} to '
          '${DateFormat('d MMM').format(end)}';
    }
    return DateFormat('EEEE d MMMM').format(day);
  }

  /// "Goal 10K", or "Limit 2h" for a goal to stay under.
  String _goalLabel(double goal) {
    final value = widget.axisFormatter?.call(goal) ?? _format(goal);
    return widget.series.direction == GoalDirection.down
        ? 'Limit $value'
        : 'Goal $value';
  }

  /// Widest line of [text] in [style] at the current text size.
  static double _textWidth(String text, TextStyle style, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  void _select(int index, int today) {
    HapticFeedback.selectionClick();
    setState(() {
      // Tapping the selected bar again goes back to today.
      _selected = index == (_selected ?? today) ? null : index;
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => _chart(context, constraints.maxWidth),
  );

  Widget _chart(BuildContext context, double width) {
    final v = context.vColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final compact = widget.compact;
    final series = widget.series;
    final points = series.points;
    final dense = points.length > 14;
    final today = points.length - 1;
    final selected = (_selected ?? today).clamp(0, points.isEmpty ? 0 : today);

    final goal = series.goal;
    final hasGoal = !compact && goal != null && goal > 0;
    // maxValue already includes the goal, so the goal line always fits.
    final maxY = series.maxValue <= 0 ? 1.0 : series.maxValue;
    // Label rooms sized from the real line height at the current text
    // size: two lines of dates below, one line for the value above.
    final scaler = MediaQuery.textScalerOf(context);
    final labelStyle = context.text.bodySmall!.copyWith(
      fontWeight: FontWeight.w700,
    );
    final lineHeight =
        scaler.scale(labelStyle.fontSize!) * (labelStyle.height ?? 1.35);
    final dayLabelHeight = (lineHeight * 2).ceilToDouble();
    final barLabelHeight = (lineHeight + AppDimens.space4).ceilToDouble();
    final dayLabelSpace = AppDimens.space8 + dayLabelHeight;
    final height = compact
        ? AppDimens.miniChartHeight
        : _barsHeight + dayLabelSpace + barLabelHeight;
    final maxBarHeight = compact ? height : _barsHeight;

    // Bars use the full width; the goal is named in a legend below.
    final barsWidth = width;

    // One date form for every bar: the longest that fits each slot.
    final slot = points.isEmpty
        ? barsWidth
        : barsWidth / points.length - AppDimens.space4;
    bool dated(int i) => !dense || (today - i) % 5 == 0;
    final forms = [for (final p in points) _dayLabels(p.day, dense)];
    var form = 0;
    if (forms.isNotEmpty) {
      while (form < forms.first.length - 1 &&
          [
            for (var i = 0; i < points.length; i++)
              if (dated(i)) forms[i][form],
          ].any((t) => _textWidth(t, labelStyle, scaler) > slot)) {
        form++;
      }
    }

    final minBarHeight = maxBarHeight * 0.15; // minimum height for 0 values
    final goalLineBottom = hasGoal
        ? dayLabelSpace +
              minBarHeight +
              (maxBarHeight - minBarHeight) * (goal / maxY).clamp(0.0, 1.0)
        : 0.0;

    final bars = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(points.length, (index) {
        final point = points[index];
        final isSelected = index == selected;
        final value = point.value ?? 0.0;
        final logged = point.value != null && value > 0;
        final fraction = (value / maxY).clamp(0.0, 1.0);
        final barHeight = logged
            ? (minBarHeight + (maxBarHeight - minBarHeight) * fraction)
            : (minBarHeight * 0.6);

        final baseColor = widget.colorOf?.call(value) ?? widget.color;
        final grey = isDark ? const Color(0xFF334155) : const Color(0xFFC4CBD1);
        final barColor = compact
            ? (index == today
                  ? baseColor
                  : baseColor.withValues(alpha: AppDimens.chartInactiveAlpha))
            : (isSelected ? baseColor : grey);

        // The selected bar's value; a tapped empty day says so.
        final valueLabel = compact || !isSelected
            ? null
            : logged
            ? _format(value)
            : (_selected == null ? null : 'No data');

        Widget bar = AnimatedContainer(
          duration: AppDurations.medium,
          curve: Curves.easeOutCubic,
          width: double.infinity,
          height: barHeight,
          margin: EdgeInsets.symmetric(
            horizontal: compact ? 1.0 : (dense ? 2.0 : 4.0),
          ),
          decoration: BoxDecoration(
            color: barColor,
            // Flat bottom corners, rounded top
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(6),
            ),
            boxShadow: isSelected && !compact
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

        if (compact) return Expanded(child: bar);

        final dateText = dated(index) ? forms[index][form] : null;
        final dateColor = isSelected ? context.colors.onSurface : v.grayText;
        final weight = isSelected ? FontWeight.w700 : FontWeight.w500;
        final spoken = logged
            ? '${_when(point.day)}: ${_format(value)}'
                  '${widget.monthly
                      ? ' average'
                      : widget.weekly
                      ? ' a day'
                      : ''}'
            : '${_when(point.day)}: no data';

        return Expanded(
          child: Semantics(
            button: true,
            selected: isSelected,
            label: spoken,
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _select(index, today),
              child: Column(
                children: [
                  // The value sits in the row above all bars, so it never
                  // covers a taller neighbour. One label only, so it may be
                  // wider than its bar; at the ends it lines up inward.
                  SizedBox(
                    height: barLabelHeight,
                    child: valueLabel == null
                        ? null
                        : OverflowBox(
                            maxWidth: double.infinity,
                            alignment: index == 0
                                ? Alignment.centerLeft
                                : index == today
                                ? Alignment.centerRight
                                : Alignment.center,
                            child: Text(
                              valueLabel,
                              maxLines: 1,
                              style: context.text.labelSmall?.copyWith(
                                color: context.colors.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                  ),
                  const Spacer(),
                  bar,
                  const SizedBox(height: AppDimens.space8),
                  SizedBox(
                    height: dayLabelHeight,
                    child: dateText == null
                        ? null
                        : Text(
                            dateText,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            softWrap: false,
                            style: context.text.bodySmall?.copyWith(
                              color: dateColor,
                              fontWeight: weight,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );

    if (!hasGoal) return SizedBox(height: height, child: bars);

    final lineColor = (v.grayText ?? widget.color).withValues(alpha: 0.7);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned.fill(child: bars),
              Positioned(
                left: 0,
                right: 0,
                bottom: goalLineBottom,
                child: IgnorePointer(
                  child: CustomPaint(
                    size: const Size.fromHeight(AppDimens.borderThin),
                    painter: _DashedLinePainter(lineColor),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.space8),
        // Legend: a short dashed line and "Goal 10K", under the dates.
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            CustomPaint(
              size: const Size(AppDimens.space16, AppDimens.borderThin),
              painter: _DashedLinePainter(lineColor),
            ),
            const SizedBox(width: AppDimens.space6),
            Flexible(
              child: Text(
                _goalLabel(goal),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall?.copyWith(color: v.grayText),
              ),
            ),
          ],
        ),
      ],
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
