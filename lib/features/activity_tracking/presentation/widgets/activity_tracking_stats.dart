import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/preferences/distance_unit_notifier.dart';
import 'package:vital_up/core/preferences/workout_prefs_notifier.dart';
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_format_utils.dart';

/// Card overlaid on top of the map showing the live duration, distance,
/// calories, and average pace while an activity is idle/in-progress/paused.
class TopStats extends StatelessWidget {
  final Duration elapsed;
  final double distanceMeters;
  final int calories;
  final int avgPace;
  final DistanceUnit distanceUnit;
  final int? heartRateBpm;
  final WorkoutPrefs workoutPrefs;
  final int steps;
  final double currentSpeed;
  final double elevationGain;

  final String activityTypeName;

  const TopStats({
    super.key,
    required this.elapsed,
    required this.distanceMeters,
    required this.calories,
    required this.avgPace,
    this.distanceUnit = DistanceUnit.km,
    this.heartRateBpm,
    this.workoutPrefs = const WorkoutPrefs(),
    this.steps = 0,
    this.currentSpeed = 0.0,
    this.elevationGain = 0.0,
    this.activityTypeName = 'Walk',
  });

  double get _targetProgress {
    final prefs = workoutPrefs;
    if (prefs.targetType == WorkoutTargetType.none || prefs.targetValue <= 0) {
      return -1;
    }
    if (prefs.targetType == WorkoutTargetType.distance) {
      final targetM = prefs.targetValue * 1000; // stored in km
      return (distanceMeters / targetM).clamp(0.0, 1.0);
    } else {
      return (calories / prefs.targetValue).clamp(0.0, 1.0);
    }
  }

  String get _targetLabel {
    final prefs = workoutPrefs;
    if (prefs.targetType == WorkoutTargetType.distance) {
      final val = distanceUnit == DistanceUnit.miles
          ? (prefs.targetValue / 1.60934)
          : prefs.targetValue;
      return '${val.toStringAsFixed(1)} ${distanceUnit.label}';
    }
    return '${prefs.targetValue.toStringAsFixed(0)} kcal';
  }

  (String, String) _getMetricData(StatMetric metric) {
    switch (metric) {
      case StatMetric.distance:
        return (
          formatDistance(distanceMeters, unit: distanceUnit),
          distanceUnit.distanceLabel.toUpperCase(),
        );
      case StatMetric.calories:
        return (calories.toString(), 'CALORIES');
      case StatMetric.avgPace:
        return (
          formatPace(avgPace, unit: distanceUnit),
          'AVG. PACE (${distanceUnit.paceLabel})'.toUpperCase(),
        );
      case StatMetric.currentSpeed:
        final factor = distanceUnit == DistanceUnit.miles ? 2.23694 : 3.6;
        final speedVal = currentSpeed * factor;
        final speedLabel = distanceUnit == DistanceUnit.miles ? 'MPH' : 'KM/H';
        return (speedVal.toStringAsFixed(1), 'SPEED ($speedLabel)');
      case StatMetric.steps:
        return (steps.toString(), 'STEPS');
      case StatMetric.elevationGain:
        final factor = distanceUnit == DistanceUnit.miles ? 3.28084 : 1.0;
        final elevVal = elevationGain * factor;
        final elevLabel = distanceUnit == DistanceUnit.miles ? 'FT' : 'M';
        return (elevVal.toStringAsFixed(0), 'ELEV. GAIN ($elevLabel)');
      case StatMetric.activityType:
        return (activityTypeName, 'ACTIVITY');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final v = context.vColors;
    final progress = _targetProgress;
    final hasBpm = heartRateBpm != null;

    final metrics = workoutPrefs.selectedMetrics.isEmpty
        ? const [StatMetric.distance, StatMetric.calories, StatMetric.avgPace]
        : workoutPrefs.selectedMetrics;

    // Chunk metrics into rows of up to 3 columns.
    final List<List<StatMetric>> rows = [];
    for (var i = 0; i < metrics.length; i += 3) {
      rows.add(
        metrics.sublist(i, (i + 3) > metrics.length ? metrics.length : i + 3),
      );
    }

    return ResponsiveCenter(
      child: AppCard(
        margin: context.pagePadding,
        padding: AppDimens.cardPaddingCompact,
        tint: v.surfaceElevated!.withValues(alpha: 0.9),
        blur: true,
        shadow: AppShadows.elevated,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Duration + optional BPM
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatDuration(elapsed),
                    style: AppTextStyles.metricLarge.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                  if (hasBpm) ...[
                    const SizedBox(width: AppDimens.space12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.space8,
                        vertical: AppDimens.space4,
                      ),
                      decoration: BoxDecoration(
                        color: v.errorFill,
                        borderRadius: BorderRadius.circular(
                          AppDimens.radiusPill,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.favorite_rounded,
                            color: colors.error,
                            size: AppDimens.iconXs,
                          ),
                          const SizedBox(width: AppDimens.space4),
                          Text(
                            '$heartRateBpm',
                            style: context.text.titleSmall?.copyWith(
                              color: colors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppDimens.space4),
            const AppCaption('Duration'),

            // Dynamic metric rows
            ...rows.map((rowMetrics) {
              return Padding(
                padding: const EdgeInsets.only(top: AppDimens.space12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: rowMetrics.map((metric) {
                    final (value, label) = _getMetricData(metric);
                    return Expanded(
                      child: StatColumn(value: value, label: label),
                    );
                  }).toList(),
                ),
              );
            }),

            // Target progress bar
            if (progress >= 0) ...[
              const SizedBox(height: AppDimens.space12),
              Row(
                children: [
                  Icon(
                    Icons.flag_rounded,
                    size: AppDimens.iconXs,
                    color: v.grayText,
                  ),
                  const SizedBox(width: AppDimens.space4),
                  Expanded(
                    child: AppProgressBar(
                      value: progress,
                      color: progress >= 1.0 ? v.success : colors.primary,
                    ),
                  ),
                  const SizedBox(width: AppDimens.space8),
                  Text(
                    _targetLabel,
                    style: context.text.labelSmall?.copyWith(
                      color: v.grayText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A single labeled value used inside [TopStats].
class StatColumn extends StatelessWidget {
  final String value;
  final String label;

  const StatColumn({super.key, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.space2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: context.text.headlineSmall?.copyWith(
                color: context.colors.onSurface,
              ),
            ),
          ),
          const SizedBox(height: AppDimens.space4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.text.labelSmall?.copyWith(
              color: context.vColors.grayText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
