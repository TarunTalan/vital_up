import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/adaptive_row.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/fit_text.dart';
import 'package:vital_up/core/widgets/tracker/log_history_card.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/get_activity_history.dart';
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_format_utils.dart';
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_type_ui.dart';

/// One activity in the history: its icon, type and when, then three
/// figures in equal columns (distance, time and calories; time, calories
/// and effort for workouts without a route). One accent only, on the icon.
/// Tapping opens the details (target, notes); the bin deletes.
class ActivityHistoryCard extends StatelessWidget {
  final HistoryEntry entry;
  final VoidCallback onTap;

  /// Null on read-only lists: no delete button.
  final VoidCallback? onDelete;

  const ActivityHistoryCard({
    super.key,
    required this.entry,
    required this.onTap,
    this.onDelete,
  });

  Future<void> _confirmDelete(BuildContext context) async {
    final delete = await showSmoothDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this activity?'),
        content: const Text('It will be removed from your history and totals.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: dialogContext.colors.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (delete == true) onDelete?.call();
  }

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final session = entry.session;
    final tag = entry.annotation?.tag;
    final time = formatDuration(
      Duration(seconds: session.totalDurationSeconds),
    );
    final calories = _Figure(value: '${session.calories}', label: 'Calories');
    final figures = session.hasDistance
        ? [
            _Figure(
              value: formatDistanceKm(session.totalDistanceMeters),
              label: 'km',
            ),
            _Figure(value: time, label: 'Time'),
            calories,
          ]
        : [
            _Figure(value: time, label: 'Time'),
            calories,
            _Figure(value: session.intensity?.label ?? '–', label: 'Effort'),
          ];

    return AppCard(
      onTap: onTap,
      padding: AppDimens.cardPaddingCompact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                      style: context.text.titleSmall?.copyWith(
                        color: context.colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppDimens.space2),
                    Text(
                      formatLogDateTime(session.startTime),
                      style: context.text.bodySmall?.copyWith(
                        color: v.grayText,
                      ),
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  tooltip: 'Delete',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _confirmDelete(context),
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: AppDimens.iconMd,
                    color: v.grayText,
                  ),
                ),
            ],
          ),
          if (tag != null && tag.isNotEmpty) ...[
            const SizedBox(height: AppDimens.space8),
            Text(
              tag,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.onSurface,
              ),
            ),
          ],
          const SizedBox(height: AppDimens.space12),
          Divider(height: 1, color: v.glassBorder),
          const SizedBox(height: AppDimens.space12),
          AdaptiveRow(children: figures),
        ],
      ),
    );
  }
}

/// A figure over its label, both left-aligned so the columns line up.
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
