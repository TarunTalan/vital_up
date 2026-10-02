import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/cache/cache_store.dart';
import 'package:vital_up/core/network/offline_errors.dart';
import 'package:vital_up/features/community/data/datasources/community_remote_datasource.dart';
import 'package:vital_up/features/community/domain/entities/friend.dart';
import 'package:vital_up/features/community/domain/entities/community.dart';
import 'package:vital_up/features/community/domain/entities/leaderboard_entry.dart';
import 'package:vital_up/features/community/domain/repositories/community_repository.dart';
import 'package:vital_up/features/gamification/domain/entities/score_category.dart';

/// Reads are cache-first (see [CacheStore]): screens open from the cached
/// copy and keep it offline. Raw rows are cached, so local edits patch
/// them in place.
class CommunityRepositoryImpl implements CommunityRepository {
  final CommunityRemoteDataSource _remote;
  final CacheStore _cache;

  CommunityRepositoryImpl(this._remote, this._cache);

  static const _listsMaxAge = Duration(minutes: 10);
  static const _friendsMaxAge = Duration(minutes: 5);
  static const _boardMaxAge = Duration(minutes: 3);

  /// Gives up on a hung request early enough to fall back to the cache
  /// before the screen's own load timeout.
  static const _requestTimeout = Duration(seconds: 10);

  String _key(String name) => 'community:$name:${_remote.requireUser()}';
  String get _communitiesKey => _key('communities');
  String get _settingsKey => _key('settings');
  String get _friendsKey => _key('friends');

  /// Every leaderboard key of [communityId] starts with this.
  String _boardPrefix(String communityId) => '${_key('board')}:$communityId:';

  Future<List<Map<String, dynamic>>> _rows(
    String key,
    Future<List<Map<String, dynamic>>> Function() remote,
    Duration maxAge,
  ) => _cache.fetch<List<Map<String, dynamic>>>(
    key,
    remote: () => remote().timeout(_requestTimeout),
    maxAge: maxAge,
    decode: _decodeRows,
  );

  static List<Map<String, dynamic>> _decodeRows(Object? json) => [
    for (final r in json as List) Map<String, dynamic>.from(r as Map),
  ];

  static Map<String, dynamic>? _decodeRow(Object? json) =>
      json == null ? null : Map<String, dynamic>.from(json as Map);

  /// Applies [change] to the cached rows under [key], if any.
  Future<void> _patchRows(
    String key,
    List<Map<String, dynamic>> Function(List<Map<String, dynamic>> rows)
    change,
  ) => _cache.update(key, (data) => change(_decodeRows(data)));

  /// Friend changes reshape every friends leaderboard.
  Future<void> _invalidateFriends() async {
    await _cache.remove(_friendsKey);
    await _cache.removeWhere(_boardPrefix('friends'));
  }

  @override
  Future<List<Community>> getCommunities() async => [
    for (final r in await _rows(
      _communitiesKey,
      _remote.fetchCommunities,
      _listsMaxAge,
    ))
      Community.fromJson(r),
  ];

  @override
  Future<void> join(Community community) =>
      _setMembership(community, joined: true);

  @override
  Future<void> leave(Community community) =>
      _setMembership(community, joined: false);

  /// Online only (see [CommunityRemoteDataSource.join]); the cached list is
  /// patched so the hub doesn't refetch it.
  Future<void> _setMembership(
    Community community, {
    required bool joined,
  }) async {
    try {
      if (joined) {
        await _remote.join(community.id);
      } else {
        await _remote.leave(community.id);
      }
    } on PostgrestException catch (e) {
      // Joined already (e.g. on another device): the goal is met.
      if (!(joined && e.code == '23505')) rethrow;
    }
    await _patchRows(_communitiesKey, (rows) {
      for (final r in rows) {
        if (r['id'] == community.id && r['is_member'] != joined) {
          final count = (r['member_count'] as num?)?.toInt() ?? 0;
          r['is_member'] = joined;
          r['member_count'] = joined ? count + 1 : (count > 0 ? count - 1 : 0);
        }
      }
      return rows;
    });
    await _cache.removeWhere(_boardPrefix(community.id));
  }

  @override
  Future<CommunitySettings> getSettings() async {
    final row = await _cache.fetch<Map<String, dynamic>?>(
      _settingsKey,
      remote: () => _remote.fetchSettings().timeout(_requestTimeout),
      maxAge: _listsMaxAge,
      decode: _decodeRow,
    );
    return CommunitySettings(
      username: row?['username'] as String?,
      city: row?['city'] as String?,
      countryCode: row?['country_code'] as String?,
      leaderboardVisible: row?['leaderboard_visible'] as bool? ?? true,
    );
  }

  Future<void> _patchSettings(Map<String, dynamic> values) => _cache.update(
    _settingsKey,
    (data) => {...?_decodeRow(data), ...values},
  );

  @override
  Future<void> setCity(String city, String countryCode) async {
    final c = city.trim();
    final cc = countryCode.trim();
    final sent = await _remote.setCity(c, cc);
    await _patchSettings({
      'city': c.isEmpty ? null : c,
      'country_code': cc.isEmpty ? null : cc.toUpperCase(),
    });
    if (sent) {
      // Moved to another local community: refetch the list.
      await _cache.remove(_communitiesKey);
    } else {
      // Queued: the new city's community isn't known until it syncs, so
      // stop showing the old one as the caller's.
      await _patchRows(
        _communitiesKey,
        (rows) => [
          for (final r in rows)
            if (r['type'] != CommunityType.local.name) r,
        ],
      );
    }
  }

  @override
  Future<void> setLeaderboardVisible(bool visible) async {
    await _remote.setLeaderboardVisible(visible);
    await _patchSettings({'leaderboard_visible': visible});
  }

  @override
  Future<List<LeaderboardEntry>> getLeaderboard(
    Community community, {
    required LeaderboardPeriod period,
    ScoreCategory? category,
    int limit = 50,
    int offset = 0,
  }) async {
    if (community.type == CommunityType.friends) {
      // Fetched whole, so there is never a next page.
      return offset > 0 ? const [] : _friendsBoard(period, category);
    }
    Future<List<Map<String, dynamic>>> fetch() => _remote.fetchLeaderboard(
      communityId: community.id,
      period: period.name,
      category: category?.name,
      limit: limit,
      offset: offset,
    );
    // Only the first page is cached; later pages are fetched on demand.
    final rows = offset > 0
        ? await fetch()
        : await _rows(
            '${_boardPrefix(community.id)}${period.name}:'
            '${category?.name}:$limit',
            fetch,
            _boardMaxAge,
          );
    return [for (final r in rows) LeaderboardEntry.fromJson(r)];
  }

  @override
  Future<LeaderboardEntry?> getMyRank(
    Community community, {
    required LeaderboardPeriod period,
    ScoreCategory? category,
  }) async {
    if (community.type == CommunityType.friends) {
      return (await _friendsBoard(
        period,
        category,
      )).where((e) => e.isMe).firstOrNull;
    }
    final row = await _cache.fetch<Map<String, dynamic>?>(
      '${_boardPrefix(community.id)}me:${period.name}:${category?.name}',
      remote: () => _remote
          .fetchMyRank(
            communityId: community.id,
            period: period.name,
            category: category?.name,
          )
          .timeout(_requestTimeout),
      maxAge: _boardMaxAge,
      decode: _decodeRow,
    );
    return row == null ? null : LeaderboardEntry.fromJson(row);
  }

  Future<List<LeaderboardEntry>> _friendsBoard(
    LeaderboardPeriod period,
    ScoreCategory? category,
  ) async => [
    for (final r in await _rows(
      '${_boardPrefix('friends')}${period.name}:${category?.name}',
      () => _remote.fetchFriendsLeaderboard(
        period: period.name,
        category: category?.name,
      ),
      _boardMaxAge,
    ))
      LeaderboardEntry.fromJson(r),
  ];

  @override
  Future<List<Friend>> getFriends() async => [
    for (final r in await _rows(
      _friendsKey,
      _remote.fetchFriends,
      _friendsMaxAge,
    ))
      Friend.fromJson(r),
  ];

  /// Online only: the answer (pending / accepted / error) is needed now.
  @override
  Future<bool> sendFriendRequest(String username) async {
    final name = username.trim();
    if (name.isEmpty || name == '@') {
      throw const FriendRequestException('Enter a username.');
    }
    try {
      final accepted = await _remote.sendFriendRequest(name) == 'accepted';
      await _invalidateFriends();
      return accepted;
    } on PostgrestException catch (e) {
      throw FriendRequestException.fromServer(e.message);
    } catch (e) {
      if (isOfflineError(e)) {
        throw const FriendRequestException(CommunityRepository.offlineMessage);
      }
      rethrow;
    }
  }

  @override
  Future<void> respondToRequest(Friend friend, {required bool accept}) async {
    try {
      await _remote.respondToRequest(friend.userId, accept);
    } on PostgrestException catch (e) {
      // Gone or already answered: the cached list is out of date.
      await _invalidateFriends();
      throw FriendRequestException.fromServer(e.message);
    } catch (e) {
      if (isOfflineError(e)) {
        throw const FriendRequestException(CommunityRepository.offlineMessage);
      }
      rethrow;
    }
    await _invalidateFriends();
  }

  @override
  Future<void> removeFriend(Friend friend) async {
    final sent = await _remote.removeFriend(friend.userId);
    if (sent) {
      await _invalidateFriends();
    } else {
      // Queued: hide them now. The cached friends boards are kept so they
      // still open offline; they refresh once stale.
      await _patchRows(
        _friendsKey,
        (rows) => [
          for (final r in rows)
            if (r['user_id'] != friend.userId) r,
        ],
      );
    }
  }
}
