import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/sync/pending_writes.dart';

/// Community RPCs and membership rows. Local communities are only joined
/// through `set_my_city`; RLS allows direct joins for interest ones only.
class CommunityRemoteDataSource {
  final SupabaseClient _client;
  final PendingWrites _pending;

  CommunityRemoteDataSource(this._client, this._pending);

  String? get userId => _client.auth.currentUser?.id;

  String requireUser() {
    final id = userId;
    if (id == null) throw const AuthException('Not signed in');
    return id;
  }

  Future<List<Map<String, dynamic>>> fetchCommunities() async =>
      _rows(await _client.rpc('get_communities'));

  /// Online only: the row has no upsert policy, so a replayed insert would
  /// fail on the primary key.
  Future<void> join(String communityId) => _client
      .from('community_members')
      .insert({'community_id': communityId, 'user_id': requireUser()});

  /// Online only, so it can't be replayed after a later [join].
  Future<void> leave(String communityId) => _client
      .from('community_members')
      .delete()
      .eq('community_id', communityId)
      .eq('user_id', requireUser());

  Future<Map<String, dynamic>?> fetchSettings() => _client
      .from('profiles')
      .select('username, city, country_code, leaderboard_visible')
      .eq('id', requireUser())
      .maybeSingle();

  /// Queued when offline (the latest city wins). True if it reached the
  /// server.
  Future<bool> setCity(String city, String countryCode) {
    final user = requireUser();
    return _pending.sendOrQueue(
      _client,
      PendingWrite.rpc(
        'set_my_city',
        params: {'p_city': city, 'p_country_code': countryCode},
        userId: user,
        key: 'rpc:set_my_city',
      ),
    );
  }

  /// Queued when offline. True if it reached the server.
  Future<bool> setLeaderboardVisible(bool visible) {
    final user = requireUser();
    return _pending.sendOrQueue(
      _client,
      PendingWrite.update(
        'profiles',
        values: {'leaderboard_visible': visible},
        match: {'id': user},
        userId: user,
      ),
    );
  }

  Future<List<Map<String, dynamic>>> fetchLeaderboard({
    required String communityId,
    required String period,
    String? category,
    required int limit,
    required int offset,
  }) async => _rows(
    await _client.rpc(
      'get_leaderboard',
      params: {
        'p_community': communityId,
        'p_period': period,
        'p_category': category,
        'p_limit': limit,
        'p_offset': offset,
      },
    ),
  );

  Future<List<Map<String, dynamic>>> fetchFriends() async =>
      _rows(await _client.rpc('get_friends'));

  Future<Map<String, dynamic>> fetchPlayerProfile(String userId) async =>
      Map<String, dynamic>.from(
        await _client.rpc('get_player_profile', params: {'p_user': userId})
            as Map,
      );

  Future<void> sendCheer(String userId) =>
      _client.rpc('send_cheer', params: {'p_friend': userId});

  Future<String> sendFriendRequest(String username) async =>
      await _client.rpc('send_friend_request', params: {'p_username': username})
          as String;

  /// Online only: the server rejects a repeat (`request_not_found`).
  Future<void> respondToRequest(String requesterId, bool accept) => _client.rpc(
    'respond_friend_request',
    params: {'p_requester': requesterId, 'p_accept': accept},
  );

  /// Idempotent on the server, so queued when offline. True if it reached
  /// the server.
  Future<bool> removeFriend(String userId) => _pending.sendOrQueue(
    _client,
    PendingWrite.rpc(
      'remove_friend',
      params: {'p_user': userId},
      userId: requireUser(),
    ),
  );

  /// The caller and every friend, ranked; small enough to fetch whole.
  Future<List<Map<String, dynamic>>> fetchFriendsLeaderboard({
    required String period,
    String? category,
  }) async => _rows(
    await _client.rpc(
      'get_friends_leaderboard',
      params: {'p_period': period, 'p_category': category},
    ),
  );

  Future<Map<String, dynamic>?> fetchMyRank({
    required String communityId,
    required String period,
    String? category,
  }) async {
    final rows = _rows(
      await _client.rpc(
        'get_my_rank',
        params: {
          'p_community': communityId,
          'p_period': period,
          'p_category': category,
        },
      ),
    );
    return rows.firstOrNull;
  }

  static List<Map<String, dynamic>> _rows(dynamic result) => [
    for (final r in (result as List? ?? const []))
      Map<String, dynamic>.from(r as Map),
  ];
}
