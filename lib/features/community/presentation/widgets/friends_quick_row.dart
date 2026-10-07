import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_section_header.dart';
import 'package:vital_up/features/community/domain/entities/friend.dart';
import 'package:vital_up/features/community/presentation/widgets/community_widgets.dart';
import 'package:vital_up/features/community/presentation/widgets/player_inspect_sheet.dart';

/// Arena section: pending friend requests, then a scrolling strip of
/// friends (tap to inspect) ending in an Add tile. "Manage" opens the
/// Friends page.
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
                  for (final f in accepted) ...[
                    _FriendChip(
                      friend: f,
                      onTap: () => PlayerInspectSheet.show(
                        context,
                        friend: f,
                        onRemove: () => onRefresh?.call(),
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
          Icon(
            Icons.chevron_right_rounded,
            size: AppDimens.iconMd,
            color: context.vColors.grayText,
          ),
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

/// Fixed-width tile in the friends strip: avatar, name and level.
class _FriendChip extends StatelessWidget {
  final Friend friend;
  final VoidCallback onTap;

  const _FriendChip({required this.friend, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '@${friend.username}, level ${friend.level}',
      excludeSemantics: true,
      child: AppCard(
        width: AppDimens.trackerTile,
        padding: AppDimens.cardPaddingCompact,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            UserAvatar(
              username: friend.username,
              url: friend.avatarUrl,
              size: AppDimens.iconBadge,
            ),
            const SizedBox(height: AppDimens.space8),
            Text(
              friend.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium?.copyWith(
                color: context.colors.onSurface,
              ),
            ),
            Text(
              'Level ${friend.level}',
              maxLines: 1,
              style: context.text.labelSmall?.copyWith(
                color: context.vColors.grayText,
              ),
            ),
          ],
        ),
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
        width: AppDimens.trackerTile,
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
                color: context.colors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
