import 'package:flutter/foundation.dart';
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/cache/cache_store.dart';
import 'package:vital_up/core/network/offline_errors.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/features/community/data/datasources/community_remote_datasource.dart';
import 'package:vital_up/features/community/domain/entities/common_community_rank.dart';
import 'package:vital_up/features/community/domain/entities/friend.dart';
import 'package:vital_up/features/community/domain/entities/community.dart';
import 'package:vital_up/features/community/domain/entities/community_award.dart';
import 'package:vital_up/features/community/domain/entities/community_standing.dart';
import 'package:vital_up/features/community/domain/entities/leaderboard_entry.dart';
import 'package:vital_up/features/community/domain/entities/player_profile.dart';
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

  /// Profiles change as people log: refreshed after two minutes, the saved
  /// copy shown offline.
  static const _profileMaxAge = Duration(minutes: 2);
  String _profileKey(String userId) => '${_key('profile')}:$userId';
  static const _boardMaxAge = Duration(minutes: 3);

  /// Awards are always asked for fresh (see [getCommunityWinners]); this
  /// only applies to the copy shown offline.
  static const _awardsMaxAge = Duration(minutes: 30);

  /// Gives up on a hung request early enough to fall back to the cache
  /// before the screen's own load timeout.
  static const _requestTimeout = Duration(seconds: 10);

  String _key(String name) => 'community:$name:${_remote.requireUser()}';
  String get _communitiesKey => _key('communities');
  String get _settingsKey => settingsKey(_remote.requireUser());

  /// Cached Arena settings (username, city...); a username change patches
  /// it so Arena shows the new name at once.
  static String settingsKey(String userId) => 'community:settings:$userId';
  String get _friendsKey => _key('friends');

  /// Ranks that depend on who the caller's friends are or which
  /// communities they're in.
  String get _friendRanksPrefix => '${_key('friendranks')}:';
  String get _standingsPrefix => '${_key('standings')}:';

  /// Every leaderboard key of [communityId] starts with this.
  String _boardPrefix(String communityId) => '${_key('board')}:$communityId:';

  Future<List<Map<String, dynamic>>> _rows(
    String key,
    Future<List<Map<String, dynamic>>> Function() remote,
    Duration maxAge, {
    bool forceRefresh = false,
  }) => _cache.fetch<List<Map<String, dynamic>>>(
    key,
    remote: () => remote().timeout(_requestTimeout),
    maxAge: maxAge,
    decode: _decodeRows,
    forceRefresh: forceRefresh,
  );

  static List<Map<String, dynamic>> _decodeRows(Object? json) => [
    for (final r in json as List) Map<String, dynamic>.from(r as Map),
  ];

  static Map<String, dynamic>? _decodeRow(Object? json) =>
      json == null ? null : Map<String, dynamic>.from(json as Map);

  /// Applies [change] to the cached rows under [key], if any.
  Future<void> _patchRows(
    String key,
    List<Map<String, dynamic>> Function(List<Map<String, dynamic>> rows) change,
  ) => _cache.update(key, (data) => change(_decodeRows(data)));

  /// Friend changes reshape every friends leaderboard.
  Future<void> _invalidateFriends() async {
    await _cache.remove(_friendsKey);
    await _cache.removeWhere(_boardPrefix('friends'));
    await _cache.removeWhere(_friendRanksPrefix);
    await _cache.removeWhere(_standingsPrefix);
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
        await _remote.join(community.id).timeout(_requestTimeout);
      } else {
        await _remote.leave(community.id).timeout(_requestTimeout);
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
    await _cache.removeWhere(_standingsPrefix);
  }

  @override
  Future<CommunitySettings> getSettings() async {
    final row = await _cache.fetch<Map<String, dynamic>?>(
      _settingsKey,
      remote: () => _remote.fetchSettings().timeout(_requestTimeout),
      maxAge: _listsMaxAge,
      decode: _decodeRow,
    );
    return _settingsFrom(row);
  }

  static CommunitySettings _settingsFrom(Map<String, dynamic>? row) =>
      CommunitySettings(
        username: row?['username'] as String?,
        city: row?['city'] as String?,
        countryCode: row?['country_code'] as String?,
        leaderboardVisible: row?['leaderboard_visible'] as bool? ?? true,
      );

  @override
  Future<(List<Community>, CommunitySettings)?> savedHub() async {
    try {
      final rows = await _cache.read<List<Map<String, dynamic>>>(
        _communitiesKey,
        decode: _decodeRows,
      );
      final settings = await _cache.read<Map<String, dynamic>?>(
        _settingsKey,
        decode: _decodeRow,
      );
      if (rows == null || settings == null) return null;
      return (
        [for (final r in rows.value) Community.fromJson(r)],
        _settingsFrom(settings.value),
      );
    } catch (e) {
      debugPrint('Saved Arena unavailable: $e');
      return null;
    }
  }

  Future<void> _patchSettings(Map<String, dynamic> values) =>
      _cache.update(_settingsKey, (data) => {...?_decodeRow(data), ...values});

  @override
  Future<void> setCity(String city, String countryCode) async {
    final c = sanitizeText(city, maxLength: InputLimits.city);
    final cc = sanitizeText(countryCode).toUpperCase();
    final sent = await _remote.setCity(c, cc);
    await _patchSettings({
      'city': c.isEmpty ? null : c,
      'country_code': cc.isEmpty ? null : cc.toUpperCase(),
    });
    await _cache.removeWhere(_standingsPrefix);
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

  @override
  Future<List<LeaderboardEntry>> getFriendRanks(
    Community community, {
    required LeaderboardPeriod period,
    ScoreCategory? category,
  }) async {
    if (community.type == CommunityType.friends) {
      return _friendsBoard(period, category);
    }
    return [
      for (final r in await _rows(
        '$_friendRanksPrefix${community.id}:${period.name}:${category?.name}',
        () => _remote.fetchCommunityFriendRanks(
          communityId: community.id,
          period: period.name,
          category: category?.name,
        ),
        _boardMaxAge,
      ))
        LeaderboardEntry.fromJson(r),
    ];
  }

  @override
  Future<Map<String, CommunityStanding>> getMyStandings({
    LeaderboardPeriod period = LeaderboardPeriod.week,
  }) async => {
    for (final r in await _rows(
      '$_standingsPrefix${period.name}',
      () => _remote.fetchMyStandings(period: period.name),
      _boardMaxAge,
    ))
      r['community_id'] as String: CommunityStanding.fromJson(r),
  };

  @override
  Future<List<AwardWinner>> getCommunityWinners(
    Community community,
    AwardPeriod period,
  ) async {
    if (community.type == CommunityType.friends) return const [];
    return [
      for (final r in await _rows(
        '${_key('winners')}:${community.id}:${period.name}',
        () => _remote.fetchCommunityAwards(
          communityId: community.id,
          period: period.name,
        ),
        _awardsMaxAge,
        // Asked fresh each time (small, and winners must show as soon as
        // they're announced); the saved copy is for offline.
        forceRefresh: true,
      ))
        AwardWinner.fromJson(r),
    ];
  }

  @override
  Future<List<CommunityAward>> getPlayerAwards([String? userId]) async => [
    for (final r in await _rows(
      '${_key('awards')}:${userId ?? 'me'}',
      () => _remote.fetchPlayerAwards(userId),
      _awardsMaxAge,
      forceRefresh: true,
    ))
      CommunityAward.fromJson(r),
  ];

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
    final name = normalizeFriendUsername(username);
    try {
      final accepted =
          await _remote.sendFriendRequest(name).timeout(_requestTimeout) ==
          'accepted';
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
      await _remote
          .respondToRequest(friend.userId, accept)
          .timeout(_requestTimeout);
    } on PostgrestException catch (e) {
      // Gone or already answered: the cached list is out of date.
      await _invalidateFriends();
      throw FriendRequestException.fromServer(
        e.message,
        fallback: "Couldn't update the request. Try again.",
      );
    } catch (e) {
      if (isOfflineError(e)) {
        throw const FriendRequestException(CommunityRepository.offlineMessage);
      }
      rethrow;
    }
    await _invalidateFriends();
  }

  @override
  Future<PlayerProfile> getPlayerProfile(String userId) => _profileCall(
    () async => PlayerProfile.fromJson(
      (await _cache.fetch<Map<String, dynamic>?>(
        _profileKey(userId),
        remote: () =>
            _remote.fetchPlayerProfile(userId).timeout(_requestTimeout),
        maxAge: _profileMaxAge,
        decode: _decodeRow,
      ))!,
    ),
  );

  @override
  Future<PlayerProfile> getMyProfile() =>
      getPlayerProfile(_remote.requireUser());

  @override
  Future<void> sendCheer(String userId) async {
    try {
      await _profileCall(
        () => _remote.sendCheer(userId).timeout(_requestTimeout),
      );
    } on PlayerProfileException catch (e) {
      // A retry after a lost reply, or a cheer sent from another device:
      // the cheer is there, which is what the user wanted.
      if (e.message != PlayerProfileException.alreadyCheered) rethrow;
    }
    // The saved profile shows "Cheered" too (offline, or reopened soon).
    await _cache.update(
      _profileKey(userId),
      (data) => {...?_decodeRow(data), 'cheered_today': true},
    );
  }

  /// Maps server and network failures to [PlayerProfileException].
  Future<T> _profileCall<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on PostgrestException catch (e) {
      throw PlayerProfileException.fromServer(e.message);
    } catch (e) {
      if (isOfflineError(e)) {
        throw const PlayerProfileException(CommunityRepository.offlineMessage);
      }
      if (e is TimeoutException) throw PlayerProfileException(userMessage(e));
      rethrow;
    }
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

  /// Friends board, Global, the caller's city and joined communities where
  /// the friend is ranked too, with both all-time ranks. Uses the real
  /// ranks from [getFriendRanks]; falls back to the first 100 of each board
  /// when that isn't available.
  @override
  Future<List<CommonCommunityRank>> getCommonCommunityRanks(
    String friendUserId,
  ) async {
    try {
      final communities = await getCommunities();
      final targets = [
        Community.friendsOf(0),
        for (final c in communities)
          if (c.type == CommunityType.global) c,
        for (final c in communities)
          if (c.type != CommunityType.global && c.isMember) c,
      ];
      final results = await Future.wait(
        targets.map((c) async {
          try {
            List<LeaderboardEntry> entries;
            try {
              entries = await getFriendRanks(c, period: LeaderboardPeriod.all);
            } catch (_) {
              entries = await getLeaderboard(
                c,
                period: LeaderboardPeriod.all,
                limit: 100,
              );
            }
            final friend = entries
                .where((e) => e.userId == friendUserId)
                .firstOrNull;
            final me = entries.where((e) => e.isMe).firstOrNull;
            // Global and the friends board are always shared; elsewhere
            // only boards the friend is ranked on.
            final shared =
                c.type == CommunityType.global ||
                c.type == CommunityType.friends ||
                friend != null;
            if (!shared) return null;
            return CommonCommunityRank(
              community: c,
              friendRank: friend?.rank,
              friendPoints: friend?.points ?? 0,
              myRank: me?.rank,
              myPoints: me?.points ?? 0,
            );
          } catch (_) {
            return null;
          }
        }),
      );
      return results.whereType<CommonCommunityRank>().toList();
    } catch (_) {
      return const [];
    }
  }
}
