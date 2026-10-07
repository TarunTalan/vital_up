import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/features/community/domain/entities/friend.dart';
import 'package:vital_up/features/community/presentation/widgets/community_widgets.dart';

/// One person in a friends list: avatar, name, "@username · Level n" (or
/// [subtitle]) and a trailing action. Shows a spinner instead of the
/// action while [busy].
class FriendTile extends StatelessWidget {
  final Friend friend;
  final Widget? trailing;
  final String? subtitle;
  final bool busy;
  final VoidCallback? onTap;

  const FriendTile({
    super.key,
    required this.friend,
    this.trailing,
    this.subtitle,
    this.busy = false,
    this.onTap,
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
      child: Row(
        children: [
          UserAvatar(
            username: friend.username,
            url: friend.avatarUrl,
            size: AppDimens.iconBadge,
          ),
          const SizedBox(width: AppDimens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasName ? name : '@${friend.username}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall?.copyWith(
                    color: context.colors.onSurface,
                  ),
                ),
                const SizedBox(height: AppDimens.space2),
                Text(
                  subtitle ??
                      [
                        if (hasName) '@${friend.username}',
                        'Level ${friend.level}',
                      ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(color: grey),
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
