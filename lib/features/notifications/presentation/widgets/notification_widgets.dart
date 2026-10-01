import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/features/community/presentation/widgets/community_widgets.dart';
import 'package:vital_up/features/gamification/presentation/widgets/game_icon.dart';
import 'package:vital_up/features/notifications/domain/entities/app_notification.dart';

/// Asset paths for notification icons. These SVGs are supplied by design;
/// until a file exists, [GameIcon] falls back to a Material icon.
abstract final class NotificationIcons {
  static const bell = 'assets/icons/bell.svg';
  static const announcement = 'assets/icons/megaphone.svg';
}

/// Routes an announcement's `data.route` may open.
const notificationLinkableRoutes = {
  'friends',
  'badges',
  'points-history',
  'activity-goals',
  'diet-progress',
  'water-trends',
  'sleep-trends',
  'stress-trends',
  'meal-log-history',
  'activity-history',
  'settings',
};

/// The screen a notification opens, from the inbox or a tapped push.
String? notificationRoute(NotificationType type, String? route) =>
    switch (type) {
      NotificationType.friendRequest ||
      NotificationType.friendAccepted => 'friends',
      NotificationType.badge => 'badges',
      NotificationType.levelUp || NotificationType.streak => 'points-history',
      NotificationType.announcement =>
        notificationLinkableRoutes.contains(route) ? route : null,
    };

/// Header bell with the unread count — opens the notifications page.
class NotificationBellButton extends StatelessWidget {
  final int unread;
  final VoidCallback onTap;

  const NotificationBellButton({
    super.key,
    required this.unread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = unread > 99 ? '99+' : '$unread';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AppHeaderAction(
          tooltip: unread == 0
              ? 'Notifications'
              : 'Notifications ($unread unread)',
          onTap: onTap,
          icon: const GameIcon(
            NotificationIcons.bell,
            fallback: Icons.notifications_none_rounded,
            size: AppDimens.iconLg,
          ),
        ),
        if (unread > 0)
          Positioned(
            top: -AppDimens.space2,
            right: -AppDimens.space2,
            child: IgnorePointer(
              child: Container(
                constraints: const BoxConstraints(
                  minWidth: AppDimens.unreadBadge,
                  minHeight: AppDimens.unreadBadge,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.space4,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.colors.error,
                  borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                  border: Border.all(
                    color: context.theme.scaffoldBackgroundColor,
                    width: AppDimens.borderThin,
                  ),
                ),
                child: Text(
                  label,
                  style: context.text.labelSmall?.copyWith(
                    color: context.colors.onError,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Inbox filters on the notifications page.
enum NotificationFilter {
  all('All'),
  friends('Friends'),
  achievements('Achievements'),
  updates('Updates');

  final String label;
  const NotificationFilter(this.label);

  bool matches(AppNotification n) => switch (this) {
    all => true,
    friends => n.type.isFriend,
    achievements => n.type.isAchievement,
    updates => n.type == NotificationType.announcement,
  };
}

class NotificationFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const NotificationFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final fg = selected ? v.buttonText! : context.colors.onSurface;

    return Material(
      color: selected ? context.colors.primary : v.glassFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        side: BorderSide(
          color: selected ? context.colors.primary : v.glassBorder!,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.space12),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: context.text.labelMedium?.copyWith(
                color: fg,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One inbox row: icon (or the friend's avatar), title, body, time, and
/// accept/decline buttons for a pending friend request.
class NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final bool busy;

  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onAccept,
    required this.onDecline,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final v = context.vColors;
    final unread = !n.isRead;

    return AppCard(
      width: double.infinity,
      padding: AppDimens.cardPaddingCompact,
      highlighted: unread,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NotificationLeading(notification: n),
              const SizedBox(width: AppDimens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall?.copyWith(
                        color: context.colors.onSurface,
                      ),
                    ),
                    if (n.body != null && n.body!.isNotEmpty) ...[
                      const SizedBox(height: AppDimens.space2),
                      Text(
                        n.body!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(
                          color: v.grayText,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppDimens.space4),
                    Text(
                      notificationTimeLabel(n.createdAt, DateTime.now()),
                      style: context.text.labelSmall?.copyWith(
                        color: v.grayText,
                      ),
                    ),
                  ],
                ),
              ),
              if (unread) ...[
                const SizedBox(width: AppDimens.space8),
                Padding(
                  padding: const EdgeInsets.only(top: AppDimens.space6),
                  child: Container(
                    width: AppDimens.unreadDot,
                    height: AppDimens.unreadDot,
                    decoration: BoxDecoration(
                      color: context.colors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (n.isPendingRequest) ...[
            const SizedBox(height: AppDimens.space12),
            if (busy)
              const Center(
                child: SizedBox.square(
                  dimension: AppDimens.iconLg,
                  child: CircularProgressIndicator(
                    strokeWidth: AppDimens.borderThick,
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onDecline,
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: AppDimens.buttonGap),
                  Expanded(
                    child: FilledButton(
                      onPressed: onAccept,
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _NotificationLeading extends StatelessWidget {
  final AppNotification notification;

  const _NotificationLeading({required this.notification});

  @override
  Widget build(BuildContext context) {
    final n = notification;
    if (n.type.isFriend) {
      return UserAvatar(
        username: n.actorUsername ?? '',
        url: n.actorAvatarUrl,
        size: AppDimens.iconBadge,
      );
    }

    final (Color color, String asset, IconData fallback) = switch (n.type) {
      NotificationType.badge => (
        AppColors.rankGold,
        GamificationIcons.badge(n.badgeIconKey ?? ''),
        Icons.military_tech_rounded,
      ),
      NotificationType.levelUp => (
        AppColors.scoreBonus,
        GamificationIcons.trophy,
        Icons.emoji_events_rounded,
      ),
      NotificationType.streak => (
        AppColors.streak,
        GamificationIcons.streak,
        Icons.local_fire_department_rounded,
      ),
      _ => (
        context.colors.primary,
        NotificationIcons.announcement,
        Icons.campaign_rounded,
      ),
    };
    return AppIconBadge(
      color: color,
      icon: GameIcon(asset, fallback: fallback, size: AppDimens.iconMd),
    );
  }
}

/// "Just now", "5m", "3h", "Yesterday", weekday within a week, else a date.
String notificationTimeLabel(DateTime at, DateTime now) {
  final diff = now.difference(at);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final days = today.difference(day).inDays;
  if (days == 0) return '${diff.inHours}h ago';
  if (days == 1) return 'Yesterday';
  if (days < 7) return DateFormat('EEEE').format(at);
  if (at.year == now.year) return DateFormat('MMM d').format(at);
  return DateFormat('MMM d, y').format(at);
}
