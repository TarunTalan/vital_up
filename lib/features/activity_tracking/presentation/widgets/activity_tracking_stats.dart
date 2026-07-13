import 'package:flutter/material.dart';
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
          distanceUnit.distanceLabel.toUpperCase()
        );
      case StatMetric.calories:
        return (calories.toString(), 'CALORIES');
      case StatMetric.avgPace:
        return (
          formatPace(avgPace, unit: distanceUnit),
          'AVG. PACE (${distanceUnit.paceLabel})'.toUpperCase()
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
    final progress = _targetProgress;
    final hasBpm = heartRateBpm != null;

    final metrics = workoutPrefs.selectedMetrics.isEmpty
        ? const [StatMetric.distance, StatMetric.calories, StatMetric.avgPace]
        : workoutPrefs.selectedMetrics;

    // Chunk metrics into rows of up to 3 columns.
    final List<List<StatMetric>> rows = [];
    for (var i = 0; i < metrics.length; i += 3) {
      rows.add(metrics.sublist(
        i,
        (i + 3) > metrics.length ? metrics.length : i + 3,
      ));
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Duration + optional BPM
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                formatDuration(elapsed),
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  color: Colors.black,
                ),
              ),
              if (hasBpm) ...[
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.favorite_rounded,
                          color: Colors.red, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '$heartRateBpm',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'DURATION',
            style: TextStyle(
              color: Color(0xFF9A9A9A),
              fontSize: 10,
              letterSpacing: 2.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),

          // Dynamic metric rows
          ...rows.map((rowMetrics) {
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: rowMetrics.map((metric) {
                  final (value, label) = _getMetricData(metric);
                  return Expanded(
                    child: StatColumn(
                      value: value,
                      label: label,
                    ),
                  );
                }).toList(),
              ),
            );
          }),

          // Target progress bar
          if (progress >= 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.flag_rounded, size: 12, color: Color(0xFF9A9A9A)),
                const SizedBox(width: 4),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFEEEEEE),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress >= 1.0 ? Colors.green : Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _targetLabel,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF666666),
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

/// A single labeled value used inside [TopStats].
class StatColumn extends StatelessWidget {
  final String value;
  final String label;

  const StatColumn({
    super.key,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1.0,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 2,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF9A9A9A),
            fontSize: 8.5,
            letterSpacing: 0.4,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}