import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/dashboard/domain/entities/trend_series.dart';

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
          style: context.text.bodySmall?.copyWith(
            color: context.vColors.grayText,
          ),
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
