import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/date_range_utils.dart';
import 'package:vital_up/core/widgets/app_card.dart';

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

/// One entry in a log history list (meals, activities): what kind it is,
/// when, a delete button, then an optional title and its figures.
class LogHistoryCard extends StatelessWidget {
  final Widget badge;
  final DateTime at;
  final String? title;
  final List<Widget> figures;
  final VoidCallback? onTap;
  final VoidCallback onDelete;

  const LogHistoryCard({
    super.key,
    required this.badge,
    required this.at,
    this.title,
    this.figures = const [],
    this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    return AppCard(
      onTap: onTap,
      padding: AppDimens.cardPaddingCompact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              badge,
              const SizedBox(width: AppDimens.space8),
              // Wraps at large text sizes instead of pushing the row wider.
              Expanded(
                child: Text(
                  formatLogDateTime(at),
                  textAlign: TextAlign.end,
                  style: context.text.bodySmall?.copyWith(
                    color: context.vColors.grayText,
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.space4),
              IconButton(
                tooltip: 'Delete',
                visualDensity: VisualDensity.compact,
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: AppDimens.iconMd,
                  color: context.colors.error,
                ),
              ),
            ],
          ),
          if (title != null && title.isNotEmpty) ...[
            const SizedBox(height: AppDimens.space8),
            Text(title, style: context.text.titleSmall),
          ],
          if (figures.isNotEmpty) ...[
            const SizedBox(height: AppDimens.space12),
            Wrap(
              spacing: AppDimens.space8,
              runSpacing: AppDimens.space8,
              children: figures,
            ),
          ],
        ],
      ),
    );
  }
}

/// The entry's kind ("Lunch", "Run") as a tinted label, with an icon.
class LogTypeBadge extends StatelessWidget {
  final String label;
  final IconData? icon;

  const LogTypeBadge({super.key, required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final color = context.colors.onPrimaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.space12,
        vertical: AppDimens.space4,
      ),
      decoration: BoxDecoration(
        color: v.primaryFill,
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        border: Border.all(color: v.primaryBorder!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon case final icon?) ...[
            Icon(icon, size: AppDimens.iconXs, color: color),
            const SizedBox(width: AppDimens.space4),
          ],
          Flexible(
            child: Text(
              label,
              style: context.text.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Cals: 420", "Time: 42:10" in a pill tinted with [color].
class LogValuePill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const LogValuePill({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.space8,
        vertical: AppDimens.space4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.27)),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: context.text.bodySmall?.copyWith(
                color: context.vColors.grayText,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextSpan(
              text: value,
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
