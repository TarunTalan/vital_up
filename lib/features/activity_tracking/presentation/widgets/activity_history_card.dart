import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/widgets/tracker/log_history_card.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/get_activity_history.dart';
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_format_utils.dart';
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_type_ui.dart';

/// One activity in the history, as a [LogHistoryCard] like every other
/// tracker's entries: icon, type and start time, the tag, then three
/// figures in equal columns (distance, time and calories; time, calories
/// and effort for workouts without a route). Tapping opens the details
/// (target, notes); the bin deletes after asking.
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

  @override
  Widget build(BuildContext context) {
    final session = entry.session;
    final time = formatDuration(
      Duration(seconds: session.totalDurationSeconds),
    );
    final calories = LogFigure('${session.calories}', 'Calories');
    return LogHistoryCard(
      icon: Icon(activityTypeIcon(session.activityType)),
      color: TrackerMetric.activity.color,
      title: session.activityType.label,
      subtitle: DateFormat.jm().format(session.startTime),
      note: entry.annotation?.tag,
      onTap: onTap,
      onDelete: onDelete,
      deleteNoun: 'activity',
      figures: session.hasDistance
          ? [
              LogFigure(formatDistanceKm(session.totalDistanceMeters), 'km'),
              LogFigure(time, 'Time'),
              calories,
            ]
          : [
              LogFigure(time, 'Time'),
              calories,
              LogFigure(session.intensity?.label ?? '–', 'Effort'),
            ],
    );
  }
}
