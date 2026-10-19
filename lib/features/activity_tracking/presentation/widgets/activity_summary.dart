import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/adaptive_row.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/fit_text.dart';
import 'package:vital_up/core/widgets/tracker/log_history_card.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_format_utils.dart';
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_type_ui.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/activity_target_result.dart';

/// One activity's summary, the same for every kind (GPS, timed, logged)
/// and wherever it shows (after a workout, from history): the activity and
/// when, its main figure (distance, or time without a route), the other
/// figures in equal columns, then the target result.
class ActivitySummary extends StatelessWidget {
  final ActivitySession session;

  const ActivitySummary({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final v = context.vColors;
    final time = formatDuration(
      Duration(seconds: session.totalDurationSeconds),
    );
    final steps = session.steps;
    final targetType = session.targetType;
    final targetValue = session.targetValue;

    final (headline, headlineUnit) = session.hasDistance
        ? (formatDistanceKm(session.totalDistanceMeters), 'km')
        : (time, 'time');
    final figures = [
      if (session.hasDistance) _Figure(value: time, label: 'Time'),
      _Figure(value: '${session.calories}', label: 'Calories'),
      if (session.hasDistance)
        _Figure(
          value: formatPace(session.avgPaceSecondsPerKm),
          label: 'Pace /km',
        ),
      if (session.intensity case final intensity?)
        _Figure(value: intensity.label, label: 'Effort'),
      if (session.hasDistance || steps > 0)
        _Figure(
          value: session.stepCountReliable ? '$steps' : '$steps*',
          label: 'Steps',
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            AppIconBadge(icon: Icon(activityTypeIcon(session.activityType))),
            const SizedBox(width: AppDimens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.activityType.label,
                    style: context.text.titleMedium?.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                  Text(
                    formatLogDateTime(session.startTime),
                    style: context.text.bodySmall?.copyWith(color: v.grayText),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.space16),
        AppCard(
          padding: AppDimens.cardPaddingCompact,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: AppDimens.space8,
                children: [
                  Text(
                    headline,
                    style: AppTextStyles.metricLarge.copyWith(
                      color: colors.onSurface,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    headlineUnit,
                    style: context.text.bodyLarge?.copyWith(color: v.grayText),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.space12),
              Divider(height: 1, color: v.glassBorder),
              const SizedBox(height: AppDimens.space12),
              AdaptiveRow(children: figures),
            ],
          ),
        ),
        if (targetType != null && targetValue != null && targetValue > 0) ...[
          const SizedBox(height: AppDimens.cardGap),
          ActivityTargetResultCard(
            achieved: session.targetAchieved,
            icon: session.targetAchieved
                ? Icons.emoji_events_rounded
                : Icons.flag_rounded,
            title: session.targetAchieved
                ? 'Target achieved'
                : 'Target not reached',
            subtitle:
                'Target: ${formatActivityTarget(targetType, targetValue)}',
          ),
        ],
        if (!session.stepCountReliable && steps > 0) ...[
          const SizedBox(height: AppDimens.space8),
          Text(
            '*Step count may be inaccurate for this session.',
            style: context.text.bodySmall?.copyWith(color: v.grayText),
          ),
        ],
      ],
    );
  }
}

/// A figure over its label, left-aligned so the columns line up.
class _Figure extends StatelessWidget {
  final String value;
  final String label;

  const _Figure({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FitText(
          value,
          maxLines: 1,
          style: context.text.titleSmall?.copyWith(
            color: context.colors.onSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: AppDimens.space2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.labelSmall?.copyWith(
            color: context.vColors.grayText,
          ),
        ),
      ],
    );
  }
}
