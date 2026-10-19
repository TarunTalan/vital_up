import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/features/gamification/domain/entities/game_badge.dart';
import 'package:vital_up/features/gamification/presentation/widgets/game_icon.dart';

final _number = NumberFormat.decimalPattern();

/// "12,500 of 20,000" for a locked badge with known progress, else null.
String? badgeProgressLabel(GameBadge badge) {
  final t = badge.threshold;
  if (badge.progressFraction == null || t == null) return null;
  final p = (badge.progress ?? 0).clamp(0, t);
  return '${_number.format(p)} of ${_number.format(t)}';
}

/// "Earned Oct 10, 2026".
String badgeEarnedLabel(GameBadge badge) {
  final at = badge.earnedAt;
  return at == null
      ? 'Earned'
      : 'Earned ${DateFormat.yMMMd().format(at.toLocal())}';
}

/// Badge artwork: full colour when earned, grey and faded while locked.
class BadgeEmblem extends StatelessWidget {
  final GameBadge badge;
  final double size;

  const BadgeEmblem({
    super.key,
    required this.badge,
    this.size = AppDimens.badgeTile,
  });

  /// Greyscale with the locked fade folded into alpha: one layer per tile
  /// instead of an Opacity and a ColorFiltered (two saveLayers).
  static const _lockedFilter = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, AppDimens.badgeLockedOpacity, 0, //
  ]);

  @override
  Widget build(BuildContext context) {
    final icon = GameIcon(
      GamificationIcons.badge(badge.iconKey),
      fallback: Icons.military_tech_rounded,
      size: size,
      color: badge.earned ? AppColors.rankGold : context.vColors.grayText,
    );
    if (badge.earned) return icon;
    return ColorFiltered(colorFilter: _lockedFilter, child: icon);
  }
}

/// Grid tile on the Badges page: emblem, name and either the earned date or
/// progress toward unlocking. Tapping opens [showBadgeDetailSheet].
class BadgeTile extends StatelessWidget {
  final GameBadge badge;

  const BadgeTile({super.key, required this.badge});

  @override
  Widget build(BuildContext context) {
    final fraction = badge.progressFraction;
    final progress = badgeProgressLabel(badge);
    final grey = context.vColors.grayText;

    return Semantics(
      button: true,
      label: '${badge.name}, ${badge.earned ? 'earned' : 'locked'}',
      child: AppCard(
        onTap: () => showBadgeDetailSheet(context, badge),
        borderColor: badge.earned
            ? AppColors.rankGold.withValues(alpha: 0.4)
            : null,
        padding: const EdgeInsets.all(AppDimens.space12),
        child: Column(
          children: [
            const SizedBox(height: AppDimens.space4),
            BadgeEmblem(badge: badge),
            const SizedBox(height: AppDimens.space8),
            Text(
              badge.name,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: context.text.titleSmall?.copyWith(
                color: badge.earned ? null : grey,
              ),
            ),
            const Spacer(),
            const SizedBox(height: AppDimens.space8),
            if (badge.earned)
              _TileFooter(
                icon: Icons.check_circle_rounded,
                label: badgeEarnedLabel(badge),
                color: AppColors.rankGold,
              )
            else if (fraction != null && progress != null) ...[
              AppProgressBar(
                value: fraction,
                color: context.colors.primary,
                height: AppDimens.badgeProgressHeight,
              ),
              const SizedBox(height: AppDimens.space6),
              Text(
                progress,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: context.text.labelSmall?.copyWith(color: grey),
              ),
            ] else
              _TileFooter(
                icon: Icons.lock_outline_rounded,
                label: 'Locked',
                color: grey,
              ),
          ],
        ),
      ),
    );
  }
}

class _TileFooter extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _TileFooter({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: AppDimens.iconXs, color: color),
        const SizedBox(width: AppDimens.space4),
        Flexible(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.text.labelSmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// Bottom sheet with everything about one badge: what it takes, where the
/// user stands and the bonus it gives. Used by the Badges page, the player
/// sheet and the reward dialog.
Future<void> showBadgeDetailSheet(BuildContext context, GameBadge badge) {
  HapticFeedback.selectionClick();
  return showAppBottomSheet<void>(
    context: context,
    builder: (_) => BadgeDetailSheet(badge: badge),
  );
}

class BadgeDetailSheet extends StatelessWidget {
  final GameBadge badge;

  const BadgeDetailSheet({super.key, required this.badge});

  @override
  Widget build(BuildContext context) {
    final grey = context.vColors.grayText;
    final fraction = badge.progressFraction;
    final progress = badgeProgressLabel(badge);
    final t = badge.threshold;
    final remaining = t == null ? null : t - (badge.progress ?? 0).clamp(0, t);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        context.gutter,
        0,
        context.gutter,
        AppDimens.sectionGap,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: AppDimens.celebrationBadge,
              height: AppDimens.celebrationBadge,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: badge.earned
                    ? AppColors.rankGold.withValues(alpha: 0.16)
                    : context.vColors.track,
              ),
              child: BadgeEmblem(
                badge: badge,
                size: AppDimens.celebrationBadge * 0.72,
              ),
            ),
          ),
          const SizedBox(height: AppDimens.space16),
          Text(
            badge.name,
            textAlign: TextAlign.center,
            style: context.text.headlineSmall,
          ),
          const SizedBox(height: AppDimens.space8),
          Center(child: _StatusChip(badge: badge)),
          const SizedBox(height: AppDimens.space16),
          Text(
            badge.description.isNotEmpty
                ? badge.description
                : 'Keep logging your habits to unlock this badge.',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(color: grey),
          ),
          if (!badge.earned && fraction != null && progress != null) ...[
            const SizedBox(height: AppDimens.sectionGap),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Your progress',
                          style: context.text.titleSmall,
                        ),
                      ),
                      Text(
                        '${(fraction * 100).round()}%',
                        style: context.text.titleSmall?.copyWith(
                          color: context.colors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.space12),
                  AppProgressBar(
                    value: fraction,
                    color: context.colors.primary,
                  ),
                  const SizedBox(height: AppDimens.space8),
                  Text(
                    remaining != null && remaining > 0
                        ? '$progress · ${_number.format(remaining)} to go'
                        : progress,
                    style: context.text.bodySmall?.copyWith(color: grey),
                  ),
                ],
              ),
            ),
          ],
          if (badge.bonusPoints > 0) ...[
            const SizedBox(height: AppDimens.cardGap),
            AppCard(
              child: Row(
                children: [
                  const AppIconBadge(
                    color: AppColors.rankGold,
                    icon: Icon(Icons.bolt_rounded),
                  ),
                  const SizedBox(width: AppDimens.space12),
                  Expanded(
                    child: Text(
                      badge.earned ? 'Bonus points added' : 'Bonus when earned',
                      style: context.text.bodyMedium,
                    ),
                  ),
                  Text(
                    '+${_number.format(badge.bonusPoints)} pts',
                    style: context.text.titleSmall,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final GameBadge badge;

  const _StatusChip({required this.badge});

  @override
  Widget build(BuildContext context) {
    final color = badge.earned ? AppColors.rankGold : context.vColors.grayText!;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.space10,
        vertical: AppDimens.space4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            badge.earned
                ? Icons.check_circle_rounded
                : Icons.lock_outline_rounded,
            size: AppDimens.iconXs,
            color: color,
          ),
          const SizedBox(width: AppDimens.space4),
          Text(
            badge.earned ? badgeEarnedLabel(badge) : 'Locked',
            style: context.text.labelMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
