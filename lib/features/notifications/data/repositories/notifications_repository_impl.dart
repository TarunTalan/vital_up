import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:vital_up/core/cache/cache_store.dart';
import 'package:vital_up/features/community/domain/entities/friend.dart';
import 'package:vital_up/features/community/domain/repositories/community_repository.dart';
import 'package:vital_up/features/notifications/data/datasources/notifications_remote_datasource.dart';
import 'package:vital_up/features/notifications/domain/entities/app_notification.dart';
import 'package:vital_up/features/notifications/domain/repositories/notifications_repository.dart';

/// The inbox is cached (raw rows) so it opens instantly and offline. Local
/// changes (read, delete, answered requests) and realtime rows are applied
/// to the cached copy instead of refetching it.
class NotificationsRepositoryImpl implements NotificationsRepository {
  final NotificationsRemoteDataSource _remote;
  final CommunityRepository _community;
  final CacheStore _cache;

  NotificationsRepositoryImpl(this._remote, this._community, this._cache);

  static const _maxAge = Duration(minutes: 2);
  static const _limit = 50;

  /// Gives up on a hung request early enough to fall back to the cache.
  static const _requestTimeout = Duration(seconds: 10);

  String? get _key {
    final user = _remote.userId;
    return user == null ? null : 'notifications:list:$user';
  }

  static List<Map<String, dynamic>> _decode(Object? json) => [
    for (final r in json as List) Map<String, dynamic>.from(r as Map),
  ];

  /// Applies [change] to the cached rows, if any.
  Future<void> _patch(
    List<Map<String, dynamic>> Function(List<Map<String, dynamic>> rows) change,
  ) async {
    final key = _key;
    if (key == null) return;
    await _cache.update(key, (data) => change(_decode(data)));
  }

  @override
  Future<List<AppNotification>> getNotifications({
    int limit = _limit,
    bool refresh = false,
  }) async {
    final key = _key;
    if (key == null) return const [];
    final rows = await _cache.fetch<List<Map<String, dynamic>>>(
      limit == _limit ? key : '$key:$limit',
      remote: () => _remote.fetch(limit: limit).timeout(_requestTimeout),
      maxAge: _maxAge,
      decode: _decode,
      forceRefresh: refresh,
    );
    return [for (final r in rows) AppNotification.fromJson(r)];
  }

  @override
  Future<void> markRead([List<int>? ids]) async {
    if (ids != null && ids.isEmpty) return;
    final readAt = DateTime.now().toUtc().toIso8601String();
    await _patch(
      (rows) => [
        for (final r in rows)
          if (r['read_at'] == null &&
              (ids == null || ids.contains((r['id'] as num).toInt())))
            {...r, 'read_at': readAt}
          else
            r,
      ],
    );
    await _remote.markRead(ids);
  }

  @override
  Future<void> delete(AppNotification notification) async {
    await _patch(
      (rows) => [
        for (final r in rows)
          if ((r['id'] as num).toInt() != notification.id) r,
      ],
    );
    await _remote.delete(notification.id);
  }

  @override
  Future<void> respondToFriendRequest(
    AppNotification notification, {
    required bool accept,
  }) async {
    final requester = notification.actorId;
    if (requester == null) {
      throw const FriendRequestException('That request is no longer there.');
    }
    // A server trigger then updates (accept) or removes (decline) this row;
    // mirror that in the cache.
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
    final readAt = DateTime.now().toUtc().toIso8601String();
    await _patch(
      (rows) => [
        for (final r in rows)
          if ((r['id'] as num).toInt() != notification.id)
            r
          else if (accept)
            {
              ...r,
              'data': {...?(r['data'] as Map?), 'status': 'accepted'},
              'read_at': r['read_at'] ?? readAt,
            },
      ],
    );
  }

  @override
  Stream<AppNotification> watch({void Function()? onResync}) => _remote
      .changes(onResubscribed: onResync)
      .transform(
        StreamTransformer.fromHandlers(
          handleData: (row, sink) {
            final AppNotification notification;
            try {
              notification = AppNotification.fromJson(row);
            } catch (e) {
              debugPrint('Unreadable notification from the feed: $e');
              return;
            }
            sink.add(notification);
            unawaited(_remember(row, notification.id));
          },
        ),
      );

  /// Puts a feed row into the cached inbox: newest first, replacing an
  /// older copy of the same row.
  Future<void> _remember(Map<String, dynamic> row, int id) {
    final cached = {for (final k in _columns) k: row[k]};
    return _patch((rows) {
      final i = rows.indexWhere((r) => (r['id'] as num).toInt() == id);
      if (i != -1) return rows..[i] = cached;
      return [cached, ...rows].take(_limit).toList();
    });
  }

  /// The columns the inbox caches (the feed sends whole rows).
  static const _columns = [
    'id',
    'type',
    'title',
    'body',
    'actor_id',
    'data',
    'created_at',
    'read_at',
  ];
}
