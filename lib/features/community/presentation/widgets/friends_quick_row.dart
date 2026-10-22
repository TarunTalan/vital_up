import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_section_header.dart';
import 'package:vital_up/features/community/domain/entities/friend.dart';
import 'package:vital_up/features/community/domain/entities/leaderboard_entry.dart';
import 'package:vital_up/features/community/presentation/widgets/community_widgets.dart';
import 'package:vital_up/features/community/presentation/pages/player_profile_page.dart';
import 'package:vital_up/features/gamification/presentation/widgets/game_icon.dart';
import 'package:vital_up/core/utils/number_formats.dart';
import 'package:vital_up/core/utils/responsive.dart';

/// Arena section: pending friend requests, then a scrolling strip of
/// friends and the caller in rank order (tap a friend to inspect) ending in
/// an Add tile. "Manage" opens the Friends page.
class FriendsQuickRow extends StatelessWidget {
  final List<Friend> friends;

  /// The caller and their friends ranked on all-time points; empty keeps
  /// the friends in list order.
  final List<LeaderboardEntry> ranking;
  final int incomingRequests;
  final String? myUsername;
  final VoidCallback? onRefresh;

  const FriendsQuickRow({
    super.key,
    required this.friends,
    this.ranking = const [],
    this.incomingRequests = 0,
    this.myUsername,
    this.onRefresh,
  });

  void _openFriends(BuildContext context) {
    context
        .pushNamed('friends', extra: myUsername)
        .then((_) => onRefresh?.call());
  }

  @override
  Widget build(BuildContext context) {
    final accepted = friends
        .where((f) => f.status == FriendStatus.accepted)
        .toList();
    final chips = rankedFriendChips(accepted, ranking);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          'Friends',
          count: accepted.isEmpty ? null : accepted.length,
          actionLabel: 'Manage',
          onAction: () => _openFriends(context),
        ),
        if (incomingRequests > 0) ...[
          _RequestsRow(
            count: incomingRequests,
            onTap: () => _openFriends(context),
          ),
          const SizedBox(height: AppDimens.cardGap),
        ],
        if (accepted.isEmpty)
          _EmptyFriends(onAdd: () => _openFriends(context))
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final c in chips) ...[
                    _FriendChip(
                      friend: c.friend,
                      rank: c.rank,
                      points: c.points,
                      isMe: c.isMe,
                      onTap: c.isMe
                          ? null
                          : () => PlayerProfilePage.open(
                              context,
                              userId: c.friend.userId,
                              username: c.friend.username,
                              level: c.friend.level,
                              avatarUrl: c.friend.avatarUrl,
                              fullName: c.friend.fullName,
                              onFriendRemoved: () => onRefresh?.call(),
                            ),
                    ),
                    const SizedBox(width: AppDimens.cardGap),
                  ],
                  _AddChip(onTap: () => _openFriends(context)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _RequestsRow extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _RequestsRow({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      width: double.infinity,
      highlighted: true,
      padding: AppDimens.cardPaddingCompact,
      onTap: onTap,
      child: Row(
        children: [
          AppIconBadge(
            icon: const Icon(Icons.person_add_alt_1_rounded),
            color: context.colors.primary,
          ),
          const SizedBox(width: AppDimens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count friend ${count == 1 ? 'request' : 'requests'}',
                  style: context.text.titleSmall?.copyWith(
                    color: context.colors.onSurface,
                  ),
                ),
                const SizedBox(height: AppDimens.space2),
                Text(
                  'Tap to review',
                  style: context.text.bodySmall?.copyWith(
                    color: context.vColors.grayText,
                  ),
                ),
              ],
            ),
          ),
          const AppChevron(),
        ],
      ),
    );
  }
}

class _EmptyFriends extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyFriends({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppIconBadge(
                icon: const Icon(Icons.group_add_rounded),
                color: context.colors.primary,
              ),
              const SizedBox(width: AppDimens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No friends yet',
                      style: context.text.titleSmall?.copyWith(
                        color: context.colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppDimens.space2),
                    Text(
                      'Add friends by username to compare progress and '
                      'start challenges.',
                      style: context.text.bodySmall?.copyWith(
                        color: context.vColors.grayText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.cardInnerGap),
          AppPrimaryButton(
            label: 'Add friends',
            leadingIcon: const Icon(
              Icons.person_add_alt_1_rounded,
              size: AppDimens.iconSm,
            ),
            onTap: onAdd,
          ),
        ],
      ),
    );
  }
}

/// One tile of the friends strip.
typedef FriendChipData = ({Friend friend, int? rank, int? points, bool isMe});

/// Friends (and the caller) in [ranking] order, then any accepted friend
/// the ranking doesn't list yet. Without a ranking, just the friends.
List<FriendChipData> rankedFriendChips(
  List<Friend> accepted,
  List<LeaderboardEntry> ranking,
) {
  if (accepted.isEmpty) return const [];
  final byId = {for (final f in accepted) f.userId: f};
  final chips = <FriendChipData>[
    for (final e in ranking)
      if (e.isMe)
        (
          friend: Friend(
            userId: e.userId,
            username: e.username,
            fullName: e.displayName,
            avatarUrl: e.avatarUrl,
            level: e.level,
            status: FriendStatus.accepted,
          ),
          rank: e.rank,
          points: e.points,
          isMe: true,
        )
      else if (byId.remove(e.userId) case final f?)
        (friend: f, rank: e.rank, points: e.points, isMe: false),
  ];
  return [
    ...chips,
    for (final f in byId.values)
      (friend: f, rank: null, points: null, isMe: false),
  ];
}

/// Tile width for the strip, growing with the text size so names and
/// figures stay whole.
double _chipWidth(BuildContext context) => context
    .textScaled(AppDimens.friendChipWidth)
    .clamp(AppDimens.friendChipWidth, 180.0);

final _pointsFormat = NumberFormat.decimalPattern();

/// Tile in the friends strip: avatar with the rank pinned to it, the name
/// (two lines when needed), then points and level on their own lines.
class _FriendChip extends StatelessWidget {
  final Friend friend;
  final int? rank;
  final int? points;
  final bool isMe;
  final VoidCallback? onTap;

  const _FriendChip({
    required this.friend,
    required this.onTap,
    this.rank,
    this.points,
    this.isMe = false,
  });

  @override
  Widget build(BuildContext context) {
    final name = isMe ? 'You' : friend.username;
    final grey = context.vColors.grayText;
    return Semantics(
      button: onTap != null,
      label: [
        isMe ? 'You' : '@${friend.username}',
        if (rank != null) 'rank $rank',
        if (points != null) '${_pointsFormat.format(points)} points',
        'level ${friend.level}',
      ].join(', '),
      excludeSemantics: true,
      child: AppCard(
        width: _chipWidth(context),
        padding: const EdgeInsets.fromLTRB(
          AppDimens.space8,
          AppDimens.space12,
          AppDimens.space8,
          AppDimens.space12,
        ),
        highlighted: isMe,
        onTap: onTap,
        child: Column(
          children: [
            _AvatarWithRank(friend: friend, rank: rank, isMe: isMe),
            const SizedBox(height: AppDimens.space8),
            Text(
              name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: context.text.titleSmall?.copyWith(
                color: context.colors.onSurface,
              ),
            ),
            const Spacer(),
            const SizedBox(height: AppDimens.space4),
            if (points != null)
              Text(
                '${formatCompactCount(points!)} pts',
                textAlign: TextAlign.center,
                style: context.text.labelLarge?.copyWith(
                  color: context.colors.onSurface,
                ),
              ),
            Text(
              'Level ${friend.level}',
              textAlign: TextAlign.center,
              style: context.text.labelSmall?.copyWith(color: grey),
            ),
          ],
        ),
      ),
    );
  }
}

/// Avatar with a small rank badge on its lower right: the medal for the
/// top three, otherwise the number on a solid disc.
class _AvatarWithRank extends StatelessWidget {
  final Friend friend;
  final int? rank;
  final bool isMe;

  const _AvatarWithRank({
    required this.friend,
    required this.rank,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final r = rank;
    const badge = AppDimens.friendChipRankBadge;
    return SizedBox.square(
      dimension: AppDimens.friendChipAvatar + badge / 3,
      child: Stack(
        children: [
          UserAvatar(
            username: friend.username,
            url: friend.avatarUrl,
            size: AppDimens.friendChipAvatar,
            ringColor: isMe ? context.colors.primary : null,
          ),
          if (r != null)
            Positioned(
              right: 0,
              bottom: 0,
              child: r <= 3
                  ? GameIcon(
                      GamificationIcons.leaderboardRank(r)!,
                      fallback: Icons.military_tech_rounded,
                      size: badge,
                      color: switch (r) {
                        1 => AppColors.rankGold,
                        2 => AppColors.rankSilver,
                        _ => AppColors.rankBronze,
                      },
                    )
                  : Container(
                      constraints: const BoxConstraints(
                        minWidth: badge,
                        minHeight: badge,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.space4,
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(
                          AppDimens.radiusPill,
                        ),
                        border: Border.all(color: context.vColors.hairline!),
                      ),
                      child: Text(
                        '$r',
                        style: context.text.labelSmall?.copyWith(
                          color: context.colors.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}

class _AddChip extends StatelessWidget {
  final VoidCallback onTap;

  const _AddChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add friends',
      excludeSemantics: true,
      child: AppCard(
        width: _chipWidth(context),
        padding: AppDimens.cardPaddingCompact,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIconBadge(
              icon: const Icon(Icons.add_rounded),
              color: context.colors.primary,
            ),
            const SizedBox(height: AppDimens.space8),
            Text(
              'Add',
              style: context.text.labelMedium?.copyWith(
                color: context.vColors.accentText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
