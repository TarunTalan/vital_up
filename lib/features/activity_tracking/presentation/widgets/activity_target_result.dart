import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';

/// Formats a stored session target (distance in km or calories).
String formatActivityTarget(String? targetType, double value) {
  return targetType == 'distance'
      ? '${value.toStringAsFixed(1)} km'
      : '${value.toStringAsFixed(0)} kcal';
}

/// Accent for a target outcome: primary when achieved, warning otherwise.
Color activityTargetColor(BuildContext context, bool achieved) =>
    achieved ? context.colors.primary : context.vColors.warning!;

/// Card summarising whether a session hit its target. Uses the highlighted
/// insight card when achieved.
class ActivityTargetResultCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool achieved;
  final IconData icon;

  const ActivityTargetResultCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.achieved,
    this.icon = Icons.flag_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final accent = activityTargetColor(context, achieved);
    return AppCard(
      padding: AppDimens.cardPaddingCompact,
      highlighted: achieved,
      child: Row(
        children: [
          AppIconBadge(icon: Icon(icon), color: accent),
          const SizedBox(width: AppDimens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.text.titleSmall?.copyWith(
                    color: context.colors.onSurface,
                  ),
                ),
                const SizedBox(height: AppDimens.space2),
                Text(
                  subtitle,
                  style: context.text.bodyMedium?.copyWith(
                    color: achieved ? accent : context.vColors.grayText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimens.space8),
          Icon(
            achieved ? Icons.check_circle_rounded : Icons.cancel_outlined,
            size: AppDimens.iconLg,
            color: accent,
          ),
        ],
      ),
    );
  }
}

/// Small pill used on list rows to show a session target and its outcome.
class ActivityTargetChip extends StatelessWidget {
  final String label;
  final bool achieved;

  const ActivityTargetChip({
    super.key,
    required this.label,
    required this.achieved,
  });

  @override
  Widget build(BuildContext context) {
    final accent = activityTargetColor(context, achieved);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.space8,
        vertical: AppDimens.space4,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag_rounded, size: AppDimens.iconXs, color: accent),
          const SizedBox(width: AppDimens.space4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelSmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppDimens.space4),
          Icon(
            achieved
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: AppDimens.iconXs,
            color: accent,
          ),
        ],
      ),
    );
  }
}

/// Neutral pill for a user tag on a session.
class ActivityTagChip extends StatelessWidget {
  final String label;

  const ActivityTagChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.space8,
        vertical: AppDimens.space4,
      ),
      decoration: BoxDecoration(
        color: context.vColors.track,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.text.labelSmall?.copyWith(
          color: context.colors.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
