import 'package:vital_up/features/community/domain/entities/friend.dart';
import 'package:vital_up/features/community/domain/repositories/community_repository.dart';
import 'package:vital_up/features/notifications/data/datasources/notifications_remote_datasource.dart';
import 'package:vital_up/features/notifications/domain/entities/app_notification.dart';
import 'package:vital_up/features/notifications/domain/repositories/notifications_repository.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  final NotificationsRemoteDataSource _remote;
  final CommunityRepository _community;

  NotificationsRepositoryImpl(this._remote, this._community);

  @override
  Future<List<AppNotification>> getNotifications({int limit = 50}) async {
    if (_remote.userId == null) return const [];
    final rows = await _remote.fetch(limit: limit);
    return [for (final r in rows) AppNotification.fromJson(r)];
  }

  @override
  Future<void> markRead([List<int>? ids]) async {
    if (ids != null && ids.isEmpty) return;
    await _remote.markRead(ids);
  }

  @override
  Future<void> delete(AppNotification notification) =>
      _remote.delete(notification.id);

  @override
  Future<void> respondToFriendRequest(
    AppNotification notification, {
    required bool accept,
  }) async {
    final requester = notification.actorId;
    if (requester == null) {
      throw const FriendRequestException('That request is no longer there.');
    }
    // A server trigger then updates (accept) or removes (decline) this row.
    await _community.respondToRequest(
      Friend(
        userId: requester,
        username: notification.actorUsername ?? 'VitalUp user',
        avatarUrl: notification.actorAvatarUrl,
        level: 1,
        status: FriendStatus.incoming,
      ),
      accept: accept,
    );
  }

  @override
  Stream<void> watch() => _remote.changes();
}
