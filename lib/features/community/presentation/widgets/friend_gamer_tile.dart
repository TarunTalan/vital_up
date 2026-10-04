import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/features/challenges/presentation/widgets/quick_challenge_sheet.dart';
import 'package:vital_up/features/community/domain/entities/friend.dart';
import 'package:vital_up/features/community/presentation/widgets/community_widgets.dart';
import 'package:vital_up/features/community/presentation/widgets/player_inspect_sheet.dart';
import 'package:vital_up/features/gamification/presentation/widgets/level_badge_widget.dart';

/// A gaming-styled friend card displaying avatar, level badge, tier rank,
/// and a direct 1-tap "Challenge" button. Tapping the card opens the
/// Player Dossier Inspect Sheet.
class FriendGamerTile extends StatelessWidget {
  final Friend friend;
  final bool busy;
  final VoidCallback onRemove;

  const FriendGamerTile({
    super.key,
    required this.friend,
    required this.onRemove,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final tier = LevelTierConfig.forLevel(friend.level);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.space8),
      child: AppCard(
        width: double.infinity,
        padding: AppDimens.cardPaddingCompact,
        onTap: () => PlayerInspectSheet.show(
          context,
          friend: friend,
          onRemove: onRemove,
        ),
        child: Row(
          children: [
            // Avatar with Level Tier Frame & Mini Level Badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                UserAvatar(
                  username: friend.username,
                  url: friend.avatarUrl,
                  size: AppDimens.iconXxl,
                  ringColor: tier.borderColor,
                ),
                Positioned(
                  bottom: -3,
                  right: -3,
                  child: LevelBadgeWidget(
                    level: friend.level,
                    size: 20,
                    showGlow: false,
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppDimens.space12),

            // Friend Username & Level Tier Tag
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '@${friend.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppDimens.space2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.space6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: tier.borderColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppDimens.radiusXs),
                          border: Border.all(
                            color: tier.borderColor.withValues(alpha: 0.5),
                            width: AppDimens.borderThin,
                          ),
                        ),
                        child: Text(
                          'LVL ${friend.level}',
                          style: context.text.labelSmall?.copyWith(
                            color: tier.borderColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 9.5,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimens.space6),
                      Flexible(
                        child: Text(
                          tier.tierName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall?.copyWith(
                            color: v.grayText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Actions: Quick 1-Tap Challenge & Remove Menu
            if (busy)
              const SizedBox.square(
                dimension: AppDimens.iconLg,
                child: CircularProgressIndicator(
                  strokeWidth: AppDimens.borderThick,
                ),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1-Tap Challenge Button
                  InkWell(
                    onTap: () => QuickChallengeSheet.show(context, friend: friend),
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.space10,
                        vertical: AppDimens.space6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.5),
                          width: AppDimens.borderThin,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.sports_martial_arts_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: AppDimens.space4),
                          Text(
                            'Duel',
                            style: context.text.labelSmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimens.space4),
                  IconButton(
                    tooltip: 'Options',
                    icon: Icon(
                      Icons.more_vert_rounded,
                      size: AppDimens.iconSm,
                      color: v.grayText,
                    ),
                    onPressed: () => PlayerInspectSheet.show(
                      context,
                      friend: friend,
                      onRemove: onRemove,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
