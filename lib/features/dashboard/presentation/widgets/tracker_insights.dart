import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/features/dashboard/domain/entities/trend_series.dart';

/// One plain-language takeaway on a detail page.
class TrackerInsight {
  final IconData icon;
  final String text;

  const TrackerInsight(this.icon, this.text);
}

/// Pattern-based insights any daily series supports: a goal streak, the
/// recent trend and weekday vs weekend. Goal-met days and the best day are
/// left to [TrendStatsRow], which sits right above.
/// [format] renders a value with its unit and [noun] names what's logged
/// ("water", "your sleep"). Wording follows the series' goal direction, so
/// "down" reads as progress for screen time and stress.
List<TrackerInsight> seriesInsights(
  TrendSeries series, {
  required String Function(double value) format,
  required String noun,
}) {
  // A zero day (no steps, no water) counts as nothing logged here, so an
  // empty period asks for data instead of reporting "steady around 0".
  final logged = [
    for (final p in series.points)
      if ((p.value ?? 0) > 0) p,
  ];
  if (logged.length < 2) {
    return [
      TrackerInsight(
        Icons.insights_rounded,
        'Log $noun for a few days to unlock trends and patterns.',
      ),
    ];
  }

  final insights = <TrackerInsight>[];
  final goal = series.goal;
  final lowerIsBetter = series.direction == GoalDirection.down;

  // A near goal (weight) is a destination, not a daily target to streak.
  if (goal != null && goal > 0 && series.direction != GoalDirection.near) {
    final streak = _goalStreak(series);
    if (streak >= 2) {
      insights.add(
        TrackerInsight(
          Icons.flag_rounded,
          '$streak-day goal streak. Keep it going.',
        ),
      );
    }
  }

  // Recent half vs the half before it.
  final mid = series.points.length ~/ 2;
  final earlier = _avg(series.points.take(mid));
  final recent = _avg(series.points.skip(mid));
  if (earlier != null && recent != null && earlier > 0) {
    final change = (recent - earlier) / earlier;
    if (change.abs() >= 0.08) {
      final up = change > 0;
      final better = lowerIsBetter ? !up : up;
      insights.add(
        TrackerInsight(
          up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
          '${up ? 'Up' : 'Down'} ${(change.abs() * 100).round()}% lately '
          '(${format(recent)} vs ${format(earlier)} a day). '
          '${better ? 'Nice progress.' : 'Worth keeping an eye on.'}',
        ),
      );
    } else {
      insights.add(
        TrackerInsight(
          Icons.trending_flat_rounded,
          'Steady lately, around ${format(recent)} a day.',
        ),
      );
    }
  }

  final weekend = _avg(series.points.where((p) => p.day.weekday >= 6));
  final weekday = _avg(series.points.where((p) => p.day.weekday < 6));
  if (weekend != null && weekday != null && weekday > 0) {
    final diff = (weekend - weekday) / weekday;
    if (diff.abs() >= 0.15) {
      insights.add(
        TrackerInsight(
          Icons.weekend_rounded,
          'Weekends average ${format(weekend)}, '
          '${(diff.abs() * 100).round()}% ${diff > 0 ? 'more' : 'less'} '
          'than weekdays (${format(weekday)}).',
        ),
      );
    }
  }

  return insights;
}

double? _avg(Iterable<DailyPoint> points) {
  final values = points
      .map((p) => p.value)
      .whereType<double>()
      .where((v) => v.isFinite)
      .toList();
  if (values.isEmpty) return null;
  return values.reduce((a, b) => a + b) / values.length;
}

/// Consecutive goal-met days ending today (or yesterday, before today's
/// goal is reached).
int _goalStreak(TrendSeries series) {
  final goal = series.goal;
  if (goal == null) return 0;
  bool met(double? v) =>
      v != null &&
      switch (series.direction) {
        GoalDirection.up => v >= goal,
        GoalDirection.down => v <= goal,
        GoalDirection.near =>
          (v - goal).abs() <= goal * TrendSeries.nearTolerance,
      };
  final points = series.points.reversed.toList();
  var i = 0;
  if (points.isNotEmpty && !met(points.first.value)) i = 1;
  var streak = 0;
  for (; i < points.length && met(points[i].value); i++) {
    streak++;
  }
  return streak;
}

/// Highlighted card listing insights — Figma card/insight.
class TrackerInsightsCard extends StatelessWidget {
  final List<TrackerInsight> insights;

  const TrackerInsightsCard({super.key, required this.insights});

  @override
  Widget build(BuildContext context) {
    final onSurface = context.colors.onSurface;
    return AppCard(
      width: double.infinity,
      highlighted: true,
      padding: AppDimens.cardPaddingCompact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_rounded,
                size: AppDimens.iconSm,
                color: onSurface,
              ),
              const SizedBox(width: AppDimens.space6),
              AppCaption('Insights', color: onSurface),
            ],
          ),
          for (final insight in insights) ...[
            const SizedBox(height: AppDimens.space12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(insight.icon, size: AppDimens.iconMd, color: onSurface),
                const SizedBox(width: AppDimens.space12),
                Expanded(
                  child: Text(
                    insight.text,
                    style: context.text.bodyMedium?.copyWith(color: onSurface),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
