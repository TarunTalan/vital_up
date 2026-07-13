import 'package:flutter/material.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_format_utils.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/activity_tracking_common_widgets.dart';

/// Full screen shown after an activity is stopped and saved. Displays the
/// finished session's stats with a back button in the top-left corner.
class ActivityCompletionPage extends StatelessWidget {
  final ActivitySession session;
  final VoidCallback onBack;
  final VoidCallback onNewActivity;
  final VoidCallback onViewHistory;

  const ActivityCompletionPage({
    super.key,
    required this.session,
    required this.onBack,
    required this.onNewActivity,
    required this.onViewHistory,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) onBack();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                child: RoundIconButton(
                  icon: Icons.arrow_back_rounded,
                  onPressed: onBack,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: _CompletionStats(
                    elapsed: Duration(seconds: session.totalDurationSeconds),
                    distanceMeters: session.totalDistanceMeters,
                    calories: session.calories,
                    avgPace: session.avgPaceSecondsPerKm,
                    steps: session.steps,
                    stepCountReliable: session.stepCountReliable,
                    activityType: session.activityType,
                    targetType: session.targetType,
                    targetValue: session.targetValue,
                    targetAchieved: session.targetAchieved,
                    onNewActivity: onNewActivity,
                    onViewHistory: onViewHistory,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletionStats extends StatelessWidget {
  final Duration elapsed;
  final double distanceMeters;
  final int calories;
  final int avgPace;
  final int steps;
  final bool stepCountReliable;
  final ActivityType activityType;
  final String? targetType;
  final double? targetValue;
  final bool targetAchieved;
  final VoidCallback onNewActivity;
  final VoidCallback onViewHistory;

  const _CompletionStats({
    required this.elapsed,
    required this.distanceMeters,
    required this.calories,
    required this.avgPace,
    required this.steps,
    required this.stepCountReliable,
    required this.activityType,
    this.targetType,
    this.targetValue,
    this.targetAchieved = false,
    required this.onNewActivity,
    required this.onViewHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                activityType.label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF777777),
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                formatDistanceKm(distanceMeters),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  height: 1.0,
                ),
              ),
              const Text(
                'KILOMETERS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF777777),
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _CompletionStatCard(
                icon: Icons.access_time_rounded,
                label: 'Duration',
                value: formatDuration(elapsed),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CompletionStatCard(
                icon: Icons.local_fire_department_rounded,
                label: 'Calories',
                value: '$calories',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _CompletionStatCard(
                icon: Icons.speed_rounded,
                label: 'Avg Pace',
                value: formatPace(avgPace),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CompletionStatCard(
                icon: Icons.directions_walk_rounded,
                label: 'Steps',
                value: '$steps',
              ),
            ),
          ],
        ),
        if (targetType != null && targetValue != null && targetValue! > 0) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: targetAchieved
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: targetAchieved
                    ? const Color(0xFF4CAF50).withValues(alpha: 0.3)
                    : const Color(0xFFFF9800).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  targetAchieved
                      ? Icons.emoji_events_rounded
                      : Icons.flag_rounded,
                  size: 28,
                  color: targetAchieved
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFFF9800),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        targetAchieved
                            ? 'Target Achieved! 🎉'
                            : 'Target Not Reached',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: targetAchieved
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFE65100),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        targetType == 'distance'
                            ? '🎯 ${targetValue!.toStringAsFixed(1)} km'
                            : '🎯 ${targetValue!.toStringAsFixed(0)} kcal',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF555555),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  targetAchieved
                      ? Icons.check_circle_rounded
                      : Icons.cancel_outlined,
                  size: 28,
                  color: targetAchieved
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFFF9800),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onViewHistory,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.black, width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'View History',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: onNewActivity,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'New Activity',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CompletionStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _CompletionStatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE3E3E3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: const Color(0xFF2BC7D8)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF777777),
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}