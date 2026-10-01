import 'package:supabase_flutter/supabase_flutter.dart';

/// Community RPCs and membership rows. Local communities are only joined
/// through `set_my_city`; RLS allows direct joins for interest ones only.
class CommunityRemoteDataSource {
  final SupabaseClient _client;

  CommunityRemoteDataSource(this._client);

  String? get userId => _client.auth.currentUser?.id;

  String _requireUser() {
    final id = userId;
    if (id == null) throw const AuthException('Not signed in');
    return id;
  }

  Future<List<Map<String, dynamic>>> fetchCommunities() async =>
      _rows(await _client.rpc('get_communities'));

  Future<void> join(String communityId) => _client
      .from('community_members')
      .insert({'community_id': communityId, 'user_id': _requireUser()});

  Future<void> leave(String communityId) => _client
      .from('community_members')
      .delete()
      .eq('community_id', communityId)
      .eq('user_id', _requireUser());

  Future<Map<String, dynamic>?> fetchSettings() => _client
      .from('profiles')
      .select('username, city, country_code, leaderboard_visible')
      .eq('id', _requireUser())
      .maybeSingle();

  Future<void> setCity(String city, String countryCode) => _client.rpc(
    'set_my_city',
    params: {'p_city': city, 'p_country_code': countryCode},
  );

  Future<void> setLeaderboardVisible(bool visible) => _client
      .from('profiles')
      .update({'leaderboard_visible': visible})
      .eq('id', _requireUser());

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

  Future<String> sendFriendRequest(String username) async =>
      await _client.rpc('send_friend_request', params: {'p_username': username})
          as String;

  Future<void> respondToRequest(String requesterId, bool accept) => _client.rpc(
    'respond_friend_request',
    params: {'p_requester': requesterId, 'p_accept': accept},
  );

  Future<void> removeFriend(String userId) =>
      _client.rpc('remove_friend', params: {'p_user': userId});

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
