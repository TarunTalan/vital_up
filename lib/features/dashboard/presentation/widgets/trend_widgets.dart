import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/dashboard/domain/entities/trend_series.dart';
import 'package:vital_up/core/widgets/fit_text.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_segmented_control.dart';

/// Daily / Weekly (/ Monthly) switch on trend detail pages.
class TrendRangeToggle extends StatelessWidget {
  final TrendRange value;
  final ValueChanged<TrendRange> onChanged;
  final List<TrendRange> ranges;

  const TrendRangeToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.ranges = TrendRange.standard,
  });

  @override
  Widget build(BuildContext context) {
    // The app's compact segmented control: the same small text as the
    // card's caption, instead of Material's larger button text.
    return AppSegmentedControl<TrendRange>(
      values: ranges,
      selected: value,
      label: (r) => r.label,
      onChanged: onChanged,
      compact: true,
    );
  }
}

/// Trend card on detail pages: what the chart shows ([title], e.g. "Last
/// 7 days", over a grey [caption]) with the range toggle, the bar chart,
/// then the average / best / goal readout, with the same spacing
/// everywhere. The toggle sits beside the title when both fit and moves
/// under it otherwise, so the title never squeezes into a narrow column.
class TrendChartCard extends StatelessWidget {
  final String title;
  final String? caption;
  final TrendRange range;
  final List<TrendRange> ranges;
  final ValueChanged<TrendRange> onRange;
  final Widget chart;
  final Widget stats;

  const TrendChartCard({
    super.key,
    required this.title,
    this.caption,
    required this.range,
    required this.onRange,
    required this.chart,
    required this.stats,
    this.ranges = TrendRange.standard,
  });

  @override
  Widget build(BuildContext context) {
    final caption = this.caption;
    return AppCard(
      width: double.infinity,
      padding: AppDimens.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppDimens.space16,
            runSpacing: AppDimens.space12,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.text.titleSmall?.copyWith(
                      color: context.colors.onSurface,
                    ),
                  ),
                  if (caption != null) ...[
                    const SizedBox(height: AppDimens.space2),
                    Text(
                      caption,
                      style: context.text.bodySmall?.copyWith(
                        color: context.vColors.grayText,
                      ),
                    ),
                  ],
                ],
              ),
              TrendRangeToggle(
                value: range,
                onChanged: onRange,
                ranges: ranges,
              ),
            ],
          ),
          const SizedBox(height: AppDimens.space24),
          chart,
          const SizedBox(height: AppDimens.space16),
          Divider(height: AppDimens.borderThin, color: context.vColors.divider),
          const SizedBox(height: AppDimens.space16),
          stats,
        ],
      ),
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
    if (series.direction == GoalDirection.near) {
      final values = [
        for (final p in series.points)
          if (p.value != null && p.value!.isFinite) p.value!,
      ];
      String of(double Function(double, double) pick) =>
          values.isEmpty ? '—' : format(values.reduce(pick));
      return Row(
        children: [
          Expanded(child: _Stat('Average', avg == null ? '—' : format(avg))),
          Expanded(child: _Stat('Lowest', of((a, b) => a < b ? a : b))),
          Expanded(child: _Stat('Highest', of((a, b) => a > b ? a : b))),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: _Stat('Average', avg == null ? '—' : format(avg))),
        Expanded(child: _Stat('Best', best == null ? '—' : format(best))),
        // Without a goal (mood), how often it was logged instead.
        Expanded(
          child: series.goal == null
              ? _Stat(
                  'Days logged',
                  '${series.loggedDays}/${series.points.length} days',
                )
              : _Stat(
                  'Goal met',
                  '${series.daysMetGoal}/${series.points.length} days',
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
          style: context.text.bodySmall?.copyWith(
            color: context.vColors.grayText,
          ),
        ),
        const SizedBox(height: AppDimens.space4),
        FitText(
          value,
          maxLines: 1,
          style: context.text.titleSmall?.copyWith(
            color: context.colors.onSurface,
          ),
        ),
      ],
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
