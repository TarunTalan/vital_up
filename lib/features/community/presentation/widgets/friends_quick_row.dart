import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/features/challenges/presentation/widgets/quick_challenge_sheet.dart';
import 'package:vital_up/features/community/domain/entities/friend.dart';
import 'package:vital_up/features/community/presentation/widgets/community_widgets.dart';
import 'package:vital_up/features/community/presentation/widgets/player_inspect_sheet.dart';
import 'package:vital_up/features/gamification/presentation/widgets/level_badge_widget.dart';

/// A sleek horizontal quick-access row for friends in the Gamification Arena hub.
/// Displays friend avatars with level badges, online indicators, quick-challenge
/// on long press, inspect sheet on tap, and an invite friend chip.
class FriendsQuickRow extends StatelessWidget {
  final List<Friend> friends;
  final int incomingRequests;
  final String? myUsername;
  final VoidCallback? onRefresh;

  const FriendsQuickRow({
    super.key,
    required this.friends,
    this.incomingRequests = 0,
    this.myUsername,
    this.onRefresh,
  });

  void _openFriendsPage(BuildContext context) {
    context.pushNamed('friends', extra: myUsername).then((_) => onRefresh?.call());
  }

  void _shareInvite(BuildContext context) {
    final name = myUsername ?? 'vitalup';
    final shareText =
        'Join me on VitalUp to track fitness, complete 1v1 challenges, and level up! Add me: @$name';
    Clipboard.setData(ClipboardData(text: shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎉 Invite message copied to clipboard! Share it with your friends to earn +200 XP.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final acceptedFriends = friends.where((f) => f.status == FriendStatus.accepted).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              children: [
                Text(
                  'Friends',
                  style: context.text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (acceptedFriends.isNotEmpty) ...[
                  const SizedBox(width: AppDimens.space8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.space8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                      border: Border.all(
                        color: context.colors.primary.withValues(alpha: 0.4),
                        width: AppDimens.borderThin,
                      ),
                    ),
                    child: Text(
                      '${acceptedFriends.length}',
                      style: context.text.labelSmall?.copyWith(
                        color: context.colors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Row(
              children: [
                // Add Friends Button
                InkWell(
                  onTap: () => _openFriendsPage(context),
                  borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.space10,
                      vertical: AppDimens.space4,
                    ),
                    decoration: BoxDecoration(
                      color: incomingRequests > 0
                          ? AppColors.rankGold.withValues(alpha: 0.2)
                          : context.colors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                      border: Border.all(
                        color: incomingRequests > 0
                            ? AppColors.rankGold.withValues(alpha: 0.6)
                            : context.colors.primary.withValues(alpha: 0.4),
                        width: AppDimens.borderThin,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_add_alt_1_rounded,
                          size: AppDimens.iconXs,
                          color: incomingRequests > 0
                              ? AppColors.rankGold
                              : context.colors.primary,
                        ),
                        const SizedBox(width: AppDimens.space4),
                        Text(
                          incomingRequests > 0
                              ? '+$incomingRequests New'
                              : '+ Add',
                          style: context.text.labelSmall?.copyWith(
                            color: incomingRequests > 0
                                ? AppColors.rankGold
                                : context.colors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppDimens.space8),
                // See All Button
                InkWell(
                  onTap: () => _openFriendsPage(context),
                  borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.space4,
                      vertical: AppDimens.space4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'See All',
                          style: context.text.bodySmall?.copyWith(
                            color: v.grayText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 10,
                          color: v.grayText,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppDimens.space12),

        // Friends horizontal list or empty callout
        if (acceptedFriends.isEmpty)
          AppCard(
            width: double.infinity,
            padding: AppDimens.cardPaddingCompact,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppDimens.space12),
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: context.colors.primary.withValues(alpha: 0.4),
                      width: AppDimens.borderThin,
                    ),
                  ),
                  child: Icon(
                    Icons.group_add_rounded,
                    size: AppDimens.iconLg,
                    color: context.colors.primary,
                  ),
                ),
                const SizedBox(width: AppDimens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Challenge friends & level up',
                        style: context.text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppDimens.space2),
                      Text(
                        'Earn +200 XP for every friend you invite!',
                        style: context.text.bodySmall?.copyWith(
                          color: v.grayText,
                        ),
                      ),
                      const SizedBox(height: AppDimens.space8),
                      Row(
                        children: [
                          AppPrimaryButton(
                            label: '+ Add Friends',
                            expand: false,
                            onTap: () => _openFriendsPage(context),
                          ),
                          const SizedBox(width: AppDimens.space8),
                          AppSecondaryButton(
                            label: 'Invite Link',
                            expand: false,
                            onTap: () => _shareInvite(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 116,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: acceptedFriends.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: AppDimens.space10),
              itemBuilder: (context, index) {
                // Last item is always the Invite Friend chip
                if (index == acceptedFriends.length) {
                  return _InviteChip(onTap: () => _shareInvite(context));
                }

                final friend = acceptedFriends[index];
                return _FriendAvatarChip(
                  friend: friend,
                  onTap: () => PlayerInspectSheet.show(
                    context,
                    friend: friend,
                    onRemove: () => onRefresh?.call(),
                  ),
                  onLongPress: () => QuickChallengeSheet.show(
                    context,
                    friend: friend,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _FriendAvatarChip extends StatelessWidget {
  final Friend friend;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _FriendAvatarChip({
    required this.friend,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final tier = LevelTierConfig.forLevel(friend.level);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      child: Container(
        width: 78,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.space4,
          vertical: AppDimens.space8,
        ),
        decoration: BoxDecoration(
          color: v.glassFill,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          border: Border.all(
            color: tier.borderColor.withValues(alpha: 0.35),
            width: AppDimens.borderThin,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Avatar with Level Badge overlay
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                UserAvatar(
                  username: friend.username,
                  url: friend.avatarUrl,
                  size: 46,
                  ringColor: tier.borderColor,
                ),
                // Level Badge positioned at bottom-right
                Positioned(
                  bottom: -4,
                  right: -4,
                  child: LevelBadgeWidget(
                    level: friend.level,
                    size: 18,
                    showGlow: false,
                  ),
                ),
                // Active Online Dot
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.success,
                      border: Border.all(
                        color: AppColors.surfaceDark,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.space6),

            // Username
            Text(
              '@${friend.username}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: context.text.labelSmall?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),

            // Level / Tier tag
            Text(
              'Lv.${friend.level}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: context.text.bodySmall?.copyWith(
                color: tier.borderColor,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteChip extends StatelessWidget {
  final VoidCallback onTap;

  const _InviteChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      child: Container(
        width: 78,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.space4,
          vertical: AppDimens.space8,
        ),
        decoration: BoxDecoration(
          color: AppColors.rankGold.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          border: Border.all(
            color: AppColors.rankGold.withValues(alpha: 0.4),
            width: AppDimens.borderThin,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.rankGold.withValues(alpha: 0.2),
                border: Border.all(
                  color: AppColors.rankGold.withValues(alpha: 0.5),
                  width: AppDimens.borderThin,
                ),
              ),
              child: const Icon(
                Icons.card_giftcard_rounded,
                size: AppDimens.iconMd,
                color: AppColors.rankGold,
              ),
            ),
            const SizedBox(height: AppDimens.space6),
            Text(
              '+200 XP',
              maxLines: 1,
              style: context.text.labelSmall?.copyWith(
                color: AppColors.rankGold,
                fontWeight: FontWeight.w900,
                fontSize: 10.5,
              ),
            ),
            Text(
              'Invite',
              maxLines: 1,
              style: context.text.bodySmall?.copyWith(
                color: v.grayText,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
