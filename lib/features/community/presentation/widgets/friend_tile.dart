import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/features/community/domain/entities/friend.dart';
import 'package:vital_up/features/community/presentation/widgets/community_widgets.dart';
import 'package:vital_up/features/gamification/presentation/widgets/game_icon.dart';
import 'package:vital_up/core/widgets/name_with_you_tag.dart';

final _pointsFormat = NumberFormat.decimalPattern();

Color _rankColor(int rank) => switch (rank) {
  1 => AppColors.rankGold,
  2 => AppColors.rankSilver,
  _ => AppColors.rankBronze,
};

/// One person in a friends list: avatar, name, "@username · Level n" (or
/// [subtitle]) and a trailing action. With [rank] / [points] it reads like a
/// leaderboard row; [isMe] highlights the caller's own row.
class FriendTile extends StatelessWidget {
  final Friend friend;
  final Widget? trailing;
  final String? subtitle;
  final bool busy;
  final VoidCallback? onTap;
  final int? rank;
  final int? points;
  final bool isMe;

  const FriendTile({
    super.key,
    required this.friend,
    this.trailing,
    this.subtitle,
    this.busy = false,
    this.onTap,
    this.rank,
    this.points,
    this.isMe = false,
  });

  @override
  Widget build(BuildContext context) {
    final name = friend.fullName?.trim();
    final hasName = name != null && name.isNotEmpty;
    final grey = context.vColors.grayText;

    return AppCard(
      width: double.infinity,
      padding: AppDimens.cardPaddingCompact,
      onTap: onTap,
      highlighted: isMe,
      child: Row(
        children: [
          if (rank != null || points != null || isMe) ...[
            SizedBox(
              width: AppDimens.rankColumnWidth,
              child: rank != null && rank! <= 3
                  ? GameIcon(
                      GamificationIcons.leaderboardRank(rank!)!,
                      fallback: Icons.military_tech_rounded,
                      size: AppDimens.iconLg,
                      color: _rankColor(rank!),
                    )
                  : Text(
                      rank != null ? '${rank!}' : '–',
                      style: context.text.titleSmall?.copyWith(
                        color: isMe ? context.colors.primary : grey,
                      ),
                    ),
            ),
          ],
          UserAvatar(
            username: friend.username,
            url: friend.avatarUrl,
            size: AppDimens.iconBadge,
            ringColor: isMe ? context.colors.primary : null,
          ),
          const SizedBox(width: AppDimens.space12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NameWithYouTag(
                  name: hasName ? name : '@${friend.username}',
                  isMe: isMe,
                  style: context.text.titleSmall?.copyWith(
                    color: context.colors.onSurface,
                  ),
                ),
                const SizedBox(height: AppDimens.space2),
                Row(
                  children: [
                    if (subtitle == null) ...[
                      GameIcon(
                        GamificationIcons.levelHexagon(friend.level),
                        fallback: Icons.shield_rounded,
                        size: AppDimens.iconXs,
                        color: context.colors.primary,
                      ),
                      const SizedBox(width: AppDimens.space4),
                    ],
                    Expanded(
                      child: Text(
                        subtitle ??
                            [
                              if (hasName) '@${friend.username}',
                              'Level ${friend.level}',
                              if (points != null)
                                '${_pointsFormat.format(points)} pts',
                            ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(color: grey),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (busy) ...[
            const SizedBox(width: AppDimens.space8),
            const SizedBox.square(
              dimension: AppDimens.iconLg,
              child: CircularProgressIndicator(
                strokeWidth: AppDimens.borderThick,
                strokeCap: StrokeCap.round,
              ),
            ),
          ] else if (trailing != null) ...[
            const SizedBox(width: AppDimens.space8),
            trailing!,
          ],
        ],
      ),
    );
  }
}
