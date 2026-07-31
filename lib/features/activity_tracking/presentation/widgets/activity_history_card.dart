import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/get_activity_history.dart';
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_format_utils.dart';
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_type_ui.dart';

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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final customColors = theme.extension<VitalUpColors>();
    final session = entry.session;
    final tag = entry.annotation?.tag;

    return Dismissible(
      key: ValueKey(session.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: colors.error,
        child: const Icon(Icons.delete_rounded, color: Colors.white),
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
                child: Text('Delete', style: TextStyle(color: colors.error)),
              ),
            ],
          ),
        ) ??
            false;
      },
      onDismissed: (_) => onDelete(),
      child: InkWell(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(14),
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  activityTypeIcon(session.activityType),
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            session.activityType.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: colors.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${formatShortDate(session.startTime)} · ${formatTimeOfDay(session.startTime)}',
                          style: TextStyle(
                            color: customColors?.grayText ?? const Color(0xFF9A9A9A),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniStat(
                            icon: Icons.straighten_rounded,
                            value: '${formatDistanceKm(session.totalDistanceMeters)} km',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MiniStat(
                            icon: Icons.access_time_rounded,
                            value: formatDuration(
                              Duration(seconds: session.totalDurationSeconds),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MiniStat(
                            icon: Icons.local_fire_department_rounded,
                            value: '${session.calories} cal',
                          ),
                        ),
                      ],
                    ),
                    if (tag != null && tag.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: colors.outline.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: colors.onSurface.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                    if (session.targetType != null && session.targetValue != null && session.targetValue! > 0) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: session.targetAchieved
                              ? colors.primary.withValues(alpha: 0.12)
                              : colors.outline.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.flag_rounded,
                              size: 12,
                              color: session.targetAchieved
                                  ? colors.primary
                                  : customColors?.grayText ?? const Color(0xFFFF9800),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              session.targetType == 'distance'
                                  ? '${session.targetValue!.toStringAsFixed(1)} km'
                                  : '${session.targetValue!.toStringAsFixed(0)} kcal',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: session.targetAchieved
                                    ? colors.primary
                                    : customColors?.grayText ?? const Color(0xFFFF9800),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              session.targetAchieved
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: 14,
                              color: session.targetAchieved
                                  ? colors.primary
                                  : customColors?.grayText ?? const Color(0xFFFF9800),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.outline),
            ],
          ),
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final customColors = theme.extension<VitalUpColors>();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: customColors?.grayText ?? const Color(0xFF9A9A9A)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: colors.onSurface),
          ),
        ),
      ],
    );
  }
}