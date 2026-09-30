import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/get_activity_history.dart';
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_format_utils.dart';
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_type_ui.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/activity_target_result.dart';

/// A single row in the activity history list: date/time, activity icon,
/// key stats, and an optional tag chip. Tapping the card opens details/edit
/// via [onTap]; long-pressing offers delete via [onDelete].
class ActivityHistoryCard extends StatelessWidget {
  final HistoryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const ActivityHistoryCard({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final v = context.vColors;
    final session = entry.session;
    final tag = entry.annotation?.tag;
    final targetValue = session.targetValue;
    final hasTarget =
        session.targetType != null && targetValue != null && targetValue > 0;

    return Dismissible(
      key: ValueKey(session.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        margin: EdgeInsets.symmetric(
          horizontal: context.gutter,
          vertical: AppDimens.space6,
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.space20),
        decoration: BoxDecoration(
          color: colors.error,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        child: Icon(Icons.delete_rounded, color: colors.onError),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Delete activity?'),
                content: const Text('This cannot be undone.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: TextButton.styleFrom(foregroundColor: colors.error),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => onDelete(),
      child: AppCard(
        onTap: onTap,
        margin: EdgeInsets.symmetric(
          horizontal: context.gutter,
          vertical: AppDimens.space6,
        ),
        padding: AppDimens.cardPaddingCompact,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIconBadge(icon: Icon(activityTypeIcon(session.activityType))),
            const SizedBox(width: AppDimens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppDimens.space8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        session.activityType.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleSmall?.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                      Text(
                        '${formatShortDate(session.startTime)} · ${formatTimeOfDay(session.startTime)}',
                        style: context.text.bodySmall?.copyWith(
                          color: v.grayText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.space8),
                  Wrap(
                    spacing: AppDimens.space12,
                    runSpacing: AppDimens.space4,
                    children: [
                      _MiniStat(
                        icon: Icons.straighten_rounded,
                        value:
                            '${formatDistanceKm(session.totalDistanceMeters)} km',
                      ),
                      _MiniStat(
                        icon: Icons.access_time_rounded,
                        value: formatDuration(
                          Duration(seconds: session.totalDurationSeconds),
                        ),
                      ),
                      _MiniStat(
                        icon: Icons.local_fire_department_rounded,
                        value: '${session.calories} cal',
                      ),
                    ],
                  ),
                  if ((tag != null && tag.isNotEmpty) || hasTarget) ...[
                    const SizedBox(height: AppDimens.space8),
                    Wrap(
                      spacing: AppDimens.space6,
                      runSpacing: AppDimens.space6,
                      children: [
                        if (tag != null && tag.isNotEmpty)
                          ActivityTagChip(label: tag),
                        if (hasTarget)
                          ActivityTargetChip(
                            label: formatActivityTarget(
                              session.targetType,
                              targetValue,
                            ),
                            achieved: session.targetAchieved,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: v.grayText),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;

  const _MiniStat({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppDimens.iconXs, color: context.vColors.grayText),
        const SizedBox(width: AppDimens.space4),
        Text(
          value,
          maxLines: 1,
          style: context.text.bodySmall?.copyWith(
            color: context.colors.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
