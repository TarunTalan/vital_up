import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/features/community/domain/entities/friend.dart';
import 'package:vital_up/features/community/presentation/widgets/community_widgets.dart';
import 'package:vital_up/features/gamification/presentation/widgets/game_icon.dart';

final _pointsFormat = NumberFormat.decimalPattern();

Color _rankColor(int rank) => switch (rank) {
  1 => AppColors.rankGold,
  2 => AppColors.rankSilver,
  _ => AppColors.rankBronze,
};

/// One person in a friends list: avatar, name, "@username · Level n" (or
/// [subtitle]) and a trailing action. Shows rank column when [rank] is provided,
/// and highlights the tile when [isMe] is true.
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
      borderColor: isMe ? context.colors.primary.withValues(alpha: 0.5) : null,
      tint: isMe ? context.colors.primary.withValues(alpha: 0.06) : null,
      child: Row(
        children: [
          // Rank column when rank is provided or for self position
          if (rank != null || isMe) ...[
            SizedBox(
              width: 30,
              child: Center(
                child: rank != null && rank! <= 3
                    ? GameIcon(
                        GamificationIcons.leaderboardRank(rank!)!,
                        fallback: Icons.emoji_events_rounded,
                        size: 22,
                        color: _rankColor(rank!),
                      )
                    : Text(
                        rank != null ? '#$rank' : '–',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: isMe ? context.colors.primary : grey,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: AppDimens.space8),
          ],

          // Avatar (strictly circular)
          Container(
            decoration: isMe
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.primary.withValues(alpha: 0.25),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  )
                : null,
            child: UserAvatar(
              username: friend.username,
              url: friend.avatarUrl,
              size: AppDimens.iconBadge,
            ),
          ),
          const SizedBox(width: AppDimens.space12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        hasName ? name : '@${friend.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleSmall?.copyWith(
                          fontWeight: isMe ? FontWeight.w800 : FontWeight.w700,
                          color: context.colors.onSurface,
                        ),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: AppDimens.space6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5.5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.primary.withValues(alpha: 0.16),
                          borderRadius:
                              BorderRadius.circular(AppDimens.radiusPill),
                          border: Border.all(
                            color:
                                context.colors.primary.withValues(alpha: 0.5),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          'YOU',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: context.colors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
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
          ] else if (isMe) ...[
            const SizedBox(width: AppDimens.space8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
              decoration: BoxDecoration(
                color: context.colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimens.radiusPill),
              ),
              child: Text(
                'Standing',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: context.colors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

