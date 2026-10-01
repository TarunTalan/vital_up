import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// The `notifications` table (RLS: own rows only) and its realtime feed.
/// Rows are written by server triggers; the app only reads, marks read and
/// deletes.
class NotificationsRemoteDataSource {
  final SupabaseClient _client;

  NotificationsRemoteDataSource(this._client);

  String? get userId => _client.auth.currentUser?.id;

  Future<List<Map<String, dynamic>>> fetch({required int limit}) => _client
      .from('notifications')
      .select()
      .order('created_at', ascending: false)
      .limit(limit);

  Future<void> markRead(List<int>? ids) =>
      _client.rpc('mark_notifications_read', params: {'p_ids': ids});

  Future<void> delete(int id) =>
      _client.from('notifications').delete().eq('id', id);

  /// Inserts and updates on the caller's rows. Deletes can't be filtered
  /// per user, so the app reloads after its own deletes instead.
  Stream<void> changes() {
    final user = userId;
    if (user == null) return const Stream.empty();

    RealtimeChannel? channel;
    late final StreamController<void> controller;
    void onChange(PostgresChangePayload _) => controller.add(null);
    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'user_id',
      value: user,
    );

    controller = StreamController<void>(
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
            .subscribe();
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
