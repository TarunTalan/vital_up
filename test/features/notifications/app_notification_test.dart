import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/notifications/domain/entities/app_notification.dart';
import 'package:vital_up/features/notifications/presentation/widgets/notification_widgets.dart';

void main() {
  test('parses a pending friend request', () {
    final n = AppNotification.fromJson({
      'id': 7,
      'type': 'friend_request',
      'title': 'New friend request',
      'body': '@sam wants to be your friend',
      'actor_id': 'u-1',
      'data': {'username': 'sam', 'avatar_url': null, 'status': 'pending'},
      'created_at': '2026-10-01T10:00:00+00:00',
      'read_at': null,
    });
    expect(n.type, NotificationType.friendRequest);
    expect(n.isPendingRequest, isTrue);
    expect(n.isRead, isFalse);
    expect(n.actorUsername, 'sam');
    expect(n.markedRead().isRead, isTrue);
  });

  test('unknown types fall back to announcements', () {
    expect(NotificationType.fromCode('nope'), NotificationType.announcement);
  });

  test('filters group types', () {
    final badge = AppNotification(
      id: 1,
      type: NotificationType.badge,
      title: 'Badge',
      createdAt: DateTime(2026),
    );
    expect(NotificationFilter.achievements.matches(badge), isTrue);
    expect(NotificationFilter.friends.matches(badge), isFalse);
  });

  test('time labels', () {
    final now = DateTime(2026, 10, 1, 12);
    expect(notificationTimeLabel(now, now), 'Just now');
    expect(
      notificationTimeLabel(now.subtract(const Duration(minutes: 5)), now),
      '5m ago',
    );
    expect(
      notificationTimeLabel(now.subtract(const Duration(hours: 3)), now),
      '3h ago',
    );
    expect(notificationTimeLabel(DateTime(2026, 9, 30, 23), now), 'Yesterday');
    expect(notificationTimeLabel(DateTime(2026, 8, 2), now), 'Aug 2');
  });
}
