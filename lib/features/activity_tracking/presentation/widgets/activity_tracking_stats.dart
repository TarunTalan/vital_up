import 'package:flutter/material.dart';
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_format_utils.dart';

/// Card overlaid on top of the map showing the live duration, distance,
/// calories, and average pace while an activity is idle/in-progress/paused.
class TopStats extends StatelessWidget {
  final Duration elapsed;
  final double distanceMeters;
  final int calories;
  final int avgPace;

  const TopStats({
    super.key,
    required this.elapsed,
    required this.distanceMeters,
    required this.calories,
    required this.avgPace,
  });

  @override
  Widget build(BuildContext context) {
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: StatColumn(
                  value: formatDistanceKm(distanceMeters),
                  label: 'DISTANCE (KM)',
                ),
              ),
              Expanded(
                child: StatColumn(
                  value: calories.toString(),
                  label: 'CALORIES (CAL)',
                ),
              ),
              Expanded(
                child: StatColumn(
                  value: formatPace(avgPace),
                  label: 'AVG. PACE (MIN/KM)',
                ),
              ),
            ],
          ),
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
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.0,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          maxLines: 2,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF9A9A9A),
            fontSize: 9,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}