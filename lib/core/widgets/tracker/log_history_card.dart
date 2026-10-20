import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/date_range_utils.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/adaptive_row.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/fit_text.dart';

/// "Today · 7:30 AM", "Yesterday · …", "Mon, Oct 19 · …" (with the year
/// when it isn't this one).
String formatLogDateTime(DateTime at, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  final today = DateTime(clock.year, clock.month, clock.day);
  final day = DateTime(at.year, at.month, at.day);
  final time = DateFormat('h:mm a').format(at);
  if (day == today) return 'Today · $time';
  if (day == previousDay(today)) return 'Yesterday · $time';
  final date = at.year == clock.year
      ? DateFormat('EEE, MMM d').format(at)
      : DateFormat('EEE, MMM d, y').format(at);
  return '$date · $time';
}

/// Day heading in a history list: "Today", "Yesterday", "Monday 12 Oct"
/// (with the year when it isn't this one).
String formatLogDay(DateTime day, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  if (isSameDay(day, clock)) return 'Today';
  if (isSameDay(day, previousDay(clock))) return 'Yesterday';
  return DateFormat(
    day.year == clock.year ? 'EEEE d MMM' : 'EEEE d MMM y',
  ).format(day);
}

/// [logs] (newest first) split into days, in order.
List<(DateTime day, List<L> logs)> groupLogsByDay<L>(
  Iterable<L> logs,
  DateTime Function(L log) dateOf,
) {
  final days = <(DateTime, List<L>)>[];
  for (final log in logs) {
    final day = startOfDay(dateOf(log));
    if (days.isEmpty || days.last.$1 != day) days.add((day, <L>[]));
    days.last.$2.add(log);
  }
  return days;
}

/// One figure on a [LogHistoryCard]: the value over its label.
class LogFigure {
  final String value;
  final String label;

  const LogFigure(this.value, this.label);
}

/// One entry in every tracker history (water, sleep, weight, mood, screen
/// time, meals, activities), so all of them read alike:
///
/// - the entry's icon on a badge tinted with [color], its [title] and a
///   grey [subtitle] (time, source), its main [value] on the right and a
///   grey delete button;
/// - an optional [note] (tag, food names, what was on your mind);
/// - optional [figures] in equal columns under a hairline.
///
/// Delete asks first ("Delete this meal?" from [deleteNoun]). With [onTap]
/// it ends in [AppChevron]: tapping opens the entry's details.
class LogHistoryCard extends StatelessWidget {
  final Widget icon;
  final Color color;
  final String title;
  final String? subtitle;
  final String? value;
  final String? note;
  final List<LogFigure> figures;
  final VoidCallback? onTap;

  /// Null: no delete button (read-only lists, synced entries).
  final VoidCallback? onDelete;

  /// What the entry is, for the delete question ("meal", "drink").
  final String deleteNoun;

  const LogHistoryCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.value,
    this.note,
    this.figures = const [],
    this.onTap,
    this.onDelete,
    this.deleteNoun = 'entry',
  });

  /// Room the compact delete button takes, with its gap.
  static const double _deleteWidth = AppDimens.space40 + AppDimens.space4;

  /// Room the chevron of a card that opens something takes.
  static const double _chevronWidth = AppChevron.width + AppDimens.space4;

  /// Narrowest the title column gets before the value moves under it.
  static const double _minTitleWidth = 140;

  Future<void> _confirmDelete(BuildContext context) async {
    final delete = await showSmoothDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete this $deleteNoun?'),
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
    final onSurface = context.colors.onSurface;
    final note = this.note;
    final value = this.value;
    return AppCard(
      width: double.infinity,
      onTap: onTap,
      padding: AppDimens.cardPaddingCompact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final valueStyle = context.text.titleMedium?.copyWith(
                color: onSurface,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              );
              // The value moves under the title when beside it the title
              // would get under 140dp (large text, narrow phones).
              var valueBeside = value != null;
              if (value != null) {
                final painter = TextPainter(
                  text: TextSpan(text: value, style: valueStyle),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                  maxLines: 1,
                )..layout();
                final room =
                    constraints.maxWidth -
                    AppDimens.iconBadge -
                    AppDimens.space12 -
                    (onDelete != null ? _deleteWidth : 0) -
                    (onTap != null ? _chevronWidth : 0) -
                    AppDimens.space12 -
                    painter.width;
                painter.dispose();
                valueBeside = room >= context.textScaled(_minTitleWidth);
              }
              final valueText = value == null
                  ? null
                  : Text(value, style: valueStyle);
              return Row(
                children: [
                  AppIconBadge(color: color, icon: icon),
                  const SizedBox(width: AppDimens.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Whole, however long (food names): never cut.
                        Text(
                          title,
                          style: context.text.titleSmall?.copyWith(
                            color: onSurface,
                          ),
                        ),
                        if (subtitle case final subtitle?) ...[
                          const SizedBox(height: AppDimens.space2),
                          Text(
                            subtitle,
                            style: context.text.bodySmall?.copyWith(
                              color: v.grayText,
                            ),
                          ),
                        ],
                        if (valueText != null && !valueBeside) ...[
                          const SizedBox(height: AppDimens.space4),
                          valueText,
                        ],
                      ],
                    ),
                  ),
                  if (valueText != null && valueBeside) ...[
                    const SizedBox(width: AppDimens.space12),
                    valueText,
                  ],
                  if (onDelete != null) ...[
                    const SizedBox(width: AppDimens.space4),
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
                  // Opens the entry's details.
                  if (onTap != null) ...[
                    const SizedBox(width: AppDimens.space4),
                    const AppChevron(),
                  ],
                ],
              );
            },
          ),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: AppDimens.space8),
            Text(
              note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium?.copyWith(color: onSurface),
            ),
          ],
          if (figures.isNotEmpty) ...[
            const SizedBox(height: AppDimens.space12),
            Divider(height: AppDimens.borderThin, color: v.divider),
            const SizedBox(height: AppDimens.space12),
            AdaptiveRow(
              children: [for (final f in figures) _Figure(figure: f)],
            ),
          ],
        ],
      ),
    );
  }
}

/// A figure over its label, both left-aligned so the columns line up.
class _Figure extends StatelessWidget {
  final LogFigure figure;

  const _Figure({required this.figure});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FitText(
          figure.value,
          maxLines: 1,
          style: context.text.titleSmall?.copyWith(
            color: context.colors.onSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: AppDimens.space2),
        Text(
          figure.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.bodySmall?.copyWith(
            color: context.vColors.grayText,
          ),
        ),
      ],
    );
  }
}

/// Heading over one day of a history list: the day, and on the right an
/// optional total for it ("1.75 L", "1,840 kcal").
class LogDayHeader extends StatelessWidget {
  final String label;
  final String? summary;

  const LogDayHeader(this.label, {super.key, this.summary});

  @override
  Widget build(BuildContext context) {
    final summary = this.summary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.space4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              label,
              style: context.text.titleSmall?.copyWith(
                color: context.colors.onSurface,
              ),
            ),
          ),
          if (summary != null) ...[
            const SizedBox(width: AppDimens.space12),
            Text(
              summary,
              style: context.text.bodySmall?.copyWith(
                color: context.vColors.grayText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
