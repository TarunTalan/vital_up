import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/sync/pending_writes.dart';

/// The `notifications` table (RLS: own rows only) and its realtime feed.
/// Rows are written by server triggers; the app only reads, marks read and
/// deletes. Mark-read and delete are idempotent, so they are queued when
/// offline.
class NotificationsRemoteDataSource {
  final SupabaseClient _client;
  final PendingWrites _pending;

  NotificationsRemoteDataSource(this._client, this._pending);

  /// What [AppNotification.fromJson] reads.
  static const _columns =
      'id, type, title, body, actor_id, data, created_at, read_at';

  String? get userId => _client.auth.currentUser?.id;

  String _requireUser() {
    final id = userId;
    if (id == null) throw const AuthException('Not signed in');
    return id;
  }

  Future<List<Map<String, dynamic>>> fetch({required int limit}) => _client
      .from('notifications')
      .select(_columns)
      .order('created_at', ascending: false)
      .limit(limit);

  /// True if it reached the server, false if queued.
  Future<bool> markRead(List<int>? ids) => _pending.sendOrQueue(
    _client,
    PendingWrite.rpc(
      'mark_notifications_read',
      params: {'p_ids': ids},
      userId: _requireUser(),
    ),
  );

  /// True if it reached the server, false if queued.
  Future<bool> delete(int id) => _pending.sendOrQueue(
    _client,
    PendingWrite.delete(
      'notifications',
      match: {'id': id},
      userId: _requireUser(),
    ),
  );

  /// The new row of each insert and update on the caller's notifications.
  /// Deletes can't be filtered per user, so the app applies its own deletes
  /// locally instead.
  ///
  /// Rows sent while the connection was down are not replayed: the channel
  /// rejoins on its own, and [onResubscribed] runs each time it does so the
  /// caller can refetch what it missed.
  Stream<Map<String, dynamic>> changes({void Function()? onResubscribed}) {
    final user = userId;
    if (user == null) return const Stream.empty();

    RealtimeChannel? channel;
    var joined = false;
    late final StreamController<Map<String, dynamic>> controller;
    void onChange(PostgresChangePayload payload) {
      if (payload.newRecord.isNotEmpty) controller.add(payload.newRecord);
    }

    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'user_id',
      value: user,
    );

    controller = StreamController<Map<String, dynamic>>(
      onListen: () {
        channel = _client
            .channel('notifications:$user')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'notifications',
              filter: filter,
              callback: onChange,
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'notifications',
              filter: filter,
              callback: onChange,
            )
            .subscribe((status, error) {
              if (status == RealtimeSubscribeStatus.subscribed) {
                if (joined) onResubscribed?.call();
                joined = true;
              } else if (error != null) {
                debugPrint('Notifications feed $status: $error');
              }
            });
      },
      onCancel: () async {
        final c = channel;
        channel = null;
        if (c != null) await _client.removeChannel(c);
      },
    );
    return controller.stream;
  }
}
