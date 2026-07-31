import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/auth/presentation/widgets/back_icon.dart';
import 'package:vital_up/features/auth/presentation/widgets/primary_auth_button.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_format_utils.dart';

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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) onBack();
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Center(
              child: BackIcon(
                onClick: onBack,
              ),
            ),
          ),
          title: Text(
            'ACTIVITY RESULT',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
              color: colors.onSurface,
            ),
          ),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/bg.png',
              fit: BoxFit.cover,
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppTheme.hPadding, 12, AppTheme.hPadding, 24),
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final customColors = theme.extension<VitalUpColors>();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.light 
                ? Colors.white.withValues(alpha: 0.72) 
                : colors.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: (theme.brightness == Brightness.light 
                  ? const Color(0xFFD8D8D8) 
                  : colors.outline).withValues(alpha: 0.72),
            ),
          ),
          child: Column(
            children: [
              Text(
                activityType.label.toUpperCase(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: customColors?.grayText ?? const Color(0xFF777777),
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                formatDistanceKm(distanceMeters),
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                  height: 1.0,
                ),
              ),
              Text(
                'KILOMETERS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: customColors?.grayText ?? const Color(0xFF777777),
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
                  ? colors.primary.withValues(alpha: 0.12)
                  : colors.outline.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: targetAchieved
                    ? colors.primary.withValues(alpha: 0.3)
                    : colors.outline.withValues(alpha: 0.3),
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
                      ? colors.primary
                      : customColors?.grayText ?? const Color(0xFFFF9800),
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
                          fontWeight: FontWeight.w600,
                          color: targetAchieved
                              ? colors.primary
                              : colors.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        targetType == 'distance'
                            ? '🎯 ${targetValue!.toStringAsFixed(1)} km'
                            : '🎯 ${targetValue!.toStringAsFixed(0)} kcal',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colors.onSurface.withValues(alpha: 0.7),
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
                      ? colors.primary
                      : customColors?.grayText ?? const Color(0xFFFF9800),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: SecondaryAuthButton(
                label: 'View History',
                onTap: onViewHistory,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: PrimaryAuthButton(
                label: 'New Activity',
                isLoading: false,
                onTap: onNewActivity,
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final customColors = theme.extension<VitalUpColors>();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.light 
            ? Colors.white.withValues(alpha: 0.72) 
            : colors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: (theme.brightness == Brightness.light 
              ? const Color(0xFFD8D8D8) 
              : colors.outline).withValues(alpha: 0.72),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: colors.primary),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: customColors?.grayText ?? const Color(0xFF777777),
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

