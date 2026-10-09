import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_format_utils.dart';
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_type_ui.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/activity_target_result.dart';

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
      child: AppScaffold(
        header: AppPageHeader(title: 'Activity Result', onBack: onBack),
        bottomBar: Row(
          children: [
            Expanded(
              child: AppSecondaryButton(
                label: 'View History',
                onTap: onViewHistory,
              ),
            ),
            const SizedBox(width: AppDimens.space12),
            Expanded(
              child: AppPrimaryButton(
                label: 'New Activity',
                onTap: onNewActivity,
              ),
            ),
          ],
        ),
        body: _CompletionStats(session: session),
      ),
    );
  }
}

class _CompletionStats extends StatelessWidget {
  final ActivitySession session;

  const _CompletionStats({required this.session});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final v = context.vColors;
    final targetType = session.targetType;
    final targetValue = session.targetValue;
    final achieved = session.targetAchieved;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: AppCaption(session.activityType.label)),
                  Icon(
                    activityTypeIcon(session.activityType),
                    color: colors.primary,
                    size: AppDimens.iconLg,
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.cardInnerGap),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: AppDimens.space12,
                children: [
                  Text(
                    formatDistanceKm(session.totalDistanceMeters),
                    style: AppTextStyles.metricLarge.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                  Text(
                    'kilometers',
                    style: context.text.bodyLarge?.copyWith(color: v.grayText),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.cardGap),
        Row(
          children: [
            Expanded(
              child: _CompletionStatCard(
                icon: Icons.access_time_rounded,
                label: 'Duration',
                value: formatDuration(
                  Duration(seconds: session.totalDurationSeconds),
                ),
              ),
            ),
            const SizedBox(width: AppDimens.cardGap),
            Expanded(
              child: _CompletionStatCard(
                icon: Icons.local_fire_department_rounded,
                label: 'Calories',
                value: '${session.calories}',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.cardGap),
        Row(
          children: [
            Expanded(
              child: _CompletionStatCard(
                icon: Icons.speed_rounded,
                label: 'Avg Pace',
                value: formatPace(session.avgPaceSecondsPerKm),
              ),
            ),
            const SizedBox(width: AppDimens.cardGap),
            Expanded(
              child: _CompletionStatCard(
                icon: Icons.directions_walk_rounded,
                label: 'Steps',
                value: '${session.steps}',
              ),
            ),
          ],
        ),
        if (targetType != null && targetValue != null && targetValue > 0) ...[
          const SizedBox(height: AppDimens.cardGap),
          ActivityTargetResultCard(
            achieved: achieved,
            icon: achieved ? Icons.emoji_events_rounded : Icons.flag_rounded,
            title: achieved ? 'Target achieved' : 'Target not reached',
            subtitle:
                'Target: ${formatActivityTarget(targetType, targetValue)}',
          ),
        ],
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
    return AppCard(
      padding: AppDimens.cardPaddingCompact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIconBadge(icon: Icon(icon)),
          const SizedBox(height: AppDimens.space12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySmall?.copyWith(
              color: context.vColors.grayText,
            ),
          ),
        ],
      ),
    );
  }
}
