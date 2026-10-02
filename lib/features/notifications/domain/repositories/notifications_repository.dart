import 'package:vital_up/features/notifications/domain/entities/app_notification.dart';

abstract class NotificationsRepository {
  /// Newest first. Served from the cache while it is fresh (or offline);
  /// [refresh] asks the server anyway.
  Future<List<AppNotification>> getNotifications({
    int limit = 50,
    bool refresh = false,
  });

  /// Marks [ids] read, or every notification when null. Queued when
  /// offline.
  Future<void> markRead([List<int>? ids]);

  /// Queued when offline.
  Future<void> delete(AppNotification notification);

  /// Answers the friend request behind [notification]. Throws
  /// [FriendRequestException] with a user-facing message.
  Future<void> respondToFriendRequest(
    AppNotification notification, {
    required bool accept,
  });

  /// Each of the caller's notifications as it is added or changed.
  Stream<AppNotification> watch();
}
