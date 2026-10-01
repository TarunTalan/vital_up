import 'package:vital_up/features/notifications/domain/entities/app_notification.dart';

abstract class NotificationsRepository {
  /// Newest first.
  Future<List<AppNotification>> getNotifications({int limit = 50});

  /// Marks [ids] read, or every notification when null.
  Future<void> markRead([List<int>? ids]);

  Future<void> delete(AppNotification notification);

  /// Answers the friend request behind [notification]. Throws
  /// [FriendRequestException] with a user-facing message.
  Future<void> respondToFriendRequest(
    AppNotification notification, {
    required bool accept,
  });

  /// Fires whenever one of the caller's notifications is added or changed.
  Stream<void> watch();
}
